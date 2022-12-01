//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class EventPipeline {
    let amplitude: Amplitude
    var httpClient: HttpClient
    var storage: Storage? { amplitude.storage }
    @Atomic internal var eventCount: Int = 0
    internal var flushTimer: QueueTimer?
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.amplitude.com")

    internal struct UploadTaskInfo {
        let events: String
        let task: URLSessionDataTask
        // set/used via an extension in iOSLifecycleMonitor.swift
        typealias CleanupClosure = () -> Void
        var cleanup: CleanupClosure?
    }
    private var uploads = [UploadTaskInfo]()

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
        self.httpClient = HttpClient(configuration: amplitude.configuration)
        self.flushTimer = QueueTimer(interval: getFlushInterval()) { [weak self] in
            self?.flush()
        }
    }

    func put(event: BaseEvent, completion: (() -> Void)? = nil) {
        guard let storage = self.storage else { return }
        event.attempts += 1
        Task {
            do {
                try await storage.write(key: StorageKey.EVENTS, value: event)
                eventCount += 1
                if eventCount >= getFlushCount() {
                    flush()
                }
                completion?()
            } catch {
                amplitude.logger?.error(message: "Error when storing event: \(error.localizedDescription)")
            }
        }
    }

    func flush(completion: (() -> Void)? = nil) {
        Task {
            guard let storage = self.storage else { return }
            await storage.rollover()
            guard let eventFiles: [URL]? = await storage.read(key: StorageKey.EVENTS) else { return }
            amplitude.logger?.log(message: "Start flushing \(eventCount) events")
            eventCount = 0
            for eventFile in eventFiles! {
                guard let eventsString = await storage.getEventsString(eventBlock: eventFile) else {
                    continue
                }
                if eventsString.isEmpty {
                    continue
                }
                let uploadTask = httpClient.upload(events: eventsString) { [weak self] result in
                    // TODO: handle response and add retry logic
                    switch result {
                    case .success(let status):
                        self?.amplitude.logger?.log(message: "Upload event success: \(status)")
                    case .failure(let error):
                        switch error {
                        case HttpClient.Exception.httpError(let code, let data):
                            self?.amplitude.logger?.log(
                                message: "Upload event error \(code): \(String(decoding: data!, as: UTF8.self))"
                            )
                        default:
                            self?.amplitude.logger?.log(message: "\(error.localizedDescription)")
                        }
                    }
                }
                if let upload = uploadTask {
                    add(uploadTask: UploadTaskInfo(events: eventsString, task: upload))
                }
            }
            completion?()
        }
    }

    func start() {
        flushTimer?.resume()
    }

    func stop() {
        flushTimer?.suspend()
    }

    private func getFlushInterval() -> TimeInterval {
        return TimeInterval.milliseconds(amplitude.configuration.flushIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = amplitude.configuration.flushQueueSize
        return count != 0 ? count : 1
    }
}

extension EventPipeline {
    internal func cleanupUploads() {
        uploadsQueue.sync {
            let before = uploads.count
            var newPending = uploads
            newPending.removeAll { uploadInfo in
                let shouldRemove = uploadInfo.task.state != .running
                if shouldRemove, let cleanup = uploadInfo.cleanup {
                    cleanup()
                }
                return shouldRemove
            }
            uploads = newPending
            let after = uploads.count
            amplitude.logger?.log(message: "Cleaned up \(before - after) non-running uploads.")
        }
    }

    internal var pendingUploads: Int {
        var uploadsCount = 0
        uploadsQueue.sync {
            uploadsCount = uploads.count
        }
        return uploadsCount
    }

    internal func add(uploadTask: UploadTaskInfo) {
        uploadsQueue.sync {
            uploads.append(uploadTask)
        }
    }
}
