//
//  Types.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

@objc public class Plan: NSObject, Codable {
    var branch: String?
    var source: String?
    var version: String?
    var versionId: String?
}

@objc public class IngestionMetadata: NSObject, Codable {
    var sourceName: String?
    var sourceVersion: String?
}

public typealias EventCallback = (BaseEvent, Int, String) -> Void

@objc public class LocationInfo : NSObject {
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

@objc public enum StorageKey: Int, RawRepresentable, CaseIterable {
    case LAST_EVENT_ID
    case PREVIOUS_SESSION_ID
    case LAST_EVENT_TIME
    case OPT_OUT
    case EVENTS
    case USER_ID
    case DEVICE_ID

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
            case .LAST_EVENT_ID:
                return "last_event_id"
            case .PREVIOUS_SESSION_ID:
                return "previous_session_id"
            case .LAST_EVENT_TIME:
                return "last_event_time"
            case .OPT_OUT:
                return "opt_out"
            case .EVENTS:
                return "events"
            case .USER_ID:
                return "user_id"
            case .DEVICE_ID:
                return "device_id"
            }
        }

    public init?(rawValue: RawValue) {
        switch rawValue {
            case "last_event_id":
                self = .LAST_EVENT_ID
            case "previous_session_id":
                self = .PREVIOUS_SESSION_ID
            case "last_event_time":
                self = .LAST_EVENT_TIME
            case "opt_out":
                self = .OPT_OUT
            case "events":
                self = .EVENTS
            case "user_id":
                self = .USER_ID
            case "device_id":
                self = .DEVICE_ID
            default:
                return nil
        }
    }
}

 public protocol Logger {
    associatedtype LogLevel: RawRepresentable
    var logLevel: Int { get set }
    func error(message: String)
    func warn(message: String)
    func log(message: String)
    func debug(message: String)
}
/*
@objc public enum PluginType: String, CaseIterable {
    case before = "Before"
    case enrichment = "Enrichment"
    case destination = "Destination"
    case utility = "Utility"
    case observe = "Observe"
}
*/

@objc public enum PluginType: Int, RawRepresentable, CaseIterable {
        case before
        case enrichment
        case destination
        case utility
        case observe

    public typealias RawValue = String

    public var rawValue: RawValue {
            switch self {
                case .before:
                    return "Before"
                case .enrichment:
                    return "Enrichment"
                case .destination:
                    return "Destination"
                case .utility:
                    return "Utility"
                case .observe:
                    return "Observe"
            }
        }

    public init?(rawValue: RawValue) {
        switch rawValue {
            case "Before":
                self = .before
            case "Enrichment":
                self = .enrichment
            case "Destination":
                self = .destination
            case "Utility":
                self = .utility
            case "Observe":
                self = .observe
            default:
                return nil
        }
    }
}

@objc public protocol Plugin: AnyObject {
    @objc var type: PluginType { get }
    @objc var amplitude: Amplitude? { get set }
    @objc func setup(amplitude: Amplitude)
    @objc func execute(event: BaseEvent?) -> BaseEvent?
}

@objc public protocol EventPlugin: Plugin {
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
