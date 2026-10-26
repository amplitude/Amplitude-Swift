//
//  NetworkTrackingDuplicateListenerTests.swift
//  Amplitude-Swift
//
//  NetworkTrackingPlugin and autocapture remote config, through the real RemoteConfigClient path:
//
//  - One request must produce one `[Amplitude] Network Request` event, however many deliveries
//    the plugin has handled. Every delivery ends in `compileConfig`, which calls
//    `NetworkSwizzler.shared.addListener(self)`, and the swizzler calls `onTask(_:setState:)`
//    once per list entry.
//  - Tracking must follow the right options from the first request of a launch: local, cached
//    or remote, online or offline (T1-T4). The plugin compiles from AutocaptureManager's current
//    state, so a config delivered before the plugin was added is not lost.
//  - Each remote config is overlaid on the local options, not on the previous remote config.
//

import AmplitudeCore
@testable import AmplitudeSwift
import XCTest

#if !os(watchOS)
final class NetworkTrackingDuplicateListenerTests: XCTestCase {

    private static let networkRequestEventType = "[Amplitude] Network Request"
    // Harmless, distinguishable payloads: each delivery sets a different ignoreHosts entry, so a
    // test can tell which options the plugin last compiled. None matches example.com.
    private static let cacheMarker = "cache.marker.invalid"
    private static let remoteMarker = "remote.marker.invalid"
    private static let refetchMarker = "refetch.marker.invalid"
    private static let localMarker = "local.marker.invalid"
    private static let markers = [cacheMarker, remoteMarker, refetchMarker, localMarker]

    /// Local options, marked so a test can see when the plugin is running on them. They capture
    /// 500-599 from any host.
    private static let localOptions = NetworkTrackingOptions(captureRules: [.init(hosts: ["*"])],
                                                             ignoreHosts: [localMarker])

    private var amplitude: Amplitude?
    private var instanceName: String?
    private let eventCollector = EventCollectorPlugin()
    private var session: URLSession!

    override static func setUp() {
        super.setUp()
        // Idempotent; already done by TestBundlePrincipal under xcodebuild.
        RemoteConfigMockServer.install()
        // The SDK's own uploads go to FakeURLProtocol (plain 200) rather than the network.
        URLSessionConfiguration.enableMockDefault()
    }

    override static func tearDown() {
        URLSessionConfiguration.disableMockDefault()
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        // The swizzler holds listeners strongly and nothing else removes them, so take this
        // test's plugin out explicitly; otherwise it leaks into every later test.
        if let amplitude, let plugin = networkTrackingPlugin(of: amplitude) {
            NetworkSwizzler.shared.removeListener(plugin)
        }
        amplitude = nil
        if let instanceName {
            RemoteConfigClient.resetStorage(instanceName: instanceName)
        }
        session.invalidateAndCancel()
        FakeURLProtocol.clearMockResponses()
        super.tearDown()
    }

    // MARK: - 1. Duplicate listeners: cached config, then remote config

    /// Launch with a config cached by a previous launch, remote fetch in flight. In `.all`
    /// delivery mode RemoteConfigClient delivers the cached config first and then the remote one.
    /// Then ONE request fails with a 500.
    func testCachedThenRemoteConfig_oneFailedRequestIsTrackedOnce() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()

        // A previous launch left this in RemoteConfigUserDefaultsStorage.
        try writeCachedRemoteConfig(Self.remoteConfig(marker: Self.cacheMarker),
                                    instanceName: instanceName,
                                    lastFetch: Date(timeIntervalSinceNow: -3_600))
        // This launch's remote response, held by the mock until release(apiKey:).
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        // Delivery 1: the cached config (the remote one is still held). It usually reaches
        // AutocaptureManager while Amplitude.init is still running.
        let pluginAppliedCache = waitUntil(timeout: 2) { self.compiledMarker(of: plugin) == Self.cacheMarker }
        let entriesAfterCache = try entries(of: plugin)

        // Delivery 2: the remote config.
        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        let entriesAfterRemote = try entries(of: plugin)

        let events = try fireOneFailedRequest(amplitude: amplitude, plugin: plugin)

        print("NETDUP testCachedThenRemoteConfig: deliveriesSeenByRecorder=\(recorder.markers) "
              + "pluginAppliedCache=\(pluginAppliedCache) pluginEntriesAfterCache=\(entriesAfterCache) "
              + "pluginEntriesAfterRemote=\(entriesAfterRemote) networkRequestEvents=\(events.count)")

