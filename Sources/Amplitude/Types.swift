//
//  Types.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public struct Plan: Codable {
    public var branch: String?
    public var source: String?
    public var version: String?
    public var versionId: String?

    public init(branch: String? = nil, source: String? = nil, version: String? = nil, versionId: String? = nil) {
        self.branch = branch
        self.source = source
        self.version = version
        self.versionId = versionId
    }
}

public struct IngestionMetadata: Codable {
    public var sourceName: String?
    public var sourceVersion: String?

    enum CodingKeys: String, CodingKey {
        case sourceName = "source_name"
        case sourceVersion = "source_version"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceName = try values.decodeIfPresent(String.self, forKey: .sourceName)
        sourceVersion = try values.decodeIfPresent(String.self, forKey: .sourceVersion)
    }

    public init(sourceName: String? = nil, sourceVersion: String? = nil) {
        self.sourceName = sourceName
        self.sourceVersion = sourceVersion
    }
}

public typealias EventCallback = (BaseEvent, Int, String) -> Void

public struct LocationInfo {
    public var lat: Double
    public var lng: Double
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

public typealias LocationInfoBlock = () -> LocationInfo

// Swift 5.7 supports any existential type.
// The type of EventBlock has to be determined pre-runtime.
// It cannot be dynamically associated with this protocol.
// https://github.com/apple/swift/issues/62219#issuecomment-1326531801
public protocol Storage {
    func write(key: StorageKey, value: Any?) throws
    func read<T>(key: StorageKey) -> T?
    func getEventsString(eventBlock: URL) -> String?
    func remove(eventBlock: URL)
    func splitBlock(eventBlock: URL, events: [BaseEvent])
    func rollover()
    func reset()
    func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: URL,
        eventsString: String
    ) -> ResponseHandler
}

public enum StorageKey: String, CaseIterable {
    case LAST_EVENT_ID = "last_event_id"
    case PREVIOUS_SESSION_ID = "previous_session_id"
    case LAST_EVENT_TIME = "last_event_time"
    case OPT_OUT = "opt_out"
    case EVENTS = "events"
    case USER_ID = "user_id"
    case DEVICE_ID = "device_id"
}

public protocol Logger {
    associatedtype LogLevel: RawRepresentable
    var logLevel: Int { get set }
    func error(message: String)
    func warn(message: String)
    func log(message: String)
    func debug(message: String)
}

public enum PluginType: String, CaseIterable {
    case before = "Before"
    case enrichment = "Enrichment"
    case destination = "Destination"
    case utility = "Utility"
    case observe = "Observe"
}

public protocol Plugin: AnyObject {
    var type: PluginType { get }
    var amplitude: Amplitude? { get set }
    func setup(amplitude: Amplitude)
    func execute(event: BaseEvent?) -> BaseEvent?
}

public protocol EventPlugin: Plugin {
    func track(event: BaseEvent) -> BaseEvent?
    func identify(event: IdentifyEvent) -> IdentifyEvent?
    func groupIdentify(event: GroupIdentifyEvent) -> GroupIdentifyEvent?
    func revenue(event: RevenueEvent) -> RevenueEvent?
    func flush()
}

extension Plugin {
    // default behavior
    public func execute(event: BaseEvent?) -> BaseEvent? {
        return event
    }

    public func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }
}

public protocol ResponseHandler {
    func handle(result: Result<Int, Error>)
    func handleSuccessResponse(code: Int)
    func handleBadRequestResponse(data: [String: Any])
    func handlePayloadTooLargeResponse(data: [String: Any])
    func handleTooManyRequestsResponse(data: [String: Any])
    func handleTimeoutResponse(data: [String: Any])
    func handleFailedResponse(data: [String: Any])
}

extension ResponseHandler {
    func collectIndices(data: [String: [Int]]) -> Set<Int> {
        var indices = Set<Int>()
        for (_, elements) in data {
            for el in elements {
                indices.insert(el)
            }
        }
        return indices
    }
}
