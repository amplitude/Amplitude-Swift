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

    internal struct UploadTaskInfo {
        let events: String
        let task: URLSessionDataTask
    }
    private var uploads = [URL: UploadTaskInfo]()

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
        self.httpClient = HttpClient(configuration: amplitude.configuration, diagnostics: amplitude.configuration.diagonostics)
        self.flushTimer = QueueTimer(interval: getFlushInterval()) { [weak self] in
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
            amplitude.logger?.error(message: "Error when storing event: \(error.localizedDescription)")
        }
    }

    func flush(completion: (() -> Void)? = nil) {
        if self.amplitude.configuration.offline == true {
            self.amplitude.logger?.debug(message: "Skipping flush while offline.")
            return
        }

        amplitude.logger?.log(message: "Start flushing \(eventCount) events")
        eventCount = 0
        guard let storage = self.storage else { return }
        storage.rollover()
        guard let eventFiles: [URL] = storage.read(key: StorageKey.EVENTS) else { return }
        for eventFile in eventFiles {
            uploadsQueue.sync {
                guard uploads[eventFile] == nil else {
                    amplitude.logger?.log(message: "Existing upload in progress, skipping...")
                    return
                }
                guard let eventsString = storage.getEventsString(eventBlock: eventFile),
                      !eventsString.isEmpty else {
                    return
                }
                let uploadTask = httpClient.upload(events: eventsString) { [weak self] result in
                    guard let self else {
                        return
                    }
                    let responseHandler = storage.getResponseHandler(
                        configuration: self.amplitude.configuration,
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
        return TimeInterval.milliseconds(amplitude.configuration.flushIntervalMillis)
    }

    private func getFlushCount() -> Int {
        let count = amplitude.configuration.flushQueueSize
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
