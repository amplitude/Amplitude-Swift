import Foundation

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

class FakeInMemoryStorage: Storage {
    typealias EventBlock = URL

    var keyValueStore = [String: Any?]()
    var eventsStore = [URL: [BaseEvent]]()
    var index = URL(string: "0")!

    func write(key: StorageKey, value: Any?) throws {
        switch key {
        case .EVENTS:
            if let event = value as? BaseEvent {
                var chunk = eventsStore[index, default: [BaseEvent]()]
                chunk.append(event)
                eventsStore[index] = chunk
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
    }

    func remove(eventBlock: EventBlock) {
    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) {
    }

    nonisolated func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: EventBlock,
        eventsString: String
    ) -> ResponseHandler {
        FakeResponseHandler()
    }
}

class FakeHttpClient: HttpClient {
    var isUploadCalled: Bool = false

    override func upload(events: String, completion: @escaping (_ result: Result<Int, Error>) -> Void)
        -> URLSessionDataTask?
    {
        isUploadCalled = true
        return nil
    }
}

class FakeResponseHandler: ResponseHandler {
    func handle(result: Result<Int, Error>) {
    }

    func handleSuccessResponse(code: Int) {
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
}
