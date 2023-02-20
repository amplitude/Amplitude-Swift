import Foundation
import XCTest

@testable import Amplitude_Swift

class TestEnrichmentPlugin: Plugin {
    let type: PluginType
    var amplitude: Amplitude?
    let trackCompletion: (() -> Bool)?

    init(trackCompletion: (() -> Bool)? = nil) {
        self.type = PluginType.enrichment
        self.trackCompletion = trackCompletion
    }

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func execute(event: BaseEvent?) -> BaseEvent? {
        var returnEvent: BaseEvent? = event
        if let completion = trackCompletion {
            if !completion() {
                returnEvent = nil
            }
        }
        return returnEvent
    }
}

class OutputReaderPlugin: Plugin {
    var type: PluginType
    var amplitude: Amplitude?

    var lastEvent: BaseEvent?

    init() {
        self.type = .destination
    }

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func execute(event: BaseEvent?) -> BaseEvent? {
        lastEvent = event
        return event
    }
}

class SessionReaderPlugin: Plugin {
    var type: PluginType
    var amplitude: Amplitude?
    var sessionEvents: [BaseEvent]? = Array()

    init() {
        self.type = .destination
    }

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func execute(event: BaseEvent?) -> BaseEvent? {
        guard let eventType = event?.eventType,
            eventType == Constants.AMP_SESSION_START_EVENT || eventType == Constants.AMP_SESSION_END_EVENT
        else { return event }
        sessionEvents?.append(event!)
        return event
    }
}

class FakeInMemoryStorage: Storage {
    typealias EventBlock = URL

    var keyValueStore = [String: Any?]()
    var eventsStore = [URL: [BaseEvent]]()
    var index = URL(string: "0")!
    var interceptedIdentifyEvent: BaseEvent?

    func write(key: StorageKey, value: Any?) throws {
        switch key {
        case .EVENTS:
            if let event = value as? BaseEvent {
                var chunk = eventsStore[index, default: [BaseEvent]()]
                chunk.append(event)
                eventsStore[index] = chunk
            }
        case .INTERCEPTED_IDENTIFY:
            if let event = value as? BaseEvent? {
                interceptedIdentifyEvent = event
            }
        default:
            keyValueStore[key.rawValue] = value
        }
    }

    func read<T>(key: StorageKey) -> T? {
        var result: T?
        switch key {
        case .EVENTS:
            result = Array(eventsStore.keys) as? T
        case .INTERCEPTED_IDENTIFY:
            result = interceptedIdentifyEvent as? T
        default:
            result = keyValueStore[key.rawValue] as? T
        }
        return result
    }

    func getEventsString(eventBlock: EventBlock) -> String? {
        var content: String?
        content = "["
        content = content! + (eventsStore[eventBlock] ?? []).map { $0.toString() }.joined(separator: ", ")
        content = content! + "]"
        return content
    }

    func rollover() {
    }

    func reset() {
        keyValueStore.removeAll()
        eventsStore.removeAll()
        interceptedIdentifyEvent = nil
    }

    func remove(eventBlock: EventBlock) {
        eventsStore.removeValue(forKey: eventBlock)
    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) {
    }

    nonisolated func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: EventBlock,
        eventsString: String
    ) -> ResponseHandler {
        FakeResponseHandler(configuration: configuration, storage: self, eventPipeline: eventPipeline, eventBlock: eventBlock, eventsString: eventsString)
    }
}

class FakeHttpClient: HttpClient {
    var uploadCount: Int = 0
    var uploadedEvents: [String] = []
    var uploadExpectations: [XCTestExpectation] = []

    override func upload(events: String, completion: @escaping (_ result: Result<Int, Error>) -> Void)
        -> URLSessionDataTask?
    {
        uploadCount += 1
        uploadedEvents.append(events)
        if !uploadExpectations.isEmpty {
            uploadExpectations.removeFirst().fulfill()
        }
        completion(Result.success(200))
        return nil
    }
}

class FakeResponseHandler: ResponseHandler {
    let configuration: Configuration
    let storage: FakeInMemoryStorage
    let eventPipeline: EventPipeline
    let eventBlock: URL
    let eventsString: String

    init(
        configuration: Configuration,
        storage: FakeInMemoryStorage,
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

    func handle(result: Result<Int, Error>) {
        switch result {
        case .success(let code):
            handleSuccessResponse(code: code)
        default:
            break
        }
    }

    func handleSuccessResponse(code: Int) {
        storage.remove(eventBlock: eventBlock)
    }

    func handleBadRequestResponse(data: [String: Any]) {
    }

    func handlePayloadTooLargeResponse(data: [String: Any]) {
    }

    func handleTooManyRequestsResponse(data: [String: Any]) {
    }

    func handleTimeoutResponse(data: [String: Any]) {
    }

    func handleFailedResponse(data: [String: Any]) {
    }
}

class FakePersistentStorage: PersistentStorage {
    // Array to store the method invocation history for testing verification purpose
    var haveBeenCalledWith = [String]()

    override func removeEventCallback(insertId: String) {
        haveBeenCalledWith.append("removeEventCallback(insertId: \(insertId))")
    }

    override func remove(eventBlock: EventBlock) {
        haveBeenCalledWith.append("remove(eventBlock: \(eventBlock.absoluteURL))")
    }

    override func write(key: StorageKey, value: Any?) throws {
        haveBeenCalledWith.append("write(key: \(key.rawValue), \(String(describing: value!)))")
    }
}
