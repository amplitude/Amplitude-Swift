//
//  EventPipeline.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

#if AMPLITUDE_DISABLE_UIKIT
@_spi(Internal) import AmplitudeCoreNoUIKit
#else
@_spi(Internal) import AmplitudeCore
#endif

/// Retry interval capped at 1 minutes
private let MAX_RETRY_INTERVAL: Double = 60

public class EventPipeline {
    var httpClient: AnalyticsHttpClient
    let identifyStorage: any Storage
    let storage: Storage?
    let logger: (any Logger)?
    let configuration: Configuration
    let diagnosticsClient: CoreDiagnostics

    @AtomicRef internal var eventCount: Int = 0
    internal var flushTimer: QueueTimer?
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.amplitude.com")
    private let callbackQueue = DispatchQueue(label: "callbacksQueue.amplitude.com")

    private var flushCompletions: [() -> Void] = []
    private var uploadInProgress = false
    private var flushRequested = false
    private let vendorSystem: VendorSystem
    private let uploadStateStorage: (any UploadRequestStateStorage)?
    private var didRecoverPendingUpload = false

    init(amplitude: Amplitude, vendorSystem: VendorSystem = .current) {
        self.vendorSystem = vendorSystem
        identifyStorage = amplitude.identifyStorage
        storage = amplitude.storage
        logger = amplitude.logger
        diagnosticsClient = amplitude.amplitudeContext.diagnosticsClient
        configuration = amplitude.configuration
        uploadStateStorage = amplitude.storage as? any UploadRequestStateStorage
        httpClient = AnalyticsHttpClient(configuration: amplitude.configuration,
                                diagnostics: amplitude.configuration.diagonostics,
                                callbackQueue: uploadsQueue,
                                serverZone: amplitude.amplitudeContext.serverZone)
        flushTimer = QueueTimer(interval: getFlushInterval(), queue: uploadsQueue) { [weak self] in
            self?.flush(automatic: true)
        }
        amplitude.appLifecycle.addObserver(self)
    }

    func put(event: BaseEvent, isRetry: Bool = false, completion: (() -> Void)? = nil) {
        guard let storage = self.storage else { return }
        event.attempts += 1
        do {
            try storage.write(key: StorageKey.EVENTS, value: event)
            _eventCount.withLock { $0 += 1 }
            if eventCount >= getFlushCount() {
                if isRetry {
                    // The current chain owns retries; finalizing a batch must not start a new flush.
                    eventCount = 0
                    storage.rollover()
                } else {
                    flush()
                }
            }
            completion?()
        } catch {
            logger?.error(message: "Error when storing event: \(error.localizedDescription)")
        }
    }

    func flush(automatic: Bool = false, completion: (() -> Void)? = nil) {
        if configuration.offline == true {
            logger?.debug(message: "Skipping flush while offline.")
            return
        }

        logger?.log(message: "Start flushing \(eventCount) events")
        eventCount = 0
        guard let storage = self.storage else { return }
        storage.rollover()

        uploadsQueue.async { [self] in
            guard !automatic || flushTimer?.state == .resumed else { return }
            if let completion {
                flushCompletions.append(completion)
            }
            if !automatic {
                flushRequested = true
            }
            self.sendNextEventFile()
        }
    }

