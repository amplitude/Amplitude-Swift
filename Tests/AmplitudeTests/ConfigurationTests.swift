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
