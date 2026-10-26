//
//  NetworkTrackingDuplicateListenerTests.swift
//  Amplitude-Swift
//
//  One request must produce one `[Amplitude] Network Request` event, however many autocapture
//  remote-config deliveries NetworkTrackingPlugin has handled.
//
//  Every delivery ends in `compileConfig`, which calls `NetworkSwizzler.shared.addListener(self)`,
//  and the swizzler calls `onTask(_:setState:)` once per list entry. If `addListener` appended
//  the same listener again, each extra delivery would add one extra event per tracked request.
//

import AmplitudeCore
@testable import AmplitudeSwift
import XCTest

#if !os(watchOS)
final class NetworkTrackingDuplicateListenerTests: XCTestCase {

    private static let networkRequestEventType = "[Amplitude] Network Request"
    // Harmless, distinguishable payloads: each delivery sets a different ignoreHosts entry, so a
    // test can tell which delivery the plugin last compiled. None matches example.com.
    private static let cacheMarker = "cache.marker.invalid"
    private static let remoteMarker = "remote.marker.invalid"
    private static let refetchMarker = "refetch.marker.invalid"
    private static let markers = [cacheMarker, remoteMarker, refetchMarker]

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

    // MARK: - Cached config, then remote config (every launch of a returning user)

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

    // MARK: - Failed first fetch, then the new-session refetch

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

    // MARK: - Slow, opt-in: launch + one new session after more than 5 minutes

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

    // MARK: - Mechanism: listener entries per delivery

    /// Delivery 1 goes through the real RemoteConfigClient; deliveries 2...5 do exactly what
    /// `AutocaptureManager.handleRemoteConfig` does with a config -- call every registered change
    /// callback with the `autocapture` sub-config -- because RemoteConfigClient will not refetch
    /// within 5 minutes of a successful fetch.
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

        let callbacks = try changeCallbacks(of: amplitude.autocaptureManager)
        let autocaptureConfig = try XCTUnwrap(Self.autocaptureSubConfig(config))
        for _ in 2...5 {
            callbacks.forEach { $0(autocaptureConfig) }
            entriesPerDelivery.append(try entries(of: plugin))
        }

        let events = try fireOneFailedRequest(amplitude: amplitude, plugin: plugin)

        print("NETDUP testPluginListenerEntriesPerConfigDelivery: pluginEntriesAfterDelivery1...5=\(entriesPerDelivery) "
              + "networkRequestEvents=\(events.count)")

        XCTAssertEqual(entriesPerDelivery, [1, 1, 1, 1, 1])
        XCTAssertEqual(events.count, 1)
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
    private func makeAmplitude(apiKey: String, instanceName: String) -> Amplitude {
        let configuration = Configuration(apiKey: apiKey,
                                          flushQueueSize: 1_000,
                                          flushIntervalMillis: 3_600_000,
                                          instanceName: instanceName,
                                          storageProvider: FakeInMemoryStorage(),
                                          identifyStorageProvider: FakeInMemoryStorage(),
                                          flushMaxRetries: 0,
                                          autocapture: .networkTracking,
                                          offline: NetworkConnectivityCheckerPlugin.Disabled,
                                          enableAutoCaptureRemoteConfig: true)
        let amplitude = Amplitude(configuration: configuration)
        amplitude.add(plugin: eventCollector)
        self.amplitude = amplitude
        return amplitude
    }

    private func networkTrackingPlugin(of amplitude: Amplitude) -> NetworkTrackingPlugin? {
        return amplitude.timeline.plugins[PluginType.utility]?.plugins.first {
            $0 is NetworkTrackingPlugin
        } as? NetworkTrackingPlugin
    }

    private static func remoteConfig(marker: String) -> RemoteConfigClient.RemoteConfig {
        let autocapture: [String: Sendable] = [
            "networkTracking": [
                "enabled": true,
                "ignoreHosts": [marker],
            ] as [String: Sendable],
        ]
        return ["analyticsSDK": ["iosSDK": ["autocapture": autocapture] as [String: Sendable]] as [String: Sendable]]
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

    /// `NetworkSwizzler.listeners` is private, so @testable cannot reach it: read it through
    /// Mirror, holding the swizzler's own lock.
    private func swizzlerListeners() throws -> [NetworkTaskListener] {
        let swizzler = NetworkSwizzler.shared
        let lock = try XCTUnwrap(Mirror(reflecting: swizzler).children.first { $0.label == "lock" }?.value as? NSLock,
                                 "NetworkSwizzler.lock not found")
        lock.lock()
        defer { lock.unlock() }
        return try XCTUnwrap(Mirror(reflecting: swizzler).children.first { $0.label == "listeners" }?.value as? [NetworkTaskListener],
                             "NetworkSwizzler.listeners not found")
    }

    private func entries(of plugin: NetworkTrackingPlugin) throws -> Int {
        return try swizzlerListeners().filter { $0 === plugin }.count
    }

    /// AutocaptureManager's registered change callbacks (private), read through Mirror.
    private func changeCallbacks(of manager: AutocaptureManager) throws -> [AutocaptureManager.ChangeCallback] {
        return try XCTUnwrap(Mirror(reflecting: manager).children.first { $0.label == "changeCallbacks" }?.value
                             as? [AutocaptureManager.ChangeCallback],
                             "AutocaptureManager.changeCallbacks not found")
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
