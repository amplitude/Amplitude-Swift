//
//  Types.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

public struct Plan: Codable {
    var branch: String?
    var source: String?
    var version: String?
    var versionId: String?
}

public struct IngestionMetadata: Codable {
    var sourceName: String?
    var sourceVersion: String?
}

public protocol EventCallBack {

}

public protocol Storage {
    associatedtype StorageKey: RawRepresentable where StorageKey.RawValue: StringProtocol
    func write(key: StorageKey, value: Any?) async throws
    func read<T>(key: StorageKey) async -> T?
    func reset() async
}

public protocol Logger {
    associatedtype LogLevel: RawRepresentable
    var logLevel: Int? { get set }
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
