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

actor FakeInMemoryStorage: Storage {
    typealias EventBlock = URL

    var keyValueStore = [String: Any?]()
    var eventsStore = [URL: [BaseEvent]]()
    var index = URL(string: "0")!

    func write(key: StorageKey, value: Any?) async throws {
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

    func read<T>(key: StorageKey) async -> T? {
        var result: T?
        switch key {
        case .EVENTS:
            result = Array(eventsStore.keys) as? T
        default:
            result = keyValueStore[key.rawValue] as? T
        }
        return result
    }

    func getEventsString(eventBlock: EventBlock) async -> String? {
        var content: String?
        content = "["
        content = content! + (eventsStore[eventBlock] ?? []).map { $0.toString() }.joined(separator: ", ")
        content = content! + "]"
        return content
    }

    func rollover() async {
    }

    func reset() async {
        keyValueStore.removeAll()
        eventsStore.removeAll()
    }

    func remove(eventBlock: EventBlock) async {
    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) async {
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

    func handleSuccessResponse(code: Int) async {
    }

    func handleBadRequestResponse(data: [String: Any]) async {
    }

    func handlePayloadTooLargeResponse(data: [String: Any]) async {
    }

    func handleTooManyRequestsResponse(data: [String: Any]) {
    }

    func handleTimeoutResponse(data: [String: Any]) {
    }

    func handleFailedResponse(data: [String: Any]) {
    }
}
