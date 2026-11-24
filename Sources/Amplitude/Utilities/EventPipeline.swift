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

public class EventPipeline: ApplicationLifecycleObserver {
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
    private enum UploadState {
        case idle, uploading, expired, expiredWithPendingFlush
    }
    private var uploadState: UploadState = .idle
    private var uploadsBlockedUntilForeground = false
    private var isInForeground: Bool?
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
        // Apply the snapshot before this queue handles any transition delivered after registration.
        uploadsQueue.sync {
            isInForeground = amplitude.appLifecycle.addObserver(self)
            flushTimer = QueueTimer(interval: getFlushInterval(), queue: uploadsQueue) { [weak self] in
                self?.flushOnTimer()
            }
#if !os(macOS) && !targetEnvironment(macCatalyst)
            if isInForeground == false { flushTimer?.stop() }
#endif
        }
    }

    func put(event: BaseEvent, isRetry: Bool = false, completion: (() -> Void)? = nil) {
        guard let storage = self.storage else { return }
        event.attempts += 1
        do {
            try storage.write(key: StorageKey.EVENTS, value: event)
            let shouldFlush = _eventCount.withLock { count in
                count += 1
                return count >= getFlushCount()
            }
            if shouldFlush {
                if isRetry {
                    // The current chain handles retry batches; requeues must not start a new one.
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

    func flush(completion: (() -> Void)? = nil) {
        guard prepareFlush() else { return }
        uploadsQueue.async { [self] in
            if let completion {
                flushCompletions.append(completion)
            }
            if uploadState == .expired {
                uploadState = .expiredWithPendingFlush
            }
            sendNextEventFile()
        }
    }

    func flushOnTimer() {
        dispatchPrecondition(condition: .onQueue(uploadsQueue))
        // Preserve the threshold for fresh extension events while the expired request finishes.
        guard uploadState != .expired, uploadState != .expiredWithPendingFlush else { return }
        if prepareFlush() { sendNextEventFile() }
    }

    private func prepareFlush() -> Bool {
        if configuration.offline == true {
            logger?.debug(message: "Skipping flush while offline.")
            return false
        }

        logger?.log(message: "Start flushing \(eventCount) events")
        eventCount = 0
        guard let storage else { return false }
        storage.rollover()
        return true
    }

    private func sendNextEventFile(failures: Int = 0, skipFiles: Set<URL> = []) {
        autoreleasepool {
            guard uploadState == .idle else {
                logger?.log(message: "Existing upload in progress, skipping...")
                return
            }

            guard !uploadsBlockedUntilForeground else {
                completeFlush()
                return
            }

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

            uploadState = .uploading
            var finished = false
            var backgroundTaskCompletion: BackgroundTaskCompletionCallback?
            backgroundTaskCompletion = vendorSystem.beginBackgroundTask(label: "amplitude.upload") {
                // Let response handling already on this queue finish acknowledging its batch.
                // If the queue stalls, the assertion can outlive the expiry handler and the OS may terminate the app.
                self.uploadsQueue.async {
                    guard !finished else { return }
                    if self.vendorSystem.isRunningInAppExtension {
                        if self.uploadState == .uploading { self.uploadState = .expired }
                    } else if self.isInForeground != true {
                        self.uploadsBlockedUntilForeground = true
                        self.flushTimer?.stop()
                    }
                    backgroundTaskCompletion?()
                    backgroundTaskCompletion = nil
                }
            }
            if configuration.enableDiagnostics {
                uploadStateStorage?.uploadRequestPending = true
            }
            _ = httpClient.upload(events: eventsString) { [self] result in
                let responseHandler = storage.getResponseHandler(
                    configuration: self.configuration,
                    eventPipeline: self,
                    eventBlock: nextEventFile,
                    eventsString: eventsString
                )
                let handled: Bool = responseHandler.handle(result: result)
                // Handle the batch before doing best-effort diagnostic bookkeeping.
                if configuration.enableDiagnostics {
                    uploadStateStorage?.uploadRequestPending = false
                }
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
                    if self.uploadsBlockedUntilForeground || self.uploadState == .expired {
                        self.uploadState = .idle
                        self.completeFlush()
                        return
                    }
                    if self.uploadState == .expiredWithPendingFlush {
                        self.uploadState = .idle
                        self.sendNextEventFile()
                        return
                    }

                    // Foreground responses retain the ordinary retry limit and backoff, even after expiration.
                    guard failures <= self.configuration.flushMaxRetries else {
                        self.uploadState = .idle
                        self.configuration.offline = true
                        self.logger?.error(message: "Request failed more than \(self.configuration.flushMaxRetries) times, marking offline")
                        return
                    }
                    let nextFileBlock: () -> Void = { [weak self] in
                        guard let self else { return }
                        self.uploadState = .idle
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

    func dispatchCallbacks(_ callbacks: @escaping () -> Void) {
        callbackQueue.async(execute: callbacks)
    }

    private func completeFlush() {
        let completions = flushCompletions
        flushCompletions.removeAll()
        guard !completions.isEmpty else { return }
        dispatchCallbacks { completions.forEach { $0() } }
    }

    func stop() {
        uploadsQueue.async { [weak self] in
            self?.flushTimer?.stop()
        }
    }

    private func getFlushInterval() -> TimeInterval {
        return TimeInterval.milliseconds(configuration.flushIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = configuration.flushQueueSize
        return count != 0 ? count : 1
    }

    func applicationDidBecomeActive(launch: Bool) { enterForeground() }
    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) { enterForeground() }

    private func enterForeground() {
        uploadsQueue.async { [weak self] in
            self?.isInForeground = true
            self?.uploadsBlockedUntilForeground = false
            self?.flushTimer?.start()
        }
    }

    func applicationDidEnterBackground(timestamp: Int64) {
        uploadsQueue.async { [weak self] in
            self?.isInForeground = false
#if !os(macOS) && !targetEnvironment(macCatalyst)
            self?.flushTimer?.stop()
#endif
        }
    }
}