        XCTAssertEqual(entriesAfterRemote, 1, "NetworkTrackingPlugin is registered with NetworkSwizzler more than once")
        XCTAssertEqual(events.count, 1, "one failed request produced \(events.count) [Amplitude] Network Request events")
    }

    // MARK: - 1. Duplicate listeners: failed first fetch, then the new-session refetch

    /// No cache, and the first remote fetch fails (e.g. offline at launch): the plugin gets a nil
    /// config and registers with the local options. Later the app comes to the foreground, a new
    /// session starts, `Sessions.sessionId`'s setter calls `remoteConfigClient.updateConfigs()`,
    /// the refetch succeeds and is delivered to every `.all` subscriber.
    func testFailedFetchThenNewSessionRefetch_oneFailedRequestIsTrackedOnce() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        // Delivery 1: nothing is queued for this key, so the mock fails the request (a URLError,
        // not a RemoteConfigError, so updateConfigs will not skip the refetch later). No cache
        // either, so the `.all` subscriber gets nil.
        let nilDelivered = recorder.expectation(forMarker: DeliveryRecorder.nilMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [nilDelivered], timeout: 15)
        let entriesAfterFirst = try entries(of: plugin)

        // Network is back: the next fetch succeeds.
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.refetchMarker), forApiKey: apiKey)
        RemoteConfigMockServer.release(apiKey: apiKey)

        // Delivery 2: app enters the foreground -> new session -> Sessions.sessionId setter ->
        // remoteConfigClient.updateConfigs() -> refetch -> callback to every `.all` subscriber.
        let refetched = recorder.expectation(forMarker: Self.refetchMarker)
        amplitude.onEnterForeground(timestamp: Self.nowMillis())
        wait(for: [refetched], timeout: 15)
        let entriesAfterRefetch = try entries(of: plugin)

        let events = try fireOneFailedRequest(amplitude: amplitude, plugin: plugin)

        print("NETDUP testFailedFetchThenNewSessionRefetch: deliveriesSeenByRecorder=\(recorder.markers) "
              + "pluginEntriesAfterFirst=\(entriesAfterFirst) pluginEntriesAfterRefetch=\(entriesAfterRefetch) "
              + "networkRequestEvents=\(events.count)")

        XCTAssertEqual(entriesAfterFirst, 1)
        XCTAssertEqual(entriesAfterRefetch, 1, "NetworkTrackingPlugin is registered with NetworkSwizzler more than once")
        XCTAssertEqual(events.count, 1, "one failed request produced \(events.count) [Amplitude] Network Request events")
    }

    // MARK: - 1. Duplicate listeners (slow, opt-in): launch + one new session after more than 5 minutes

    /// The production long-session path end to end: launch (cache + remote), app goes to the
    /// background, comes back after more than RemoteConfigClient's 5-minute minimum between
    /// fetches, a new session starts and the refetch is delivered. Takes ~5.5 minutes, so it only
    /// runs with NETDUP_SLOW=1 (pass TEST_RUNNER_NETDUP_SLOW=1 to xcodebuild).
    func testLaunchThenNewSessionAfterFiveMinutes_oneFailedRequestIsTrackedOnce() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NETDUP_SLOW"] == "1",
                          "slow (~5.5 min); set TEST_RUNNER_NETDUP_SLOW=1 to run")
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()

        try writeCachedRemoteConfig(Self.remoteConfig(marker: Self.cacheMarker),
                                    instanceName: instanceName,
                                    lastFetch: Date(timeIntervalSinceNow: -3_600))
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let pluginAppliedCache = waitUntil(timeout: 2) { self.compiledMarker(of: plugin) == Self.cacheMarker }
        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)

        // First session of this launch. Its updateConfigs() is skipped: the fetch above is <5 min old.
        let launchMillis = Self.nowMillis()
        amplitude.onEnterForeground(timestamp: launchMillis)
        amplitude.onExitForeground(timestamp: launchMillis)
        let entriesAtLaunch = try entries(of: plugin)

        // Background for longer than both the session timeout and minTimeBetweenFetches (5 min each).
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.refetchMarker), forApiKey: apiKey)
        RemoteConfigMockServer.release(apiKey: apiKey)
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "background > 5 min")], timeout: 305)

        let refetched = recorder.expectation(forMarker: Self.refetchMarker)
        amplitude.onEnterForeground(timestamp: Self.nowMillis())
        wait(for: [refetched], timeout: 30)
        let entriesAfterNewSession = try entries(of: plugin)

        let events = try fireOneFailedRequest(amplitude: amplitude, plugin: plugin)

        print("NETDUP testLaunchThenNewSessionAfterFiveMinutes: deliveriesSeenByRecorder=\(recorder.markers) "
              + "pluginAppliedCache=\(pluginAppliedCache) pluginEntriesAtLaunch=\(entriesAtLaunch) "
              + "pluginEntriesAfterNewSession=\(entriesAfterNewSession) networkRequestEvents=\(events.count)")

        XCTAssertEqual(entriesAfterNewSession, 1, "NetworkTrackingPlugin is registered with NetworkSwizzler more than once")
        XCTAssertEqual(events.count, 1, "one failed request produced \(events.count) [Amplitude] Network Request events")
    }

    // MARK: - 2. Duplicate listeners: entries per delivery

    /// Delivery 1 goes through the real RemoteConfigClient; deliveries 2...5 are handed to
    /// AutocaptureManager directly, because RemoteConfigClient will not refetch within 5 minutes
    /// of a successful fetch.
    func testPluginListenerEntriesPerConfigDelivery() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        let config = Self.remoteConfig(marker: Self.remoteMarker)
        RemoteConfigClient.setNextFetchedRemoteConfig(config, forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        var entriesPerDelivery = [try entries(of: plugin)]

        let autocaptureConfig = try XCTUnwrap(Self.autocaptureSubConfig(config))
        for _ in 2...5 {
            amplitude.autocaptureManager.handleRemoteConfig(autocaptureConfig)
            entriesPerDelivery.append(try entries(of: plugin))
        }

        let events = try fireOneFailedRequest(amplitude: amplitude, plugin: plugin)

        print("NETDUP testPluginListenerEntriesPerConfigDelivery: pluginEntriesAfterDelivery1...5=\(entriesPerDelivery) "
              + "networkRequestEvents=\(events.count)")

        XCTAssertEqual(entriesPerDelivery, [1, 1, 1, 1, 1])
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - 3. Launch-window and offline behavior (T1-T4)
    //
    // Network tracking is on locally (`autocapture: .networkTracking`; the local options carry the
    // ignoreHosts marker `local.marker.invalid`) and autocapture remote config is enabled (the
    // default). Each test fires ONE 500 at a specific point of the launch and counts the
    // `[Amplitude] Network Request` events that request produced. `opts=` in the output is the
    // ignoreHosts marker of the options the plugin has compiled: local / cache / remote.

    /// T1a. Normal network, no cache, remote response delayed (held by the mock until release).
    /// #1 right after Amplitude.init, before the remote config arrives; #2 after it arrives.
    func testT1a_delayedRemoteNoCache_requestBeforeRemoteIsTracked() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T1a: #1 beforeRemote {\(state1)} events=\(events1) | #2 afterRemote {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "#1, sent before the remote config arrived")
        XCTAssertEqual(events2, 1, "#2, sent after the remote config arrived")
        XCTAssertEqual(compiledMarker(of: plugin), Self.remoteMarker)
    }

    /// T1b. As T1a, but a previous launch cached a config. #1 should already use the cached options.
    func testT1b_delayedRemoteWithCache_requestBeforeRemoteIsTrackedWithCachedOptions() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        try writeCachedRemoteConfig(Self.remoteConfig(marker: Self.cacheMarker),
                                    instanceName: instanceName,
                                    lastFetch: Date(timeIntervalSinceNow: -3_600))
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let state1 = pluginState(plugin)
        let optionsAt1 = compiledMarker(of: plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T1b: #1 beforeRemote {\(state1)} events=\(events1) | #2 afterRemote {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "#1, sent before the remote config arrived")
        XCTAssertEqual(optionsAt1, Self.cacheMarker, "#1 should use the cached config")
        XCTAssertEqual(events2, 1, "#2, sent after the remote config arrived")
    }

    /// T2a. First install, offline, no cache. The launch fetch is held, then fails with a
    /// connection error (no retry for thrown errors), so `.all` falls back to nil. #1 before the
    /// failure, #2 after it; #2 should use the local options.
    func testT2a_offlineFirstInstall_requestsBeforeAndAfterNilFallback() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        let nilDelivered = recorder.expectation(forMarker: DeliveryRecorder.nilMarker)
        let released = DispatchTime.now().uptimeNanoseconds
        RemoteConfigMockServer.release(apiKey: apiKey) // nothing queued: the request fails
        wait(for: [nilDelivered], timeout: 15)
        let fallbackMs = Self.elapsedMs(since: released)
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T2a: #1 beforeFailure {\(state1)} events=\(events1) | nilFallbackReachedManager=\(fallbackMs)ms after release "
              + "| #2 afterFallback {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "#1, sent before the launch fetch failed")
        XCTAssertEqual(events2, 1, "#2, sent after the nil fallback")
        XCTAssertEqual(compiledMarker(of: plugin), Self.localMarker, "#2 should use the local options")
    }

    /// T2b. First install, offline, no cache, and the launch fetch fails as soon as it starts (like
    /// airplane mode: URLSession fails at once, RemoteConfigClient does not retry thrown errors).
    /// Measures, from Configuration creation: when the client's nil fallback is available (direct
    /// `.all` subscriber registered before Amplitude.init), when Amplitude.init returns, and when
    /// the plugin has compiled options and is registered with the swizzler.
    func testT2b_offlineFirstInstall_immediateFailure_timing() throws {
        let iterations = 10
        var registeredWhenInitReturned = 0
        var neverRegistered = 0
        var rows: [String] = []

        for _ in 0..<iterations {
            let apiKey = makeApiKey()
            let instanceName = makeInstanceName()
            RemoteConfigClient.resetStorage(instanceName: instanceName)
            RemoteConfigMockServer.release(apiKey: apiKey) // fail the request the moment it starts

            let start = DispatchTime.now().uptimeNanoseconds
            let configuration = makeConfiguration(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
            let fallback = FallbackTimer(start: start)
            configuration.remoteConfigClient.subscribe(key: Constants.RemoteConfig.Key.autocapture, callback: fallback.record)
            let amplitude = makeAmplitude(configuration: configuration)
            let initMs = Self.elapsedMs(since: start)
            let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
            let isRegistered = { plugin.options != nil && (try? self.entries(of: plugin)) == 1 }
            if isRegistered() {
                registeredWhenInitReturned += 1
            }
            let registered = pollUntil(timeout: 3, isRegistered)
            let registeredMs = registered ? Self.elapsedMs(since: start) : -1
            if !registered {
                neverRegistered += 1
            }
            _ = XCTWaiter().wait(for: [fallback.expectation], timeout: 5)
            rows.append("fallback=\(fallback.nilAtMs.map(String.init) ?? "none")ms init=\(initMs)ms "
                        + "pluginRegistered=\(registered ? "\(registeredMs)ms" : "never(3s)")")

            NetworkSwizzler.shared.removeListener(plugin)
            RemoteConfigClient.resetStorage(instanceName: instanceName)
        }

        print("NETDUP T2b: iterations=\(iterations) pluginRegisteredWhenInitReturned=\(registeredWhenInitReturned) "
              + "pluginNeverRegisteredWithin3s=\(neverRegistered) perLaunch=\(rows)")
        XCTAssertEqual(registeredWhenInitReturned, iterations, "network tracking should be live when Amplitude.init returns")
    }

    /// T2c. First install, no cache, the config endpoint answers 503: RemoteConfigClient retries
    /// 3 times with backoff (maxRetryDelay 8 s: 8/8 + 8/4 + 8/2 = 7 s times U(0.4, 1)) before
    /// the nil fallback. #1 right after init; #2 after the fallback.
    func testT2c_configEndpoint503_retriesThenNilFallback() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        RemoteConfigMockServer.failRequests(withStatusCode: 503, apiKey: apiKey)
        RemoteConfigMockServer.release(apiKey: apiKey)

        let start = DispatchTime.now().uptimeNanoseconds
        let configuration = makeConfiguration(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let fallback = FallbackTimer(start: start)
        configuration.remoteConfigClient.subscribe(key: Constants.RemoteConfig.Key.autocapture, callback: fallback.record)
        let amplitude = makeAmplitude(configuration: configuration)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))

        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)
        let request1DoneMs = Self.elapsedMs(since: start)

        wait(for: [fallback.expectation], timeout: 20)
        _ = waitUntil(timeout: 2) { plugin.options != nil }
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T2c: #1 (done at \(request1DoneMs)ms) {\(state1)} events=\(events1) | nilFallback=\(fallback.nilAtMs ?? -1)ms "
              + "| #2 afterFallback {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "#1, sent while the config endpoint was being retried")
        XCTAssertEqual(events2, 1, "#2, sent after the nil fallback")
        XCTAssertEqual(compiledMarker(of: plugin), Self.localMarker)
    }

    /// T3. A previous launch cached a config; this launch's fetch fails (offline with a cache).
    /// `.all` already counted the cache as sent, so no further callback follows the failure.
    func testT3_cachedConfigThenFailedLaunchFetch_tracksWithCachedOptions() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        try writeCachedRemoteConfig(Self.remoteConfig(marker: Self.cacheMarker),
                                    instanceName: instanceName,
                                    lastFetch: Date(timeIntervalSinceNow: -3_600))

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))

        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        // A `.waitForRemote` subscriber is called back (with the cache) only once the remote fetch
        // has failed -- the signal that RemoteConfigClient is done delivering for this launch.
        let remoteFailed = XCTestExpectation(description: "remote fetch failed, cache delivered to waitForRemote subscriber")
        amplitude.configuration.remoteConfigClient.subscribe(key: Constants.RemoteConfig.Key.autocapture,
                                                             deliveryMode: .waitForRemote(timeout: 10)) { _, source, _ in
            if case .cache = source {
                remoteFailed.fulfill()
            }
        }
        RemoteConfigMockServer.release(apiKey: apiKey) // nothing queued: the mock fails the request
        wait(for: [remoteFailed], timeout: 15)
        _ = waitUntil(timeout: 1) { false } // let any in-flight AutocaptureManager callback finish

        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T3: #1 beforeFailure {\(state1)} events=\(events1) | #2 afterFailure {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "#1, sent before the launch fetch failed")
        XCTAssertEqual(events2, 1, "#2, sent after the launch fetch failed")
        XCTAssertEqual(compiledMarker(of: plugin), Self.cacheMarker, "should use the cached config")
    }

    /// T4a. The cached config turns network tracking OFF (locally it is on). It must stay off
    /// from the first request and come back when the remote config turns it on.
    func testT4a_cachedConfigDisablesNetworkTracking_optsOutFromFirstRequest() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        try writeCachedRemoteConfig(Self.remoteConfig(marker: Self.cacheMarker, networkTrackingEnabled: false),
                                    instanceName: instanceName,
                                    lastFetch: Date(timeIntervalSinceNow: -3_600))
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)
        let managerDisabled = !amplitude.autocaptureManager.isEnabled(.networkTracking)
        let pluginAppliedCache = waitUntil(timeout: 2) { self.compiledMarker(of: plugin) == Self.cacheMarker }

        let state1 = pluginState(plugin)
        let optOut1 = plugin.optOut
        let entries1 = try entries(of: plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T4a: managerDisabledByCacheWhenInitReturned=\(managerDisabled) pluginAppliedCache=\(pluginAppliedCache) "
              + "| #1 cachedDisabled {\(state1)} events=\(events1) | #2 remoteEnabled {\(state2)} events=\(events2)")
        XCTAssertTrue(optOut1)
        XCTAssertEqual(entries1, 0)
        XCTAssertEqual(events1, 0, "the cached config disables network tracking")
        XCTAssertEqual(events2, 1, "the remote config re-enables it")
    }

    /// T4b. No cache; the remote config turns network tracking OFF. Before it arrives the local
    /// setting (on) applies; after it arrives nothing is tracked.
    func testT4b_remoteConfigDisablesNetworkTracking() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker, networkTrackingEnabled: false),
                                                      forApiKey: apiKey)

        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)

        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 500, amplitude: amplitude, plugin: plugin)

        print("NETDUP T4b: #1 beforeRemote(local on) {\(state1)} events=\(events1) | #2 remoteDisabled {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "before the remote config arrives the local setting (on) applies")
        XCTAssertTrue(plugin.optOut)
        XCTAssertEqual(try entries(of: plugin), 0)
        XCTAssertEqual(events2, 0, "the remote config disables network tracking")
    }

    // MARK: - 4. A delivery racing setup

    /// A delivery that AutocaptureManager applies while the plugin's setup-time refresh() is in
    /// progress -- after it has read the manager's state, before it has returned -- must still end
    /// up compiled. Deterministic: the test holds NetworkSwizzler's lock, which refresh() needs
    /// (in addListener) only after it has read the state and compiled, so setup is parked exactly
    /// there while the delivery is applied.
    func testDeliveryRacingSetupRefresh_endsWithLatestConfigCompiled() throws {
        let amplitude = try makeAmplitudeAfterFailedLaunchFetch()
        let manager = amplitude.autocaptureManager
        let plugin = NetworkTrackingPlugin()
        defer {
            NetworkSwizzler.shared.removeListener(plugin)
        }
        let swizzlerLock = try swizzlerLockObject()
        let setup = DispatchGroup()
        let delivery = DispatchGroup()

        swizzlerLock.lock()
        setup.enter()
        DispatchQueue.global().async {
            plugin.setup(amplitude: amplitude)
            setup.leave()
        }
        // refresh() has read the state (no remote config) and compiled the local options; it is
        // now waiting for the swizzler lock.
        let setupReadLocalState = pollUntil(timeout: 3) { self.compiledMarker(of: plugin) == Self.localMarker }
        delivery.enter()
        DispatchQueue.global().async {
            manager.handleRemoteConfig(Self.networkTrackingSubConfig(marker: Self.remoteMarker, appLifecycles: true))
            delivery.leave()
        }
        // Only this delivery turns appLifecycles on: once it is on, the manager has applied the
        // delivery (it does so before notifying callbacks).
        let managerAppliedDelivery = pollUntil(timeout: 3) { manager.isEnabled(.appLifecycles) }
        let setupStillInRefresh = setup.wait(timeout: .now() + 0.2) == .timedOut
        swizzlerLock.unlock()

        XCTAssertEqual(setup.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(delivery.wait(timeout: .now() + 10), .success)
        let finalMarker = compiledMarker(of: plugin)

        print("NETDUP raceSetup: setupReadLocalState=\(setupReadLocalState) managerAppliedDelivery=\(managerAppliedDelivery) "
              + "setupStillInRefresh=\(setupStillInRefresh) final {\(pluginState(plugin))}")
        XCTAssertTrue(setupReadLocalState, "setup's refresh() should have compiled the local options")
        XCTAssertTrue(managerAppliedDelivery)
        XCTAssertTrue(setupStillInRefresh, "the delivery must land while setup's refresh() is still running")
        XCTAssertEqual(finalMarker, Self.remoteMarker, "the delivery that raced setup must end up compiled")
        XCTAssertFalse(plugin.optOut)
        XCTAssertEqual(try entries(of: plugin), 1)
    }

    // MARK: - 5. Each remote config is overlaid on the local options

    /// Delivery 1 captures 404s; delivery 2 has a networkTracking section without captureRules.
    /// The omitted field falls back to the local rules (500-599), not to delivery 1's.
    func testRemoteOverlay_captureRulesOmittedByLaterConfig_fallBackToLocal() throws {
        let amplitude = try makeAmplitudeAfterFailedLaunchFetch()
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let manager = amplitude.autocaptureManager

        manager.handleRemoteConfig(Self.networkTrackingSubConfig(marker: Self.remoteMarker, captureRules: [Self.capture404Rule]))
        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 404, amplitude: amplitude, plugin: plugin)

        manager.handleRemoteConfig(Self.networkTrackingSubConfig(marker: Self.refetchMarker))
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 404, amplitude: amplitude, plugin: plugin)

        print("NETDUP overlayOmittedCaptureRules: #1 after404Rules {\(state1)} events=\(events1) "
              + "| #2 afterConfigWithoutCaptureRules {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "delivery 1 captures 404")
        XCTAssertEqual(compiledMarker(of: plugin), Self.refetchMarker, "delivery 2 was applied")
        XCTAssertEqual(events2, 0, "delivery 2 omits captureRules, so the local rules (500-599) apply")
    }

    /// As above, but delivery 2 has no networkTracking section at all: every field falls back to
    /// the local options. `enabled` is not a field of the options: AutocaptureManager keeps the
    /// last value it received.
    func testRemoteOverlay_networkTrackingSectionOmittedByLaterConfig_fallsBackToLocal() throws {
        let amplitude = try makeAmplitudeAfterFailedLaunchFetch()
        let plugin = try XCTUnwrap(networkTrackingPlugin(of: amplitude))
        let manager = amplitude.autocaptureManager

        manager.handleRemoteConfig(Self.networkTrackingSubConfig(marker: Self.remoteMarker, captureRules: [Self.capture404Rule]))
        let state1 = pluginState(plugin)
        let events1 = trackedEventsForOneRequest(statusCode: 404, amplitude: amplitude, plugin: plugin)

        manager.handleRemoteConfig(["sessions": false])
        let state2 = pluginState(plugin)
        let events2 = trackedEventsForOneRequest(statusCode: 404, amplitude: amplitude, plugin: plugin)

        print("NETDUP overlayOmittedSection: #1 after404Rules {\(state1)} events=\(events1) "
              + "| #2 afterConfigWithoutNetworkTracking {\(state2)} events=\(events2)")
        XCTAssertEqual(events1, 1, "delivery 1 captures 404")
        XCTAssertEqual(compiledMarker(of: plugin), Self.localMarker, "no networkTracking section: the local options apply")
        XCTAssertFalse(plugin.optOut)
        XCTAssertEqual(events2, 0, "no networkTracking section, so the local rules (500-599) apply")
    }

    // MARK: - 6. IOSLifecycleMonitor, the other onChange subscriber

    /// `IOSLifecycleMonitor.updateAutocaptureSetup` runs once in setup and once per delivery.
    /// Counted through dead-click detectors: with frustration interactions on, every call creates
    /// a DeadClickDetector, which registers with the interface signal provider.
    func testIOSLifecycleMonitor_updateAutocaptureSetupRunsOnceInSetupAndOncePerDelivery() throws {
        let apiKey = makeApiKey()
        let instanceName = makeInstanceName()
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        RemoteConfigClient.setNextFetchedRemoteConfig(Self.remoteConfig(marker: Self.remoteMarker), forApiKey: apiKey)

        let configuration = makeConfiguration(apiKey: apiKey,
                                              instanceName: instanceName,
                                              autocapture: [.networkTracking, .frustrationInteractions])
        let amplitude = SetupCountingAmplitude(configuration: configuration)
        amplitude.add(plugin: eventCollector)
        self.amplitude = amplitude
        var calls = [amplitude.signalProvider.receiversAdded]

        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)
        let remoteApplied = recorder.expectation(forMarker: Self.remoteMarker)
        RemoteConfigMockServer.release(apiKey: apiKey)
        wait(for: [remoteApplied], timeout: 15)
        calls.append(amplitude.signalProvider.receiversAdded)

        for marker in [Self.cacheMarker, Self.refetchMarker, Self.localMarker] {
            amplitude.autocaptureManager.handleRemoteConfig(Self.networkTrackingSubConfig(marker: marker))
            calls.append(amplitude.signalProvider.receiversAdded)
        }

        print("NETDUP lifecycleMonitor: updateAutocaptureSetupCalls afterInit,afterRemote,after3Deliveries=\(calls)")
        XCTAssertEqual(calls, [1, 2, 3, 4, 5])
    }

    // MARK: - Helpers

    private func makeApiKey(_ function: String = #function) -> String {
        // Unique per run so repeated runs (-test-iterations) never share mock-server state.
        let name = function.replacingOccurrences(of: "()", with: "")
        return "\(RemoteConfigMockServer.testApiKeyPrefix)netdup-\(name)-\(UUID().uuidString.prefix(8))"
    }

    private func makeInstanceName(_ function: String = #function) -> String {
        let name = "netdup-\(function.replacingOccurrences(of: "()", with: ""))-\(UUID().uuidString.prefix(8))"
        instanceName = name
        return name
    }

    /// Creating the Configuration also creates the RemoteConfigClient, which starts reading the
    /// cache and fetching immediately.
    private func makeConfiguration(apiKey: String,
                                   instanceName: String,
                                   networkTrackingOptions: NetworkTrackingOptions = .default,
                                   autocapture: AutocaptureOptions = .networkTracking) -> Configuration {
        return Configuration(apiKey: apiKey,
                             flushQueueSize: 1_000,
                             flushIntervalMillis: 3_600_000,
                             instanceName: instanceName,
                             storageProvider: FakeInMemoryStorage(),
                             identifyStorageProvider: FakeInMemoryStorage(),
                             flushMaxRetries: 0,
                             autocapture: autocapture,
                             offline: NetworkConnectivityCheckerPlugin.Disabled,
                             networkTrackingOptions: networkTrackingOptions,
                             enableAutoCaptureRemoteConfig: true)
    }

    private func makeAmplitude(apiKey: String,
                               instanceName: String,
                               networkTrackingOptions: NetworkTrackingOptions = .default) -> Amplitude {
        return makeAmplitude(configuration: makeConfiguration(apiKey: apiKey,
                                                              instanceName: instanceName,
                                                              networkTrackingOptions: networkTrackingOptions))
    }

    private func makeAmplitude(configuration: Configuration) -> Amplitude {
        let amplitude = Amplitude(configuration: configuration)
        amplitude.add(plugin: eventCollector)
        self.amplitude = amplitude
        return amplitude
    }

    /// Local options, no cache, and a launch fetch that fails: after the nil fallback the client
    /// delivers nothing more, so a test can drive deliveries itself.
    private func makeAmplitudeAfterFailedLaunchFetch(_ function: String = #function) throws -> Amplitude {
        let apiKey = makeApiKey(function)
        let instanceName = makeInstanceName(function)
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        let amplitude = makeAmplitude(apiKey: apiKey, instanceName: instanceName, networkTrackingOptions: Self.localOptions)
        let recorder = DeliveryRecorder()
        amplitude.autocaptureManager.onChange(recorder.record)
        let nilDelivered = recorder.expectation(forMarker: DeliveryRecorder.nilMarker)
        RemoteConfigMockServer.release(apiKey: apiKey) // nothing queued: the request fails
        wait(for: [nilDelivered], timeout: 15)
        return amplitude
    }

    private func networkTrackingPlugin(of amplitude: Amplitude) -> NetworkTrackingPlugin? {
        return amplitude.timeline.plugins[PluginType.utility]?.plugins.first {
            $0 is NetworkTrackingPlugin
        } as? NetworkTrackingPlugin
    }

    private static func remoteConfig(marker: String,
                                     networkTrackingEnabled: Bool = true) -> RemoteConfigClient.RemoteConfig {
        let autocapture: [String: Sendable] = [
            "networkTracking": [
                "enabled": networkTrackingEnabled,
                "ignoreHosts": [marker],
            ] as [String: Sendable],
        ]
        return ["analyticsSDK": ["iosSDK": ["autocapture": autocapture] as [String: Sendable]] as [String: Sendable]]
    }

    private static let capture404Rule: [String: Any] = ["hosts": ["*"], "statusCodeRange": "404"]

    /// An `autocapture` sub-config, as AutocaptureManager receives it.
    private static func networkTrackingSubConfig(marker: String,
                                                 captureRules: [[String: Any]]? = nil,
                                                 appLifecycles: Bool? = nil) -> [String: Any] {
        var networkTracking: [String: Any] = ["enabled": true, "ignoreHosts": [marker]]
        networkTracking["captureRules"] = captureRules
        var config: [String: Any] = ["networkTracking": networkTracking]
        config["appLifecycles"] = appLifecycles
        return config
    }

    /// What the `analyticsSDK.iosSDK.autocapture` subscription hands AutocaptureManager.
    private static func autocaptureSubConfig(_ config: RemoteConfigClient.RemoteConfig) -> [String: Any]? {
        let analytics = config["analyticsSDK"] as? [String: Any]
        let ios = analytics?["iosSDK"] as? [String: Any]
        return ios?["autocapture"] as? [String: Any]
    }

    /// The marker in the ignoreHosts the plugin has compiled -- the options actually in effect.
    private func compiledMarker(of plugin: NetworkTrackingPlugin) -> String? {
        guard let hosts = plugin.options?.ignoreHosts.hostSet else {
            return nil
        }
        return Self.markers.first { hosts.contains($0) }
    }

    private func pluginState(_ plugin: NetworkTrackingPlugin) -> String {
        let marker = compiledMarker(of: plugin).map { $0.replacingOccurrences(of: ".marker.invalid", with: "") } ?? "-"
        return "compiled=\(plugin.options != nil) optOut=\(plugin.optOut) entries=\((try? entries(of: plugin)) ?? -1) opts=\(marker)"
    }

    private static func elapsedMs(since start: UInt64) -> Int {
        return Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }

    /// 1 ms polling without spinning the run loop, for timing measurements.
    private func pollUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.001)
        }
        return condition()
    }

    private func networkRequestEventCount() -> Int {
        return eventCollector.events.filter { $0.eventType == Self.networkRequestEventType }.count
    }

    /// Fires ONE request that the mock answers with `statusCode` and returns how many network
    /// request events it produced (0 if untracked). Waits up to 1.5 s for a first event, then lets
    /// any duplicates drain through networkTrackingQueue and trackingQueue.
    private func trackedEventsForOneRequest(statusCode: Int, amplitude: Amplitude, plugin: NetworkTrackingPlugin) -> Int {
        let before = networkRequestEventCount()
        FakeURLProtocol.mockResponses = [.init(statusCode: statusCode)]
        let completed = expectation(description: "request completed")
        var request = URLRequest(url: URL(string: "https://example.com/netdup")!)
        request.httpMethod = "GET"
        session.dataTask(with: request) { _, response, _ in
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, statusCode)
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 30)

        _ = waitUntil(timeout: 1.5) { self.networkRequestEventCount() > before }
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: 0.3)
        plugin.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        return networkRequestEventCount() - before
    }

    /// Writes what AmplitudeCore's RemoteConfigUserDefaultsStorage persists after a fetch: same
    /// suite, same keys, JSON-decoded Foundation objects.
    private func writeCachedRemoteConfig(_ config: RemoteConfigClient.RemoteConfig,
                                         instanceName: String,
                                         lastFetch: Date) throws {
        RemoteConfigClient.resetStorage(instanceName: instanceName)
        let json = try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: config))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "com.amplitude.remoteconfig.cache.\(instanceName)"))
        defaults.set(json, forKey: "config")
        defaults.set(lastFetch, forKey: "lastFetch")
    }

    private static func nowMillis() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// `NetworkSwizzler.lock` is private, so @testable cannot reach it: read it through Mirror.
    private func swizzlerLockObject() throws -> NSLock {
        return try XCTUnwrap(Mirror(reflecting: NetworkSwizzler.shared).children.first { $0.label == "lock" }?.value as? NSLock,
                             "NetworkSwizzler.lock not found")
    }

    /// `NetworkSwizzler.listeners` is private too: read it through Mirror, holding the swizzler's lock.
    private func swizzlerListeners() throws -> [NetworkTaskListener] {
        let swizzler = NetworkSwizzler.shared
        let lock = try swizzlerLockObject()
        lock.lock()
        defer { lock.unlock() }
        return try XCTUnwrap(Mirror(reflecting: swizzler).children.first { $0.label == "listeners" }?.value as? [NetworkTaskListener],
                             "NetworkSwizzler.listeners not found")
    }

    private func entries(of plugin: NetworkTrackingPlugin) throws -> Int {
        return try swizzlerListeners().filter { $0 === plugin }.count
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            _ = XCTWaiter().wait(for: [XCTestExpectation(description: "poll")], timeout: 0.02)
        }
        return condition()
    }

    /// Fires ONE request that the mock answers with HTTP 500, waits for the first network event,
    /// then lets any duplicates (produced by the same setState(.completed) call) drain through
    /// networkTrackingQueue and trackingQueue before counting.
    private func fireOneFailedRequest(amplitude: Amplitude, plugin: NetworkTrackingPlugin) throws -> [BaseEvent] {
        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]
        let completed = expectation(description: "request completed")
        var request = URLRequest(url: URL(string: "https://example.com/netdup")!)
        request.httpMethod = "GET"
        session.dataTask(with: request) { _, response, _ in
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 500)
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 30)

        let firstEvent = XCTestExpectation(description: "first network request event")
        eventCollector.fulfill(firstEvent, whenCollected: 1)
        XCTAssertEqual(XCTWaiter().wait(for: [firstEvent], timeout: 10), .completed, "no network request event at all")

        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: 0.5)
        plugin.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        return eventCollector.events.filter { $0.eventType == Self.networkRequestEventType }
    }
}

