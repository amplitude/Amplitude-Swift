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

    func testDefaultStoreMigrationsWaitForStartupOrDirectAccess() throws {
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyEvent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyIdentify.path))
        let blocks: [URL] = try XCTUnwrap(earlyStore.read(key: .EVENTS))
        let block = try XCTUnwrap(blocks.first)
        XCTAssertEqual(block.lastPathComponent, "v2-0")
        let json = try XCTUnwrap(earlyStore.getEventsString(eventBlock: block))
        XCTAssertEqual(BaseEvent.fromArrayString(jsonString: json)?.first?.eventType, "legacy")

        let amplitude = Amplitude(configuration: config)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyIdentify.path))
        XCTAssertEqual(identifies.userDefaults?.integer(forKey: identifies.storageVersionKey), 2)
        XCTAssertTrue(amplitude.storage as? PersistentStorage === earlyStore)
    }

    func testConcurrentFirstAccessReusesOneDefaultStore() {
        let config = Configuration(apiKey: apiKey, instanceName: UUID().uuidString, httpClient: RemoteConfigMockServer())
        let instances = AtomicRef(wrappedValue: Set<ObjectIdentifier>())
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            let provider = config.storageProvider as AnyObject
            instances.withLock { _ = $0.insert(ObjectIdentifier(provider)) }
        }
        XCTAssertEqual(instances.wrappedValue.count, 1)
        config.storageProvider.reset()
    }

    func testCustomProvidersAreReusedAtStartup() {
        let events = FakeInMemoryStorage()
        let identifies = FakeInMemoryStorage()
        let config = Configuration(apiKey: apiKey, storageProvider: events, identifyStorageProvider: identifies,
                                   httpClient: RemoteConfigMockServer())
        XCTAssertTrue(config.storageProvider as? FakeInMemoryStorage === events)
        XCTAssertTrue(config.identifyStorageProvider as? FakeInMemoryStorage === identifies)

        let amplitude = Amplitude(configuration: config)
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
