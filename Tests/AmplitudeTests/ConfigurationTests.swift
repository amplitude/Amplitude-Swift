//
//  ConfigurationTests.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import XCTest

@testable import AmplitudeSwift

final class ConfigurationTests: XCTestCase {
    let apiKey = "testApiKey"

    func testConfigurationInit() {
        let configuration = Configuration(apiKey: apiKey, httpClient: RemoteConfigMockServer())
        XCTAssertEqual(
            configuration.apiKey,
            apiKey
        )
    }

    func testDefaultStoresWaitForAmplitudeToMigrateLegacyFiles() throws {
        let instanceName = UUID().uuidString
        let seed = Configuration(apiKey: apiKey, instanceName: instanceName, httpClient: RemoteConfigMockServer())
        let events = try XCTUnwrap(seed.storageProvider as? PersistentStorage)
        let identifies = try XCTUnwrap(seed.identifyStorageProvider as? PersistentStorage)
        defer {
            events.reset()
            identifies.reset()
        }

        func seedLegacyFile(in store: PersistentStorage) throws -> URL {
            store.userDefaults?.set(1, forKey: store.storageVersionKey)
            let url = store.getLegacyEventsStorageDirectory().appendingPathComponent("0")
            let json = "[\(BaseEvent(eventType: "legacy").toString())]"
            try json.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
        let legacyEvent = try seedLegacyFile(in: events)
        let legacyIdentify = try seedLegacyFile(in: identifies)

        let config = Configuration(apiKey: apiKey, instanceName: instanceName, optOut: true,
                                   autocapture: [], httpClient: RemoteConfigMockServer())
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyEvent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyIdentify.path))

