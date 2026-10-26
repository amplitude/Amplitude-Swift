//
//  AutocaptureRemoteConfigTests.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 4/29/25.
//

import AmplitudeCore
@testable
import AmplitudeSwift
import XCTest

// Each test follows the same shape, and the order matters:
//
//   1. queue the remote config for this test's API key -- the mock holds it;
//   2. init Amplitude and assert the *local* defaults -- the remote config provably
//      has not arrived, because nothing has released it;
//   3. register `remoteConfigAppliedExpectation()`, release the mock, wait;
//   4. assert the remote values.
//
// Nothing here depends on how long any step takes. See RemoteConfigMockServer.
class AutocaptureRemoteConfigTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        // Already done by TestBundlePrincipal under xcodebuild; idempotent safety net
        // for runners that ignore NSPrincipalClass, such as `swift test`.
        RemoteConfigMockServer.install()
    }

    private func uniqueApiKey(_ function: String = #function) -> String {
        let cleanName = function.replacingOccurrences(of: "()", with: "")
        return "\(RemoteConfigMockServer.testApiKeyPrefix)\(cleanName)"
    }

    private func uniqueInstanceName(_ function: String = #function) -> String {
        let cleanName = function.replacingOccurrences(of: "()", with: "")
        return "test-instance-\(cleanName)"
    }

    private func resetStorage(_ function: String = #function) {
        let instanceName = uniqueInstanceName(function)
        RemoteConfigClient.resetStorage(instanceName: instanceName)
    }

    func testSessionsTurnsOnFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "sessions": true,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: []))
        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.sessions), "Sessions should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.sessions), "Sessions should be on from remote config")
    }

    func testSessionsTurnsOffFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "sessions": false,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: [.sessions]))
        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.sessions), "Sessions should be on by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.sessions), "Sessions should be off from remote config")
    }

#if os(iOS)

    func testScreenViewsTurnsOnFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "pageViews": true,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: []))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }
        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.screenViews), "Screen views should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.screenViews), "Screen views should be on from remote config")
    }

    func testScreenViewsTurnsOffFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "pageViews": false,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: [.screenViews]))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.screenViews), "Screen views should be on by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.screenViews), "Screen views should be off from remote config")
    }

    func testElementInteractionsTurnsOnFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "elementInteractions": true,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: []))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.elementInteractions), "Element interactions should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.elementInteractions), "Element interactions should be on from remote config")
    }

    func testElementInteractionsTurnsOffFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "elementInteractions": false,
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: [.elementInteractions]))

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.elementInteractions), "Element interactions should be on by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.elementInteractions), "Element interactions should be off from remote config")
    }

    func testFrustrationInteractionsTurnsOnFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
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
        ], forApiKey: apiKey)

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: false),
            deadClick: .init(enabled: false)
        )
        let config = Configuration(apiKey: apiKey,
                                   instanceName: uniqueInstanceName(),
                                   autocapture: [],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be off by default")
        XCTAssertFalse(amplitude.autocaptureManager.rageClickEnabled, "Rage click should be off by default")
        XCTAssertFalse(amplitude.autocaptureManager.deadClickEnabled, "Dead click should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be on from remote config")
        XCTAssertTrue(amplitude.autocaptureManager.rageClickEnabled, "Rage click should be on from remote config")
        XCTAssertFalse(amplitude.autocaptureManager.deadClickEnabled, "Dead click should be off from remote config")
    }

    func testFrustrationInteractionsTurnsOffFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
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
        ], forApiKey: apiKey)

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: true),
            deadClick: .init(enabled: true)
        )
        let config = Configuration(apiKey: apiKey,
                                   instanceName: uniqueInstanceName(),
                                   autocapture: [.frustrationInteractions],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be on by default")
        XCTAssertTrue(amplitude.autocaptureManager.rageClickEnabled, "Rage click should be on by default")
        XCTAssertTrue(amplitude.autocaptureManager.deadClickEnabled, "Dead click should be on by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertFalse(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be off from remote config")
        XCTAssertTrue(amplitude.autocaptureManager.rageClickEnabled, "Rage click should still be on from local config")
        XCTAssertTrue(amplitude.autocaptureManager.deadClickEnabled, "Dead click should still be on from local config")
    }

    func testFrustrationInteractionsPartialRemoteConfig() {
        resetStorage()
        // Test that missing values in remote config fall back to local config
        let apiKey = uniqueApiKey()
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
        ], forApiKey: apiKey)

        let interactionsOptions = InteractionsOptions(
            rageClick: .init(enabled: true),
            deadClick: .init(enabled: true)
        )
        let config = Configuration(apiKey: apiKey,
                                   instanceName: uniqueInstanceName(),
                                   autocapture: [.frustrationInteractions],
                                   interactionsOptions: interactionsOptions)
        let amplitude = Amplitude(configuration: config)

        var iosLifecycleMonitor: IOSLifecycleMonitor?
        amplitude.apply { plugin in
            if let monitor = plugin as? IOSLifecycleMonitor {
                iosLifecycleMonitor = monitor
            }
        }

        XCTAssertNotNil(iosLifecycleMonitor, "iOS lifecycle monitor not installed")

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be on by default")
        XCTAssertTrue(amplitude.autocaptureManager.rageClickEnabled, "Rage click should be on by default")
        XCTAssertTrue(amplitude.autocaptureManager.deadClickEnabled, "Dead click should be on by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(amplitude.autocaptureManager.isEnabled(.frustrationInteractions), "Frustration interactions should be on by default")
        XCTAssertFalse(amplitude.autocaptureManager.rageClickEnabled, "Rage click should be off from remote config")
        XCTAssertTrue(amplitude.autocaptureManager.deadClickEnabled, "Dead click should be on from local config")
    }
