//
//  EventPipeline.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

public class EventPipeline {
    let amplitude: Amplitude
    var httpClient: HttpClient
    var storage: Storage? { amplitude.storage }
    @Atomic internal var eventCount: Int = 0
    internal var flushTimer: QueueTimer?
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.amplitude.com")

    private let identifyInterceptor = IdentifyInterceptor()
    private var identifyUploadTimer: QueueTimer?
    private let minIdentifyUploadInterval: Int

    internal struct UploadTaskInfo {
        let events: String
        let task: URLSessionDataTask
        // set/used via an extension in iOSLifecycleMonitor.swift
        typealias CleanupClosure = () -> Void
        var cleanup: CleanupClosure?
    }
    private var uploads = [UploadTaskInfo]()

    init(amplitude: Amplitude, minIdentifyUploadInterval: Int = Constants.Configuration.MIN_IDENTIFY_UPLOAD_INTERVAL_MILLIS) {
        self.amplitude = amplitude
        self.minIdentifyUploadInterval = minIdentifyUploadInterval
        self.httpClient = HttpClient(configuration: amplitude.configuration)
        self.flushTimer = QueueTimer(interval: getFlushInterval()) { [weak self] in
            self?.flush(includeInterceptedIdentifyEvent: false)
        }
    }

    func put(event: BaseEvent, completion: (() -> Void)? = nil) {
        guard let storage = self.storage else { return }
        event.attempts += 1
        do {
            if !amplitude.configuration.disableIdentifyBatching {
                try interceptIdentifyEvent(storage, event)
            } else {
                try moveInterceptedIdentifyEventToEvents(storage)
                try addEventToStorage(storage, event)
            }
            if eventCount >= getFlushCount() {
                flush(includeInterceptedIdentifyEvent: false)
            }
            completion?()
        } catch {
            amplitude.logger?.error(message: "Error when storing event: \(error.localizedDescription)")
        }
    }

    func flush(includeInterceptedIdentifyEvent: Bool = true, completion: (() -> Void)? = nil) {
        amplitude.logger?.log(message: "Start flushing \(eventCount) events")
        guard let storage = self.storage else { return }

        if includeInterceptedIdentifyEvent {
            do {
                try moveInterceptedIdentifyEventToEvents(storage)
            } catch {
                amplitude.logger?.error(message: "Error when flush intercepted identify event: \(error.localizedDescription)")
            }
        }

        eventCount = 0

        storage.rollover()
        guard let eventFiles: [URL]? = storage.read(key: StorageKey.EVENTS) else { return }
        cleanupUploads()
        if pendingUploads == 0 {
            for eventFile in eventFiles! {
                guard let eventsString = storage.getEventsString(eventBlock: eventFile) else {
                    continue
                }
                if eventsString.isEmpty {
                    continue
                }
                let uploadTask = httpClient.upload(events: eventsString) { [weak self] result in
                    let responseHandler = storage.getResponseHandler(
                        configuration: self!.amplitude.configuration,
                        eventPipeline: self!,
                        eventBlock: eventFile,
                        eventsString: eventsString
                    )
                    responseHandler.handle(result: result)
                    self?.cleanupUploads()
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

    private func getIdentifyUploadInterval() -> TimeInterval {
        let identifyUploadIntervalMillis = max(
            amplitude.configuration.identifyUploadIntervalMillis,
            minIdentifyUploadInterval
        )
        return TimeInterval.milliseconds(identifyUploadIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = amplitude.configuration.flushQueueSize
        return count != 0 ? count : 1
    }

    private func addEventToStorage(_ storage: Storage, _ event: BaseEvent) throws {
        try storage.write(key: StorageKey.EVENTS, value: event)
        eventCount += 1
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

extension EventPipeline {
    private func interceptIdentifyEvent(_ storage: Storage, _ event: BaseEvent) throws {
        var mergedInterceptedIdentifyEvent: BaseEvent?
        let interceptedIdentifyEvent: BaseEvent? = storage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        if let interceptedIdentifyEvent {
            mergedInterceptedIdentifyEvent = identifyInterceptor.mergeIdentifyEvents(event1: interceptedIdentifyEvent, event2: event)
        }

        if let mergedInterceptedIdentifyEvent {
            try writeInterceptedIdentifyEventToStorage(storage, mergedInterceptedIdentifyEvent)
        } else {
            if let interceptedIdentifyEvent {
                try addEventToStorage(storage, interceptedIdentifyEvent)
            }
            if identifyInterceptor.canMergeIdentifyEvent(event) {
                try writeInterceptedIdentifyEventToStorage(storage, event)
            } else {
                try removeInterceptedIdentifyEventFromStorage(storage)
                try addEventToStorage(storage, event)
            }
        }
    }

    private func moveInterceptedIdentifyEventToEvents(_ storage: Storage) throws {
        if let interceptedIdentifyEvent: BaseEvent = storage.read(key: StorageKey.INTERCEPTED_IDENTIFY) {
            try addEventToStorage(storage, interceptedIdentifyEvent)
            try removeInterceptedIdentifyEventFromStorage(storage)
        }
    }

    private func writeInterceptedIdentifyEventToStorage(_ storage: Storage, _ event: BaseEvent) throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: event)
        scheduleInterceptedIdentifyFlush()
    }


    private func removeInterceptedIdentifyEventFromStorage(_ storage: Storage) throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: nil)
        identifyUploadTimer = nil
    }

    private func scheduleInterceptedIdentifyFlush() {
        guard identifyUploadTimer == nil else {
            return
        }

        identifyUploadTimer = QueueTimer(interval: getIdentifyUploadInterval(), repeatInterval: .infinity) { [weak self] in
            let flush = self?.flush
            let storage = self?.storage
            self?.identifyUploadTimer = nil
            if let flush, let storage {
                if let _: BaseEvent = storage.read(key: StorageKey.INTERCEPTED_IDENTIFY) {
                    flush(true, nil)
                }
            }
        }
    }
}