/// Every `interfaceSignalProvider` read returns a counting provider, including the reads made
/// while `Amplitude.init` sets up its plugins.
private final class SetupCountingAmplitude: Amplitude {
    let signalProvider = CountingSignalProvider()

    override var interfaceSignalProvider: InterfaceSignalProvider? {
        get { signalProvider }
        set {}
    }
}

private final class CountingSignalProvider: InterfaceSignalProvider {
    private let lock = NSLock()
    private var _receiversAdded = 0

    var receiversAdded: Int {
        lock.withLock { _receiversAdded }
    }

    var isProviding: Bool { false }

    func addInterfaceSignalReceiver(_ receiver: any InterfaceSignalReceiver) {
        lock.withLock { _receiversAdded += 1 }
    }

    func removeInterfaceSignalReceiver(_ receiver: any InterfaceSignalReceiver) {}
}

/// A plain RemoteConfigClient subscriber that records when the first nil delivery (the `.all`
/// fallback after a failed fetch with no cache) arrived, in ms since `start`.
private final class FallbackTimer: @unchecked Sendable {
    let expectation = XCTestExpectation(description: "nil fallback delivered")
    private let start: UInt64
    private let lock = NSLock()
    private var _nilAtMs: Int?

    init(start: UInt64) {
        self.start = start
        expectation.assertForOverFulfill = false
    }

