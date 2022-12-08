//
//  PersistentStorageResponseHandler.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import Foundation

class PersistentStorageResponseHandler: ResponseHandler {
    var configuration: Configuration
    var storage: PersistentStorage
    var eventPipeline: EventPipeline
    var eventBlock: URL
    var eventsString: String

    init(
        configuration: Configuration,
        storage: PersistentStorage,
        eventPipeline: EventPipeline,
        eventBlock: URL,
        eventsString: String
    ) {
        self.configuration = configuration
        self.storage = storage
        self.eventPipeline = eventPipeline
        self.eventBlock = eventBlock
        self.eventsString = eventsString
    }

    func handleSuccessResponse(code: Int) {
        guard let events = BaseEvent.fromArrayString(jsonString: eventsString) else {
            storage.remove(eventBlock: eventBlock)
            removeEventCallbackByEventsString(eventsString: eventsString)
            return
        }
        triggerEventsCallback(events: events, code: code, message: "Successfully send event")
        storage.remove(eventBlock: eventBlock)
    }

    func handleBadRequestResponse(data: [String: Any]) {
        guard let events = BaseEvent.fromArrayString(jsonString: eventsString) else {
            storage.remove(eventBlock: eventBlock)
            removeEventCallbackByEventsString(eventsString: eventsString)
            return
        }

        if events.count == 1 {
            let error = data["error"] as? String ?? ""
            triggerEventsCallback(
                events: events,
                code: HttpClient.HttpStatus.BAD_REQUEST.rawValue,
                message: error
            )
            storage.remove(eventBlock: eventBlock)
            return
        }

        var dropIndexes = Set<Int>()
        if let eventsWithInvalidFields = data["events_with_invalid_fields"] as? [String: [Int]] {
            dropIndexes.formUnion(collectIndices(data: eventsWithInvalidFields))
        }
        if let eventsWithMissingFields = data["events_with_missing_fields"] as? [String: [Int]] {
            dropIndexes.formUnion(collectIndices(data: eventsWithMissingFields))
        }
        if let silencedEvents = data["silenced_events"] as? [Int] {
            dropIndexes.formUnion(silencedEvents)
        }
        var silencedDevices = Set<String>()
        if let silencedDevicesArray = data["silenced_devices"] as? [String] {
            silencedDevices.formUnion(silencedDevicesArray)
        }

        var eventsToDrop = [BaseEvent]()
        var eventsToRetry = [BaseEvent]()
        for (index, event) in events.enumerated() {
            if dropIndexes.contains(index) || (event.deviceId != nil && silencedDevices.contains(event.deviceId!)) {
                eventsToDrop.append(event)
            } else {
                eventsToRetry.append(event)
            }
        }

        let error = data["error"] as? String ?? ""
        triggerEventsCallback(events: eventsToDrop, code: HttpClient.HttpStatus.BAD_REQUEST.rawValue, message: error)

        eventsToRetry.forEach { event in
            eventPipeline.put(event: event)
        }

        storage.remove(eventBlock: eventBlock)
    }

    func handlePayloadTooLargeResponse(data: [String: Any]) {
        guard let events = BaseEvent.fromArrayString(jsonString: eventsString) else {
            storage.remove(eventBlock: eventBlock)
            removeEventCallbackByEventsString(eventsString: eventsString)
            return
        }
        if events.count == 1 {
            let error = data["error"] as? String ?? ""
            triggerEventsCallback(
                events: events,
                code: HttpClient.HttpStatus.PAYLOAD_TOO_LARGE.rawValue,
                message: error
            )
            storage.remove(eventBlock: eventBlock)
            return
        }
        storage.splitBlock(eventBlock: eventBlock, events: events)
    }

    func handleTooManyRequestsResponse(data: [String: Any]) {
        // wait for next time to pick it up
    }

    func handleTimeoutResponse(data: [String: Any]) {
        // Wait for next time to pick it up
    }

    func handleFailedResponse(data: [String: Any]) {
        // wait for next time to try again
    }

    func handle(result: Result<Int, Error>) {
        switch result {
        case .success(let code):
            // We don't care about the data when success
            handleSuccessResponse(code: code)
        case .failure(let error):
            switch error {
            case HttpClient.Exception.httpError(let code, let data):
                var json = [String: Any]()
                if data != nil {
                    json = (try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]) ?? json
                }
                switch code {
                case HttpClient.HttpStatus.BAD_REQUEST.rawValue:
                    handleBadRequestResponse(data: json)
                case HttpClient.HttpStatus.PAYLOAD_TOO_LARGE.rawValue:
                    handlePayloadTooLargeResponse(data: json)
                case HttpClient.HttpStatus.TIMEOUT.rawValue:
                    handleTimeoutResponse(data: json)
                case HttpClient.HttpStatus.TOO_MANY_REQUESTS.rawValue:
                    handleTooManyRequestsResponse(data: json)
                case HttpClient.HttpStatus.FAILED.rawValue:
                    handleFailedResponse(data: json)
                default:
                    handleFailedResponse(data: json)
                }
            default:
                break
            }
        }
    }
}

extension PersistentStorageResponseHandler {
    private func triggerEventsCallback(events: [BaseEvent], code: Int, message: String) {
        events.forEach { event in
            configuration.callback?(event, code, message)
            if let eventInsertId = event.insertId, let eventCallback = storage.getEventCallback(insertId: eventInsertId)
            {
                eventCallback(event, code, message)
                storage.removeEventCallback(insertId: eventInsertId)
            }
        }
    }

    func removeEventCallbackByEventsString(eventsString: String) {
        guard let regex = try? NSRegularExpression(pattern: #"\"insert_id\":\"(.{36})\","#) else {
            return
        }
        let eventsNSString = NSString(string: eventsString)
        regex.matches(in: eventsString, options: [], range: NSRange(location: 0, length: eventsNSString.length)).forEach
        { match in
            (1..<match.numberOfRanges).forEach {
                if match.range(at: $0).location != NSNotFound {
                    let eventInsertId = eventsNSString.substring(with: match.range(at: $0))
                    storage.removeEventCallback(insertId: eventInsertId)
                }
            }
        }
    }
}