#endif
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testNetworkTrackingTurnsOnFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "networkTracking": [
                            "enabled": true
                        ]
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: []))

        var networkTrackingPlugin: NetworkTrackingPlugin?
        amplitude.apply { plugin in
            if let networkPlugin = plugin as? NetworkTrackingPlugin {
                networkTrackingPlugin = networkPlugin
            }
        }
        guard let networkTrackingPlugin else {
            XCTFail("Network tracking plugin not installed")
            return
        }

        XCTAssertTrue(networkTrackingPlugin.optOut, "Network tracking should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertFalse(networkTrackingPlugin.optOut, "Network tracking should be on from remote config")
    }

    func testNetworkTrackingTurnsOffFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "networkTracking": [
                            "enabled": false
                        ]
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: [.networkTracking]))

        var networkTrackingPlugin: NetworkTrackingPlugin?
        amplitude.apply { plugin in
            if let networkPlugin = plugin as? NetworkTrackingPlugin {
                networkTrackingPlugin = networkPlugin
            }
        }
        guard let networkTrackingPlugin else {
            XCTFail("Network tracking plugin not installed")
            return
        }

        XCTAssertFalse(networkTrackingPlugin.optOut, "Network tracking should be off by default")

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        XCTAssertTrue(networkTrackingPlugin.optOut, "Network tracking should be on from remote config")
    }

    func testNetworkTrackingConfigSchemaFromRemoteConfig() {
        resetStorage()
        let apiKey = uniqueApiKey()
        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "networkTracking": [
                            "enabled": true,
                            "ignoreHosts": ["test.example.com", "*.internal.com"],
                            "ignoreAmplitudeRequests": false,
                            "captureRules": [
                                [
                                    "hosts": ["api.example.com", "*.api.com"],
                                    "urls": ["https://api.example.com/v1/endpoint"],
                                    "urlsRegex": [".*\\/api\\/v[0-9]+\\/.*"],
                                    "methods": ["GET", "POST"],
                                    "statusCodeRange": "400-599",
                                    "requestHeaders": [
                                        "allowlist": ["Content-Type", "Authorization"],
                                        "captureSafeHeaders": true
                                    ],
                                    "responseHeaders": [
                                        "allowlist": ["Content-Type"],
                                        "captureSafeHeaders": false
                                    ],
                                    "requestBody": [
                                        "allowlist": ["userId", "eventType"],
                                        "excludelist": ["password", "token"]
                                    ],
                                    "responseBody": [
                                        "allowlist": ["status", "message"],
                                        "excludelist": ["secret"]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let amplitude = Amplitude(configuration: Configuration(apiKey: apiKey, instanceName: uniqueInstanceName(), autocapture: []))

        var networkTrackingPlugin: NetworkTrackingPlugin?
        amplitude.apply { plugin in
            if let networkPlugin = plugin as? NetworkTrackingPlugin {
                networkTrackingPlugin = networkPlugin
            }
        }
        guard let networkTrackingPlugin else {
            XCTFail("Network tracking plugin not installed")
            return
        }

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        // Verify the plugin is enabled
        XCTAssertFalse(networkTrackingPlugin.optOut)

        // Verify the configuration was compiled
        guard let options = networkTrackingPlugin.options else {
            XCTFail("Network tracking options not compiled")
            return
        }
        XCTAssertTrue(options.ignoreHosts.matches("test.example.com"))
        XCTAssertTrue(options.ignoreHosts.matches("api.internal.com"))
        // ignoreAmplitudeRequests: false, so Amplitude's own hosts are not ignored
        XCTAssertFalse(options.ignoreHosts.matches("api2.amplitude.com"))

        // Verify capture rules
        XCTAssertEqual(options.captureRules.count, 1)

        if let captureRule = options.captureRules.first {
            XCTAssertEqual(captureRule.hosts?.hostSet, ["api.example.com"])
            XCTAssertTrue(captureRule.hosts?.matches("v2.api.com") ?? false)
            XCTAssertEqual(captureRule.methods, ["GET", "POST"])
            XCTAssertEqual(captureRule.statusCodeIndexSet, IndexSet(400...599))

            // Verify URL patterns: urls are exact, urlsRegex are regexes
            XCTAssertTrue(captureRule.urls?.matches("https://api.example.com/v1/endpoint") ?? false)
            XCTAssertTrue(captureRule.urls?.matches("https://other.example.com/api/v2/items") ?? false)
            XCTAssertFalse(captureRule.urls?.matches("https://api.example.com/v1/other") ?? true)

            // Verify header filters. Authorization is always blocked; safe headers only on request.
            let headers = ["Content-Type": "application/json", "Authorization": "Bearer x", "Cache-Control": "no-cache", "X-Other": "1"]
            XCTAssertEqual(captureRule.requestHeaders?.filterHeaders(headers),
                           ["Content-Type": "application/json", "Cache-Control": "no-cache"])
            XCTAssertEqual(captureRule.responseHeaders?.filterHeaders(headers), ["Content-Type": "application/json"])

            // Verify body filters
            let requestBody = captureRule.requestBody?.filterBody(["userId": "u", "eventType": "e", "password": "p", "other": "o"])
            XCTAssertEqual(requestBody as? [String: String], ["userId": "u", "eventType": "e"])
            let responseBody = captureRule.responseBody?.filterBody(["status": "ok", "message": "m", "secret": "s", "other": "o"])
            XCTAssertEqual(responseBody as? [String: String], ["status": "ok", "message": "m"])
        }
    }

    func testNetworkTrackingPartialRemoteConfig() {
        resetStorage()
        // Test that missing values in remote config fall back to local config
        let apiKey = uniqueApiKey()
        let localOptions = NetworkTrackingOptions(
            captureRules: [
                NetworkTrackingOptions.CaptureRule(hosts: ["local.example.com"], statusCodeRange: "500-599")
            ],
            ignoreHosts: ["local-ignore.com"],
            ignoreAmplitudeRequests: false
        )

        RemoteConfigClient.setNextFetchedRemoteConfig([
            "analyticsSDK": [
                "iosSDK": [
                    "autocapture": [
                        "networkTracking": [
                            "enabled": true,
                            "ignoreHosts": ["remote-ignore.com"]
                            // captureRules and ignoreAmplitudeRequests are missing, should use local config
                        ]
                    ]
                ]
            ]
        ], forApiKey: apiKey)

        let config = Configuration(apiKey: apiKey,
                                   instanceName: uniqueInstanceName(),
                                   autocapture: [.networkTracking],
                                   networkTrackingOptions: localOptions)
        let amplitude = Amplitude(configuration: config)

        var networkTrackingPlugin: NetworkTrackingPlugin?
        amplitude.apply { plugin in
            if let networkPlugin = plugin as? NetworkTrackingPlugin {
                networkTrackingPlugin = networkPlugin
            }
        }
        guard let networkTrackingPlugin else {
            XCTFail("Network tracking plugin not installed")
            return
        }

        let remoteConfigApplied = amplitude.remoteConfigAppliedExpectation()
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteConfigApplied], timeout: 15)

        // Verify the plugin is enabled from remote config
        XCTAssertFalse(networkTrackingPlugin.optOut)

        // Verify ignoreHosts was overridden by remote config
        XCTAssertEqual(networkTrackingPlugin.options?.ignoreHosts.hostSet, ["remote-ignore.com"])

        // Verify captureRules stayed from local config (not overridden since missing in remote)
        XCTAssertEqual(networkTrackingPlugin.options?.captureRules.count, 1)
        XCTAssertEqual(networkTrackingPlugin.options?.captureRules.first?.hosts?.hostSet, ["local.example.com"])

        // Verify ignoreAmplitudeRequests stayed from local config (false: Amplitude hosts not ignored)
        XCTAssertEqual(networkTrackingPlugin.options?.ignoreHosts.hostPatterns.count, 0)
    }
#endif
#if !os(watchOS)
    // The tests below drive deliveries with `handleRemoteConfig` directly. The remote fetch never
    // answers (nothing is queued or released for the API key) and the cache is reset, so the
    // test's deliveries are the only ones.

    private static let localNetworkTrackingOptions = NetworkTrackingOptions(
        captureRules: [.init(hosts: ["local.example.com"])],
        ignoreHosts: ["local-ignore.example.com"]
    )
    private static let remoteCaptureRule: [String: Any] = ["hosts": ["remote.example.com"], "statusCodeRange": "400-499"]

    private func makeNetworkTrackingAmplitude(_ function: String = #function) -> Amplitude {
        resetStorage(function)
        return Amplitude(configuration: Configuration(apiKey: uniqueApiKey(function),
                                                      instanceName: uniqueInstanceName(function),
                                                      autocapture: [.networkTracking],
                                                      networkTrackingOptions: Self.localNetworkTrackingOptions))
    }

    private func networkTrackingPlugin(of amplitude: Amplitude) -> NetworkTrackingPlugin? {
        var found: NetworkTrackingPlugin?
        amplitude.apply { plugin in
            if let plugin = plugin as? NetworkTrackingPlugin {
                found = plugin
            }
        }
        return found
    }

    private func captureRuleHosts(_ plugin: NetworkTrackingPlugin) -> [Set<String>?]? {
        plugin.options?.captureRules.map { $0.hosts?.hostSet }
    }

    // MARK: Network tracking plugin added after deliveries
    //
    // A config handled before the plugin is added (the cached config, or the nil fallback after a
    // failed fetch, usually arrives while Amplitude.init is still adding plugins) must be in effect
    // as soon as add(plugin:) returns. The instance's own plugin is removed first, so only the
    // plugin under test is compiled and registered with the swizzler.

    private func addNetworkTrackingPlugin(afterDeliveries deliveries: [[String: Any]?],
                                          _ function: String = #function) throws -> RecordingNetworkTrackingPlugin {
        let amplitude = makeNetworkTrackingAmplitude(function)
        amplitude.remove(plugin: try XCTUnwrap(networkTrackingPlugin(of: amplitude)))
        for delivery in deliveries {
            amplitude.autocaptureManager.handleRemoteConfig(delivery)
        }
        let plugin = RecordingNetworkTrackingPlugin()
        amplitude.add(plugin: plugin)
        addTeardownBlock { amplitude.remove(plugin: plugin) }
        return plugin
    }

    func testNetworkTrackingPluginAddedWithNoDelivery_compilesLocalOptions() throws {
        let plugin = try addNetworkTrackingPlugin(afterDeliveries: [])

        XCTAssertFalse(plugin.optOut)
        XCTAssertEqual(captureRuleHosts(plugin), [["local.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["local-ignore.example.com"])
        XCTAssertEqual(swizzlerEntries(of: plugin), 1)
    }

    func testNetworkTrackingPluginAddedAfterNilDelivery_compilesLocalOptions() throws {
        let plugin = try addNetworkTrackingPlugin(afterDeliveries: [nil])

        XCTAssertFalse(plugin.optOut)
        XCTAssertEqual(captureRuleHosts(plugin), [["local.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["local-ignore.example.com"])
        XCTAssertEqual(swizzlerEntries(of: plugin), 1)
    }

    func testNetworkTrackingPluginAddedAfterCachedConfig_compilesRemoteOptions() throws {
        let plugin = try addNetworkTrackingPlugin(afterDeliveries: [[
            "networkTracking": [
                "enabled": true,
                "captureRules": [Self.remoteCaptureRule],
                "ignoreHosts": ["remote-ignore.example.com"],
            ]
        ]])

        XCTAssertFalse(plugin.optOut)
        XCTAssertEqual(captureRuleHosts(plugin), [["remote.example.com"]])
        XCTAssertEqual(plugin.options?.captureRules.first?.statusCodeIndexSet, IndexSet(400...499))
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["remote-ignore.example.com"])
        XCTAssertEqual(swizzlerEntries(of: plugin), 1)
    }

    func testNetworkTrackingPluginAddedAfterDisablingConfig_optsOutWithoutCompiling() throws {
        let plugin = try addNetworkTrackingPlugin(afterDeliveries: [[
            "networkTracking": [
                "enabled": false,
                "captureRules": [Self.remoteCaptureRule],
            ]
        ]])

        XCTAssertTrue(plugin.optOut)
        XCTAssertNil(plugin.options)
        XCTAssertEqual(swizzlerEntries(of: plugin), 0)
    }

    // MARK: Successive remote configs
    //
    // Each networkTracking section is overlaid on the local options, not on the previous section:
    // a field the section omits takes the local value. A config without the section, or a nil
    // delivery, keeps the previous section, as it keeps the enabled flag.

    func testNetworkTrackingSuccessiveRemoteConfigs() throws {
        let amplitude = makeNetworkTrackingAmplitude()
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let manager = amplitude.autocaptureManager

        // A: captureRules replace the local rules; the omitted ignoreHosts stay local
        manager.handleRemoteConfig(["networkTracking": ["enabled": true, "captureRules": [Self.remoteCaptureRule]]])
        XCTAssertEqual(captureRuleHosts(plugin), [["remote.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["local-ignore.example.com"])

        // B: a section without captureRules: the local rules, not A's
        manager.handleRemoteConfig(["networkTracking": ["enabled": true, "ignoreHosts": ["remote-ignore.example.com"]]])
        XCTAssertEqual(captureRuleHosts(plugin), [["local.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["remote-ignore.example.com"])

        // C: no networkTracking section: B's section is kept
        manager.handleRemoteConfig(["sessions": true])
        XCTAssertEqual(captureRuleHosts(plugin), [["local.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["remote-ignore.example.com"])

        // nil (the fallback after a failed fetch): state is kept
        manager.handleRemoteConfig(nil)
        XCTAssertEqual(captureRuleHosts(plugin), [["local.example.com"]])
        XCTAssertEqual(plugin.options?.ignoreHosts.hostSet, ["remote-ignore.example.com"])
        XCTAssertFalse(plugin.optOut)
    }

    func testNetworkTrackingConfigWithoutSection_keepsPreviousCaptureRules() throws {
        let amplitude = makeNetworkTrackingAmplitude()
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let manager = amplitude.autocaptureManager

        manager.handleRemoteConfig(["networkTracking": ["enabled": true, "captureRules": [Self.remoteCaptureRule]]])
        manager.handleRemoteConfig(["sessions": true])

        XCTAssertEqual(captureRuleHosts(plugin), [["remote.example.com"]])
        XCTAssertEqual(plugin.options?.captureRules.first?.statusCodeIndexSet, IndexSet(400...499))
        XCTAssertFalse(plugin.optOut)
    }
#endif
}
