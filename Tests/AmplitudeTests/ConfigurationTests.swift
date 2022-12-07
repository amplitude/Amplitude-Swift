//
//  ConfigurationTests.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import XCTest

@testable import Amplitude_Swift

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
}
