//
//  TestAmplitude.swift
//  AmplitudeObjCExampleTests
//
//  Created by Chris Leonavicius on 5/3/24.
//

@testable import AmplitudeSwift
import XCTest

@objc
public class TestAmplitude: ObjCAmplitude {

    @objc
    public override init(configuration: ObjCConfiguration) {
        let config = configuration.configuration
        let updatedConfig = Configuration(apiKey: config.apiKey,
                                          flushQueueSize: config.flushQueueSize,
                                          flushIntervalMillis: config.flushIntervalMillis,
                                          instanceName: config.instanceName,
                                          optOut: config.optOut,
                                          storageProvider: TestStorage(),
                                          identifyStorageProvider: TestStorage(),
                                          logLevel: config.logLevel,
                                          loggerProvider: config.loggerProvider,
                                          minIdLength: config.minIdLength,
                                          partnerId: config.partnerId,
                                          callback: config.callback,
                                          flushMaxRetries: config.flushMaxRetries,
                                          useBatch: config.useBatch,
                                          serverZone: config.serverZone,
                                          serverUrl: "https://127.0.0.1",
                                          plan: config.plan,
                                          ingestionMetadata: config.ingestionMetadata,
                                          trackingOptions: config.trackingOptions,
                                          enableCoppaControl: config.enableCoppaControl,
                                          flushEventsOnClose: config.flushEventsOnClose,
                                          minTimeBetweenSessionsMillis: config.minTimeBetweenSessionsMillis,
                                          autocapture: config.autocapture,
                                          identifyBatchIntervalMillis: config.identifyBatchIntervalMillis,
                                          migrateLegacyData: config.migrateLegacyData,
                                          offline: NetworkConnectivityCheckerPlugin.Disabled)

        super.init(configuration: ObjCConfiguration(configuration: updatedConfig))
    }
}

class TestStorage: Storage {

    private let eventsURL = URL(string: NSTemporaryDirectory())
    private var storage: [String: Any] = [:]
    private var events: [BaseEvent] = []

    func write(key: StorageKey, value: Any?) throws {
        switch key {
        case .EVENTS:
            if let event = value as? BaseEvent {
                events.append(event)
                event.callback?(event, events.count, "")
            }
        default:
            storage[key.rawValue] = value
        }
    }

    func read<T>(key: StorageKey) -> T? {
        switch key {
        case .EVENTS:
            return [eventsURL] as? T
        default:
            return storage[key.rawValue] as? T
        }
    }

    func getEventsString(eventBlock: URL) -> String? {
        let eventsData = try? JSONEncoder().encode(events)
        return eventsData.flatMap { String(data: $0, encoding: .utf8) }
    }

    func remove(eventBlock: URL) {
        // no-op
    }

    func splitBlock(eventBlock: URL, events: [BaseEvent]) {
        // no-op
    }

    func rollover() {
        // no-op
    }

    func reset() {
        storage.removeAll()
        events.removeAll()
    }

    func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: URL,
        eventsString: String
    ) -> ResponseHandler {
        class TestResponseHandler: ResponseHandler {

            func handle(result: Result<Int, Error>) {
                // no-op
            }

            func handleSuccessResponse(code: Int) {
                // no-op
            }

            func handleBadRequestResponse(data: [String: Any]) {
                // no-op
            }

            func handlePayloadTooLargeResponse(data: [String: Any]) {
                // no-op
            }

            func handleTooManyRequestsResponse(data: [String: Any]) {
                // no-op
            }

            func handleTimeoutResponse(data: [String: Any]) {
                // no-op
            }

            func handleFailedResponse(data: [String: Any]) {
                // no-op
            }
        }
        return TestResponseHandler()
    }
}