    private func sendNextEventFile(failures: Int = 0, skipFiles: Set<URL> = []) {
        autoreleasepool {
            guard !uploadInProgress else {
                logger?.log(message: "Existing upload in progress, skipping...")
                return
            }

            flushRequested = false

            // Runs once on uploadsQueue, before this instance can start a request.
            // Assumes one SDK initialization per instance name per process.
            if configuration.enableDiagnostics && !didRecoverPendingUpload {
                didRecoverPendingUpload = true
                if uploadStateStorage?.uploadRequestPending == true {
                    diagnosticsClient.increment(name: "analytics.upload.missed_network_callback")
                }
                uploadStateStorage?.uploadRequestPending = false
            }

            guard let storage = storage,
                  let eventFiles: [URL] = storage.read(key: StorageKey.EVENTS),
                  let nextEventFile = eventFiles.first(where: { !skipFiles.contains($0) }) else {
                completeFlush()
                logger?.debug(message: "No event files to upload")
                return
            }

            guard configuration.offline != true else {
                logger?.debug(message: "Skipping flush while offline.")
                return
            }

            guard let eventsString = storage.getEventsString(eventBlock: nextEventFile),
                  !eventsString.isEmpty else {
                logger?.log(message: "Could not read events file: \(nextEventFile)")
                // Storage quarantines unreadable files inside getEventsString. Add the
                // file to skipFiles so this flush chain continues to later files even
                // if the quarantine rename itself failed, and so we don't revisit it
                // within the same flush.
                var newSkipFiles = skipFiles
                newSkipFiles.insert(nextEventFile)
                uploadsQueue.async { [weak self] in
                    self?.sendNextEventFile(failures: failures, skipFiles: newSkipFiles)
                }
                return
            }

            // Expiration and response handling share uploadsQueue. End the assertion on
            // expiry, but keep the request alive so a late success can acknowledge its batch.
            var expired = false
            var finished = false
            var backgroundTaskCompletion: BackgroundTaskCompletionCallback?
            backgroundTaskCompletion = vendorSystem.beginBackgroundTask(label: "amplitude.upload") {
                self.uploadsQueue.async {
                    guard !finished else { return }
                    expired = true
                    self.flushTimer?.suspend()
                    backgroundTaskCompletion?()
                    backgroundTaskCompletion = nil
                }
            }
            if configuration.enableDiagnostics {
                uploadStateStorage?.uploadRequestPending = true
            }
            uploadInProgress = true
            _ = httpClient.upload(events: eventsString) { [self] result in
                if configuration.enableDiagnostics {
                    uploadStateStorage?.uploadRequestPending = false
                }
                let responseHandler = storage.getResponseHandler(
                    configuration: self.configuration,
                    eventPipeline: self,
                    eventBlock: nextEventFile,
                    eventsString: eventsString
                )
                let handled: Bool = responseHandler.handle(result: result)
                backgroundTaskCompletion?()
                backgroundTaskCompletion = nil
                var failures = failures

                switch result {
                case .success:
                    failures = 0
                case .failure:
                    if !handled {
                        failures += 1
                    }
                }

                // Let expiration and flush requests queued during response handling run before
                // deciding whether to continue. Keep the in-flight guard until that decision.
                self.uploadsQueue.async { [weak self] in
                    guard let self else { return }
                    finished = true
                    if expired {
                        self.uploadInProgress = false
                        if self.flushRequested {
                            self.sendNextEventFile()
                        } else {
                            self.completeFlush()
                        }
                    } else if failures > self.configuration.flushMaxRetries {
                        self.uploadInProgress = false
                        self.configuration.offline = true
                        self.logger?.error(message: "Request failed more than \(self.configuration.flushMaxRetries) times, marking offline")
                    } else {
                        let nextFileBlock: () -> Void = { [weak self] in
                            guard let self else { return }
                            self.uploadInProgress = false
                            self.sendNextEventFile(failures: failures, skipFiles: skipFiles)
                        }

                        if failures == 0 || handled {
                            nextFileBlock()
                        } else {
                            let sendingInterval = min(MAX_RETRY_INTERVAL, pow(2, Double(failures - 1)))
                            self.uploadsQueue.asyncAfter(deadline: .now() + sendingInterval, execute: nextFileBlock)
                            self.logger?.error(message: "Request failed \(failures) times, send next event file in \(sendingInterval) seconds")
                        }
                    }
                }
            }
        }
    }

    func dispatchCallbacks(_ callbacks: @escaping () -> Void) {
        callbackQueue.async(execute: callbacks)
    }

    private func completeFlush() {
        let completions = flushCompletions
        flushCompletions.removeAll()
        guard !completions.isEmpty else { return }
        dispatchCallbacks { completions.forEach { $0() } }
    }

    func start() {
        uploadsQueue.async { [weak self] in
            self?.flushTimer?.resume()
        }
    }

    func stop() {
        uploadsQueue.async { [weak self] in
            self?.flushTimer?.suspend()
        }
    }

    private func getFlushInterval() -> TimeInterval {
        return TimeInterval.milliseconds(configuration.flushIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = configuration.flushQueueSize
        return count != 0 ? count : 1
    }
}

extension EventPipeline: ApplicationLifecycleObserver {
    func applicationDidBecomeActive(launch: Bool) {
        start()
    }

    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
        start()
    }

    func applicationDidEnterBackground(timestamp: Int64) {
        stop()
    }
}