        let earlyStore = try XCTUnwrap(config.storageProvider as? PersistentStorage)
        let earlyIdentifies = try XCTUnwrap(config.identifyStorageProvider as? PersistentStorage)
        let earlyEvents: [URL]? = earlyStore.read(key: .EVENTS)
        XCTAssertEqual(earlyEvents, [])
        earlyIdentifies.reset()
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyEvent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyIdentify.path))

        let event = BaseEvent(eventType: "before-startup")
        event.insertId = "before-startup"
        event.callback = { _, _, _ in }
        try earlyStore.write(key: .EVENTS, value: event)

        let amplitude = Amplitude(configuration: config)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyIdentify.path))
        XCTAssertEqual(identifies.userDefaults?.integer(forKey: identifies.storageVersionKey), 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyEvent.path))
        let runtimeStore = try XCTUnwrap(amplitude.storage as? PersistentStorage)
        XCTAssertTrue(runtimeStore === earlyStore)
        for (store, expected) in [(runtimeStore, ["before-startup", "legacy"]), (earlyIdentifies, ["legacy"])] {
            let blocks: [URL] = try XCTUnwrap(store.read(key: .EVENTS))
            let types = try blocks.flatMap { block -> [String] in
                let json = try XCTUnwrap(store.getEventsString(eventBlock: block))
                return try XCTUnwrap(BaseEvent.fromArrayString(jsonString: json)).map(\.eventType)
            }
            XCTAssertEqual(types.sorted(), expected)
        }
        XCTAssertNotNil(runtimeStore.getEventCallback(insertId: "before-startup"))
        runtimeStore.removeEventCallback(insertId: "before-startup")
        XCTAssertNil(earlyStore.getEventCallback(insertId: "before-startup"))
    }

    func testExplicitMigrationOnlyMigratesTheSelectedProvider() throws {
        let config = Configuration(apiKey: apiKey, instanceName: UUID().uuidString, optOut: true,
                                   autocapture: [], httpClient: RemoteConfigMockServer())
        let stores = try [config.storageProvider, config.identifyStorageProvider].map { try XCTUnwrap($0 as? PersistentStorage) }
        defer { stores.forEach { $0.reset() } }

        for store in stores {
            let legacyFile = store.getLegacyEventsStorageDirectory().appendingPathComponent("0")
            try "[\(BaseEvent(eventType: "legacy").toString())]".write(to: legacyFile, atomically: true, encoding: .utf8)
        }
        config.storageProvider.migrateIfNeeded()
        config.storageProvider.migrateIfNeeded()
        let earlyIdentifies: [URL]? = config.identifyStorageProvider.read(key: .EVENTS)
        XCTAssertEqual(earlyIdentifies, [])
        config.identifyStorageProvider.migrateIfNeeded()

        for store in stores {
            let blocks: [URL] = try XCTUnwrap(store.read(key: .EVENTS))
            XCTAssertEqual(blocks.map(\.lastPathComponent), ["v2-0"])
            let block = try XCTUnwrap(blocks.first)
            let json = try XCTUnwrap(store.getEventsString(eventBlock: block))
            XCTAssertEqual(BaseEvent.fromArrayString(jsonString: json)?.first?.eventType, "legacy")
        }
    }

    func testExplicitAndStartupMigrationErrorsAreIncludedInTheAnalyticsUpload() throws {
        let instance = UUID().uuidString
        let seed = Configuration(apiKey: apiKey, instanceName: instance, httpClient: RemoteConfigMockServer())
        let events = try XCTUnwrap(seed.storageProvider as? PersistentStorage)
        let identifies = try XCTUnwrap(seed.identifyStorageProvider as? PersistentStorage)
        defer {
            events.reset()
            identifies.reset()
        }
        for (store, filename) in [(events, "before-start"), (identifies, "at-start")] {
            store.userDefaults?.set(1, forKey: store.storageVersionKey)
            let file = store.getLegacyEventsStorageDirectory().appendingPathComponent(filename)
            try Data([0xff]).write(to: file)
        }

        let config = Configuration(apiKey: apiKey, instanceName: instance, optOut: true,
                                   autocapture: [], httpClient: RemoteConfigMockServer())
        config.storageProvider.migrateIfNeeded()
        let amplitude = Amplitude(configuration: config)
        let client = EventPipeline(amplitude: amplitude).httpClient
        let data = try XCTUnwrap(client.getRequestData(events: "[]").data?.gunzipped())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metadata = try XCTUnwrap(body["request_metadata"] as? [String: Any])
        let sdk = try XCTUnwrap(metadata["sdk"] as? [String: Any])
        let errors = try XCTUnwrap(sdk["error_logs"] as? [String]).filter { $0.contains("Error migrating file:") }
        XCTAssertEqual(errors.count, 2)
        XCTAssertTrue(errors.contains { $0.contains("/before-start ") })
        XCTAssertTrue(errors.contains { $0.contains("/at-start ") })
    }

    func testCustomProvidersAreReusedAtStartup() {
        let events = FakeInMemoryStorage()
        let identifies = FakeInMemoryStorage()
        let config = Configuration(apiKey: apiKey, storageProvider: events, identifyStorageProvider: identifies,
                                   httpClient: RemoteConfigMockServer())
        XCTAssertTrue(config.storageProvider as? FakeInMemoryStorage === events)
        XCTAssertTrue(config.identifyStorageProvider as? FakeInMemoryStorage === identifies)

        config.storageProvider.migrateIfNeeded()
        XCTAssertEqual(events.migrationCalls, 1)
        XCTAssertEqual(identifies.migrationCalls, 0)

        let amplitude = Amplitude(configuration: config)
        XCTAssertEqual(events.migrationCalls, 2)
        XCTAssertEqual(identifies.migrationCalls, 1)
        XCTAssertTrue(amplitude.storage as? FakeInMemoryStorage === events)
        XCTAssertTrue(amplitude.identifyStorage as? FakeInMemoryStorage === identifies)
    }

    func testConfigurationIsValid() {
        var configuration = Configuration(apiKey: apiKey, httpClient: RemoteConfigMockServer())
        XCTAssertTrue(configuration.isValid())

        configuration = Configuration(
            apiKey: apiKey,
            flushQueueSize: 100,
            flushIntervalMillis: 3000,
            minIdLength: 10,
            httpClient: RemoteConfigMockServer()
        )
        XCTAssertTrue(configuration.isValid())

        configuration = Configuration(apiKey: "", httpClient: RemoteConfigMockServer())
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, flushQueueSize: -10, httpClient: RemoteConfigMockServer())
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, flushIntervalMillis: -1000, httpClient: RemoteConfigMockServer())
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, minTimeBetweenSessionsMillis: -3000, httpClient: RemoteConfigMockServer())
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, minIdLength: 0, httpClient: RemoteConfigMockServer())
        XCTAssertFalse(configuration.isValid())
    }

    func testStorageByApiKeyAndInstanceName() throws {
        let configuration = Configuration(apiKey: "migration-api-key", httpClient: RemoteConfigMockServer())

        let expectedStoragePostfix = "\(configuration.apiKey)-\(configuration.getNormalizeInstanceName())"

        let eventsStorage = configuration.storageProvider as? PersistentStorage
        let eventStorageUrl = eventsStorage != nil
            ? eventsStorage?.getEventsStorageDirectory(createDirectory: false).absoluteString
            : ""

        let identifyStorage = configuration.storageProvider as? PersistentStorage
        let identifyStorageUrl = identifyStorage != nil
        ? identifyStorage?.getEventsStorageDirectory(createDirectory: false).absoluteString
            : ""

        XCTAssertTrue(eventStorageUrl?.contains(expectedStoragePostfix) ?? false)
        XCTAssertTrue(identifyStorageUrl?.contains(expectedStoragePostfix) ?? false)
    }

    func testStorageByApiKeyAndInstanceNameWithCustomInstanceName() throws {
        let configuration = Configuration(
            apiKey: "migration-api-key",
            instanceName: "test-instance",
            httpClient: RemoteConfigMockServer()
        )

        let expectedStoragePostfix = "\(configuration.apiKey)-\(configuration.getNormalizeInstanceName())"

        let eventsStorage = configuration.storageProvider as? PersistentStorage
        let eventStorageUrl = eventsStorage != nil
            ? eventsStorage?.getEventsStorageDirectory(createDirectory: false).absoluteString
            : ""

        let identifyStorage = configuration.storageProvider as? PersistentStorage
        let identifyStorageUrl = identifyStorage != nil
        ? identifyStorage?.getEventsStorageDirectory(createDirectory: false).absoluteString
            : ""

        XCTAssertTrue(eventStorageUrl?.contains(expectedStoragePostfix) ?? false)
        XCTAssertTrue(identifyStorageUrl?.contains(expectedStoragePostfix) ?? false)
    }
}