    var nilAtMs: Int? {
        lock.withLock { _nilAtMs }
    }

    func record(_ config: RemoteConfigClient.RemoteConfig?, _ source: RemoteConfigClient.Source, _ lastFetch: Date?) {
        guard config == nil else {
            return
        }
        let elapsed = Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        lock.withLock {
            if _nilAtMs == nil {
                _nilAtMs = elapsed
            }
        }
        expectation.fulfill()
    }
}

/// Registered as the last AutocaptureManager change callback. Callbacks run synchronously in
/// registration order, so when this one sees a delivery, NetworkTrackingPlugin's callback
/// (registered in its setup) has already finished handling it.
private final class DeliveryRecorder {
    static let nilMarker = "nil"

    private let lock = NSLock()
    private var _markers: [String] = []
    private var waiting: [String: XCTestExpectation] = [:]

    var markers: [String] {
        lock.withLock { _markers }
    }

    func record(_ config: [String: Any]?) {
        let networkTracking = config?["networkTracking"] as? [String: Any]
        let marker = config == nil ? Self.nilMarker : ((networkTracking?["ignoreHosts"] as? [String])?.first ?? "other")
        let expectation: XCTestExpectation? = lock.withLock {
            _markers.append(marker)
            return waiting.removeValue(forKey: marker)
        }
        expectation?.fulfill()
    }

    /// Fulfilled by the next delivery carrying `marker` (register before triggering it).
    func expectation(forMarker marker: String) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "delivery \(marker)")
        lock.withLock {
            waiting[marker] = expectation
        }
        return expectation
    }
}
#endif
