//
//  EventPipeline.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

public class EventPipeline {
    var httpClient: HttpClient
    let storage: Storage?
    let logger: (any Logger)?
    let configuration: Configuration

    @Atomic internal var eventCount: Int = 0
    internal var flushTimer: QueueTimer?
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.amplitude.com")

    internal struct UploadTaskInfo {
        let events: String
        let task: URLSessionDataTask
    }
    private var uploads = [URL: UploadTaskInfo]()

    init(amplitude: Amplitude) {
        storage = amplitude.storage
        logger = amplitude.logger
        configuration = amplitude.configuration
        httpClient = HttpClient(configuration: amplitude.configuration,
                                diagnostics: amplitude.configuration.diagonostics,
                                callbackQueue: amplitude.trackingQueue)
        flushTimer = QueueTimer(interval: getFlushInterval(), queue: amplitude.trackingQueue) { [weak self] in
            self?.flush()
        }
    }

    func put(event: BaseEvent, completion: (() -> Void)? = nil) {
        guard let storage = self.storage else { return }
        event.attempts += 1
        do {
            try storage.write(key: StorageKey.EVENTS, value: event)
            eventCount += 1
            if eventCount >= getFlushCount() {
                flush()
            }
            completion?()
        } catch {
            logger?.error(message: "Error when storing event: \(error.localizedDescription)")
        }
    }

    func flush(completion: (() -> Void)? = nil) {
        if configuration.offline == true {
            logger?.debug(message: "Skipping flush while offline.")
            return
        }

        logger?.log(message: "Start flushing \(eventCount) events")
        eventCount = 0
        guard let storage = self.storage else { return }
        storage.rollover()
        guard let eventFiles: [URL] = storage.read(key: StorageKey.EVENTS) else { return }
        for eventFile in eventFiles {
            uploadsQueue.sync {
                guard uploads[eventFile] == nil else {
                    logger?.log(message: "Existing upload in progress, skipping...")
                    return
                }
                guard let eventsString = storage.getEventsString(eventBlock: eventFile),
                      !eventsString.isEmpty else {
                    return
                }
                let uploadTask = httpClient.upload(events: eventsString) { [self] result in
                    let responseHandler = storage.getResponseHandler(
                        configuration: self.configuration,
                        eventPipeline: self,
                        eventBlock: eventFile,
                        eventsString: eventsString
                    )
                    responseHandler.handle(result: result)
                    self.completeUpload(for: eventFile)
                }
                if let uploadTask {
                    uploads[eventFile] = UploadTaskInfo(events: eventsString, task: uploadTask)
                }
            }
        }
        completion?()
    }

    func start() {
        flushTimer?.resume()
    }

    func stop() {
        flushTimer?.suspend()
    }

    private func getFlushInterval() -> TimeInterval {
        return TimeInterval.milliseconds(configuration.flushIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = configuration.flushQueueSize
        return count != 0 ? count : 1
    }
}

extension EventPipeline {

    func completeUpload(for eventBlock: URL) {
        uploadsQueue.sync {
            uploads[eventBlock] = nil
        }
    }
}
