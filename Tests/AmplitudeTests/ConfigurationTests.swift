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
        let configuration = Configuration(apiKey: apiKey)
        XCTAssertEqual(
            configuration.apiKey,
            apiKey
        )
    }

    func testConfigurationIsValid() {
        var configuration = Configuration(apiKey: apiKey)
        XCTAssertTrue(configuration.isValid())

        configuration = Configuration(
            apiKey: apiKey,
            flushQueueSize: 100,
            flushIntervalMillis: 3000,
            minIdLength: 10
        )
        XCTAssertTrue(configuration.isValid())

        configuration = Configuration(apiKey: "")
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, flushQueueSize: -10)
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, flushIntervalMillis: -1000)
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, minTimeBetweenSessionsMillis: -3000)
        XCTAssertFalse(configuration.isValid())

        configuration = Configuration(apiKey: apiKey, minIdLength: 0)
        XCTAssertFalse(configuration.isValid())
    }

    func testStorageByApiKeyAndInstanceName() throws {
        let configuration = Configuration(apiKey: "migration-api-key")

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
            instanceName: "test-instance"
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

    func testDefaultTrackingOptionChangesReflectInAutocapture() {
        let configuration = Configuration(
            apiKey: "test-api-key"
        )

        XCTAssertTrue(configuration.autocapture.contains(.sessions))

        (configuration as DeprecationWarningDiscardable).setDefaulTracking(sessions: false, appLifecycles: true, screenViews: true)

        XCTAssertFalse(configuration.autocapture.contains(.sessions))
        XCTAssertTrue(configuration.autocapture.contains(.appLifecycles))
        XCTAssertTrue(configuration.autocapture.contains(.screenViews))
    }

    func testDefaultTrackingInstanceChangeReflectInAutocapture() {
        let configuration = Configuration(
            apiKey: "test-api-key"
        )

        (configuration as DeprecationWarningDiscardable).setDefaulTracking(sessions: false, appLifecycles: true, screenViews: true)

        XCTAssertFalse(configuration.autocapture.contains(.sessions))
        XCTAssertTrue(configuration.autocapture.contains(.appLifecycles))
        XCTAssertTrue(configuration.autocapture.contains(.screenViews))
    }
}

private protocol DeprecationWarningDiscardable {
    func setDefaulTracking(sessions: Bool, appLifecycles: Bool, screenViews: Bool)
    func setDefaulTrackingOptions(sessions: Bool, appLifecycles: Bool, screenViews: Bool)
}

extension Configuration: DeprecationWarningDiscardable {
    @available(*, deprecated)
    func setDefaulTracking(sessions: Bool, appLifecycles: Bool, screenViews: Bool) {
        defaultTracking = DefaultTrackingOptions(sessions: sessions, appLifecycles: appLifecycles, screenViews: screenViews)
    }

    @available(*, deprecated)
    func setDefaulTrackingOptions(sessions: Bool, appLifecycles: Bool, screenViews: Bool) {
        defaultTracking.sessions = sessions
        defaultTracking.appLifecycles = appLifecycles
        defaultTracking.screenViews = screenViews
    }
}
