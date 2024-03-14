import Combine
import Foundation
import Network
import XCTest

@testable import AmplitudeSwift

class TestEnrichmentPlugin: EnrichmentPlugin {
    let trackCompletion: (() -> Bool)?

    init(trackCompletion: (() -> Bool)? = nil) {
        self.trackCompletion = trackCompletion
    }

    override func execute(event: BaseEvent) -> BaseEvent? {
        var returnEvent: BaseEvent? = event
        if let completion = trackCompletion {
            if !completion() {
                returnEvent = nil
            }
        }
        return returnEvent
    }
}

class OutputReaderPlugin: DestinationPlugin {
    var lastEvent: BaseEvent?

    override func execute(event: BaseEvent) -> BaseEvent? {
        lastEvent = event
        return event
    }
}

class EventCollectorPlugin: DestinationPlugin {
    var events: [BaseEvent] = Array()

    override func execute(event: BaseEvent) -> BaseEvent? {
        events.append(event)
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
        eventsStore.removeValue(forKey: eventBlock)
    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) {
    }

    func events() -> [BaseEvent] {
        var result: [BaseEvent] = []
        for (_, value) in eventsStore {
            for event in value {
                result.append(event)
            }
        }
        return result
    }

    nonisolated func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: EventBlock,
        eventsString: String
    ) -> ResponseHandler {
        FakeResponseHandler(
            configuration: configuration, storage: self, eventPipeline: eventPipeline, eventBlock: eventBlock,
            eventsString: eventsString)
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
        DispatchQueue.global().async {
            completion(Result.success(200))
        }
        return nil
    }

    override func getDate() -> Date {
        // timestamp of 2023-10-24T18:16:24.000 in UTC time zone
        return Date(timeIntervalSince1970: 1_698_171_384)
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

    override func read<T>(key: StorageKey) -> T? {
        haveBeenCalledWith.append("read(key: \(key.rawValue))")
        return nil
    }
}

class TestPersistentStorage: PersistentStorage {
    func events() -> [BaseEvent] {
        var result: [BaseEvent] = []

        let eventFiles: [URL]? = read(key: StorageKey.EVENTS)
        if let eventFiles {
            for eventFile in eventFiles {
                guard let eventsString = getEventsString(eventBlock: eventFile) else {
                    continue
                }
                if eventsString.isEmpty {
                    continue
                }

                if let events = BaseEvent.fromArrayString(jsonString: eventsString) {
                    for event in events {
                        result.append(event)
                    }
                }
            }
        }

        return result
    }
}

class TestIdentifyInterceptor: IdentifyInterceptor {
    private var overridenIdentifyBatchIntervalMillis: Int?

    override func getIdentifyBatchInterval() -> TimeInterval {
        if let overridenIdentifyBatchIntervalMillis {
            return TimeInterval.milliseconds(overridenIdentifyBatchIntervalMillis)
        }
        return super.getIdentifyBatchInterval()
    }

    public func setIdentifyBatchInterval(_ identifyBatchIntervalMillis: Int) {
        overridenIdentifyBatchIntervalMillis = identifyBatchIntervalMillis
    }
}

class FakeSandboxHelperWithAppSandboxContainer: SandboxHelper {
    override func getEnvironment() -> [String: String] {
        return ["APP_SANDBOX_CONTAINER_ID": "test-container-id"]
    }
}

class FakePersistentStorageAppSandboxEnabled: PersistentStorage {
    override internal func isStorageSandboxed() -> Bool {
        return true
    }
}

class FakeAmplitudeWithNoInstNameOnlyMigration: Amplitude {
    override func migrateInstanceOnlyStorages() {
        // do nothing
    }
}

class FakeAmplitudeWithSandboxEnabled: Amplitude {
    override internal func isSandboxEnabled() -> Bool {
        return true
    }
}

final class MockPathCreation: PathCreationProtocol {
    var networkPathPublisher: AnyPublisher<NetworkPath, Never>?
    private let subject = PassthroughSubject<NetworkPath, Never>()

    func start() {
        networkPathPublisher = subject.eraseToAnyPublisher()
    }

    // Method to simulate network change in tests
    func simulateNetworkChange(status: NWPath.Status) {
        let networkPath = NetworkPath(status: status)
        subject.send(networkPath)
    }
}

class SessionsWithDelayedEventStartProcessing: Sessions {
    override func processEvent(event: BaseEvent, inForeground: Bool) -> [BaseEvent] {
        if event.eventType == Constants.AMP_SESSION_START_EVENT {
            sleep(3)
        }
        return super.processEvent(event: event, inForeground: inForeground)
    }
}
