//
//  AutocaptureRemoteConfigTests.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 4/29/25.
//

import AmplitudeCore
@_spi(Frustration)
@testable
import AmplitudeSwift
import ObjectiveC
import XCTest

class AutocaptureRemoteConfigTests: XCTestCase {

    private static func swizzleUrlSessionConfiguration() {
        let originalMethod = class_getInstanceMethod(URLSessionConfiguration.self,
                                         #selector(getter: URLSessionConfiguration.protocolClasses))
        let swizzledMethod = class_getInstanceMethod(URLSessionConfiguration.self,
                                         #selector(getter: URLSessionConfiguration.amp_protocolClasses))

        guard let originalMethod, let swizzledMethod else {
            XCTFail("Unable to swizzle protocolClasses")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    override class func setUp() {
        super.setUp()

        // Inject url handler for SR client
        swizzleUrlSessionConfiguration()

    }

    override func setUp() {
        super.setUp()

        // reset remote config storage
        RemoteConfigClient.resetStorage()
    }

    override class func tearDown() {
        super.tearDown()

        // Swizzle again to restore original behavior
        swizzleUrlSessionConfiguration()
    }

    func testSessionsTurnsOnFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "sessions": true,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: []))
        let sessions = amplitude.sessions
        XCTAssertFalse(sessions.trackSessionEvents)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertTrue(sessions.trackSessionEvents)
    }

    func testSessionsTurnsOffFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "sessions": false,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: [.sessions]))
        let sessions = amplitude.sessions
        XCTAssertTrue(sessions.trackSessionEvents)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertFalse(sessions.trackSessionEvents)
    }

#if os(iOS)

    func testScreenViewsTurnsOnFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "pageViews": true,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: []))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertFalse(iosLifecycleMonitor.trackingState.screenViews)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertTrue(iosLifecycleMonitor.trackingState.screenViews)
    }

    func testScreenViewsTurnsOffFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "pageViews": false,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: [.screenViews]))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertTrue(iosLifecycleMonitor.trackingState.screenViews)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertFalse(iosLifecycleMonitor.trackingState.screenViews)
    }

    func testElementInteractionsTurnsOnFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "elementInteractions": true,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: []))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertFalse(iosLifecycleMonitor.trackingState.elementInteractions)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertTrue(iosLifecycleMonitor.trackingState.elementInteractions)
    }

    func testElementInteractionsTurnsOffFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "elementInteractions": false,
                    ]
                ]
            ]
        ])

        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa", autocapture: [.elementInteractions]))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertTrue(iosLifecycleMonitor.trackingState.elementInteractions)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertFalse(iosLifecycleMonitor.trackingState.elementInteractions)
    }

    func testFrustrationInteractionsTurnsOnFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "frustrationInteractions": [
                            "enabled": true,
                            "rageClick": [
                                "enabled": true
                            ],
                            "deadClick": [
                                "enabled": false
                            ]
                        ]
                    ]
                ]
            ]
        ])

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: false),
            deadClick: .init(enabled: false)
        )
        let config = Configuration(apiKey: "aaa",
                                   autocapture: [],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertFalse(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertFalse(iosLifecycleMonitor.trackingState.rageClick)
        XCTAssertFalse(iosLifecycleMonitor.trackingState.deadClick)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertTrue(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.rageClick)
        XCTAssertFalse(iosLifecycleMonitor.trackingState.deadClick)
    }

    func testFrustrationInteractionsTurnsOffFromRemoteConfig() {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "frustrationInteractions": [
                            "enabled": false
                        ]
                    ]
                ]
            ]
        ])

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: true),
            deadClick: .init(enabled: true)
        )
        let config = Configuration(apiKey: "aaa",
                                   autocapture: [.frustrationInteractions],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertTrue(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.rageClick)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.deadClick)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertFalse(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.rageClick) // Local config value still true
        XCTAssertTrue(iosLifecycleMonitor.trackingState.deadClick) // Local config value still true
    }

    func testFrustrationInteractionsPartialRemoteConfig() {
        // Test that missing values in remote config fall back to local config
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "frustrationInteractions": [
                            "enabled": true,
                            "rageClick": [
                                "enabled": false
                            ]
                            // deadClick is missing, should use local config
                        ]
                    ]
                ]
            ]
        ])

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: true),
            deadClick: .init(enabled: true)
        )
        let config = Configuration(apiKey: "aaa",
                                   autocapture: [.frustrationInteractions],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        guard let iosLifecycleMonitor else {
            XCTFail("iOS lifecycle monitor not installed")
            return
        }

        XCTAssertTrue(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.rageClick)
        XCTAssertTrue(iosLifecycleMonitor.trackingState.deadClick)

        wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation], timeout: 1)

        XCTAssertTrue(iosLifecycleMonitor.trackingState.frustrationInteractions)
        XCTAssertFalse(iosLifecycleMonitor.trackingState.rageClick) // Overridden by remote config
        XCTAssertTrue(iosLifecycleMonitor.trackingState.deadClick) // Falls back to local config
    }

#endif
}

extension RemoteConfigClient {

    private final class SubscriptionHolder: @unchecked Sendable {
        @Atomic var subscription: Any?
    }

    nonisolated var didFetchRemoteExpectation: XCTestExpectation {
        let expectation = XCTestExpectation(description: "didFetchRemote")

        let subscriptionHolder = SubscriptionHolder()
        subscriptionHolder.subscription = subscribe { [weak self] _, source, _ in
            guard source == .remote else {
                return
            }
            if let subscription = subscriptionHolder.subscription {
                self?.unsubscribe(subscription)
            }
            expectation.fulfill()
        }

        return expectation
    }

    static func setNextFetchedRemoteConfig(_ remoteConfig: RemoteConfigClient.RemoteConfig) {
        RemoteConfigUrlProtocol.nextConfigs.append(remoteConfig)
    }

    static func resetStorage(instanceName: String? = Constants.Configuration.DEFAULT_INSTANCE) {
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "sessions": true,
                    ]
                ]
            ]
        ])
        let amplitude = Amplitude(configuration: Configuration(apiKey: "aaa"))
        XCTWaiter().wait(for: [amplitude.amplitudeContext.remoteConfigClient.didFetchRemoteExpectation],
                         timeout: 1)
    }
}

extension URLSessionConfiguration {

    @objc var amp_protocolClasses: [AnyClass]? {
        // this is swizzled, so it is not recursive
        return [RemoteConfigUrlProtocol.self] + (self.amp_protocolClasses ?? [])
    }
}

class RemoteConfigUrlProtocol: URLProtocol {

    static var nextConfigs: [RemoteConfigClient.RemoteConfig] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.absoluteString.hasPrefix("https://sr-client-cfg.") ?? false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url, !Self.nextConfigs.isEmpty else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
            return
        }

        let config = Self.nextConfigs.removeFirst()

        let response = HTTPURLResponse(url: url,
                                       statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        let data = try? JSONSerialization.data(withJSONObject: ["configs": config])

        DispatchQueue.global().asyncAfter(deadline: .now() + DispatchTimeInterval.milliseconds(200)) { [self] in
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // no-op
    }
}
