//
//  NetworkConnectivityCheckerPluginTests.swift
//  Amplitude-SwiftTests
//
//  Created by Xinyi.Ye on 1/29/24.
//

import XCTest

@testable import AmplitudeSwift

final class NetworkConnectivityCheckerPluginTests: XCTestCase {
    private var mockPathCreation: MockPathCreation!
    private var plugin: NetworkConnectivityCheckerPlugin!
    private var amplitude: Amplitude!

    override func setUp() {
        super.setUp()
        mockPathCreation = MockPathCreation()
        // Disabled keeps Amplitude.init from installing its own NetworkConnectivityCheckerPlugin,
        // whose real NWPathMonitor also writes configuration.offline from the tracking queue --
        // a second writer racing the mock-driven plugin under test, which on a busy runner
        // flipped the value back between simulateNetworkChange and the assertion.
        amplitude = Amplitude(configuration: Configuration(apiKey: "test-api-key",
                                                           offline: NetworkConnectivityCheckerPlugin.Disabled))
        plugin = NetworkConnectivityCheckerPlugin(pathCreation: mockPathCreation)
        plugin.setup(amplitude: amplitude)
    }

    func testNetworkBecomesOnline() {
        mockPathCreation.simulateNetworkChange(status: .satisfied)
        XCTAssertEqual(amplitude.configuration.offline, false)
    }

    func testNetworkBecomesOffline() {
        mockPathCreation.simulateNetworkChange(status: .unsatisfied)
        XCTAssertEqual(amplitude.configuration.offline, true)
    }
}
