//
//  ConfigurationTests.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

@_spi(Internal) import AmplitudeCore
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
        runtimeStore.takeEventCallback(insertId: "before-startup")
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
            XCTAssertNil(store.diagnosticsClient)
        }
        config.serverZone = .EU
        let amplitude = Amplitude(configuration: config)
        for store in stores {
            XCTAssertTrue(store.diagnosticsClient === amplitude.amplitudeContext.diagnosticsClient)
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
        config.serverZone = .EU
        let amplitude = Amplitude(configuration: config)
        let client = EventPipeline(amplitude: amplitude).httpClient
        XCTAssertEqual(client.getUrl(), Constants.EU_DEFAULT_API_HOST)
        let data = try XCTUnwrap(client.getRequestData(events: "[]").data?.gunzipped())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metadata = try XCTUnwrap(body["request_metadata"] as? [String: Any])
        let sdk = try XCTUnwrap(metadata["sdk"] as? [String: Any])
        let errors = try XCTUnwrap(sdk["error_logs"] as? [String]).filter { $0.contains("Error migrating file:") }
        XCTAssertEqual(errors.count, 2)
        XCTAssertTrue(errors.contains { $0.contains("/before-start ") })
        XCTAssertTrue(errors.contains { $0.contains("/at-start ") })
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

        config.storageProvider.migrateIfNeeded()
        XCTAssertEqual(events.migrationCalls, 1)
        XCTAssertEqual(identifies.migrationCalls, 0)

        let amplitude = Amplitude(configuration: config)
        XCTAssertEqual(events.migrationCalls, 2)
        XCTAssertEqual(identifies.migrationCalls, 1)
        XCTAssertTrue(amplitude.storage as? FakeInMemoryStorage === events)
        XCTAssertTrue(amplitude.identifyStorage as? FakeInMemoryStorage === identifies)
    }

    func testZoneSetBeforeStartupRoutesAnalyticsAndCoreRequestsToEU() async throws {
        let fetched = expectation(description: "EU remote configuration")
        let analyticsUpload = expectation(description: "EU Analytics upload")
        analyticsUpload.assertForOverFulfill = false
        let uploaded = expectation(description: "EU diagnostics upload")
        uploaded.assertForOverFulfill = false
        let transport = ClosureHttpClient { request in
            let url = try XCTUnwrap(request.url)
            var body = Data()
            if request.httpMethod == "GET" {
                XCTAssertEqual(url.host, "sr-client-cfg.eu.amplitude.com")
                body = Data(#"{"configs":{"diagnostics":{"iosSDK":{"enabled":true,"sampleRate":1}}}}"#.utf8)
                fetched.fulfill()
            } else if url.path == "/v1/capture" {
                XCTAssertEqual(url.host, "diagnostics.prod.eu-central-1.amplitude.com")
                uploaded.fulfill()
            } else if url.path == "/2/httpapi" {
                XCTAssertEqual(url.host, "api.eu.amplitude.com")
                analyticsUpload.fulfill()
            }
            return (body, try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
        }
        let config = Configuration(apiKey: apiKey, instanceName: UUID().uuidString, httpClient: transport)
        let eventStorage = try XCTUnwrap(config.storageProvider as? PersistentStorage)
        let identifyStorage = try XCTUnwrap(config.identifyStorageProvider as? PersistentStorage)
        XCTAssertNil(eventStorage.diagnosticsClient)
        XCTAssertNil(identifyStorage.diagnosticsClient)
        ObjCConfiguration(configuration: config).serverZone = .EU
        let amplitude = Amplitude(configuration: config)
        XCTAssertEqual(amplitude.amplitudeContext.serverZone, .EU)
        XCTAssertTrue((amplitude.storage as? PersistentStorage)?.diagnosticsClient === amplitude.amplitudeContext.diagnosticsClient)
        XCTAssertTrue((amplitude.identifyStorage as? PersistentStorage)?.diagnosticsClient === amplitude.amplitudeContext.diagnosticsClient)
        config.serverZone = .US
        amplitude.track(eventType: "zone-test").flush()
        await fulfillment(of: [fetched, analyticsUpload], timeout: 5)

        // Core applies the sampling response asynchronously. Flush until it enables this session.
        let diagnostics = amplitude.amplitudeContext.diagnosticsClient
        let flushTask = Task {
            while !Task.isCancelled {
                await diagnostics.increment(name: "test", size: 1)
                await diagnostics.flush()
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        defer { flushTask.cancel() }
        await fulfillment(of: [uploaded], timeout: 5)
    }

    func testLatePluginAndPipelineUseStartupZone() throws {
        final class ContextPluginProbe: UniversalPlugin {
            var context: AmplitudeContext?

            func setup(analyticsClient: any AnalyticsClient, amplitudeContext: AmplitudeContext) {
                context = amplitudeContext
            }
        }

        let config = Configuration(apiKey: apiKey, instanceName: UUID().uuidString, serverZone: .EU,
                                   httpClient: RemoteConfigMockServer())
        let amplitude = Amplitude(configuration: config)
        config.serverZone = .US

        let plugin = ContextPluginProbe()
        amplitude.add(plugin: plugin)
        let context = try XCTUnwrap(plugin.context)
        XCTAssertEqual(context.serverZone, .EU)
        XCTAssertTrue(context.remoteConfigClient === amplitude.amplitudeContext.remoteConfigClient)
        XCTAssertTrue(context.diagnosticsClient === amplitude.amplitudeContext.diagnosticsClient)

        let client = EventPipeline(amplitude: amplitude).httpClient
        config.useBatch = true
        XCTAssertEqual(client.getUrl(), Constants.EU_BATCH_API_HOST)
        config.serverUrl = "https://proxy.example/upload"
        XCTAssertEqual(client.getUrl(), config.serverUrl)
        config.serverUrl = nil
        XCTAssertEqual(client.getUrl(), Constants.EU_BATCH_API_HOST)
        config.useBatch = false
        XCTAssertEqual(client.getUrl(), Constants.EU_DEFAULT_API_HOST)
    }

    func testIndependentUSAndEUClientsUseTheirOwnRegionalEndpoints() async {
        let allRequests = expectation(description: "Both transports receive remote config, Analytics, and diagnostics")
        allRequests.expectedFulfillmentCount = 6

        func makeClient(zone: ServerZone, key: String, configHost: String, analyticsHost: String,
                        diagnosticsHost: String) -> Amplitude {
            let seenPaths = AtomicRef(wrappedValue: Set<String>())
            let transport = ClosureHttpClient { request in
                let url = try XCTUnwrap(request.url)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                var body = Data()
                switch url.path {
                case "/config/\(key)":
                    XCTAssertEqual(url.host, configHost)
                    body = Data(#"{"configs":{"diagnostics":{"iosSDK":{"enabled":true,"sampleRate":1}}}}"#.utf8)
                case "/2/httpapi":
                    XCTAssertEqual(url.host, analyticsHost)
                    let data = try XCTUnwrap(request.httpBody?.gunzipped())
                    let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    XCTAssertEqual(payload["api_key"] as? String, key)
                case "/v1/capture":
                    XCTAssertEqual(url.host, diagnosticsHost)
                    XCTAssertEqual(request.value(forHTTPHeaderField: "X-ApiKey"), key)
                default:
                    XCTFail("Unexpected request for \(key): \(url)")
                    return (body, response)
                }
                if seenPaths.withLock({ $0.insert(url.path).inserted }) {
                    allRequests.fulfill()
                }
                return (body, response)
            }
            return Amplitude(configuration: Configuration(apiKey: key, instanceName: UUID().uuidString,
                                                         serverZone: zone, autocapture: [], httpClient: transport))
        }

        let us = makeClient(zone: .US, key: "us-test-key", configHost: "sr-client-cfg.amplitude.com",
                            analyticsHost: "api2.amplitude.com", diagnosticsHost: "diagnostics.prod.us-west-2.amplitude.com")
        let eu = makeClient(zone: .EU, key: "eu-test-key", configHost: "sr-client-cfg.eu.amplitude.com",
                            analyticsHost: "api.eu.amplitude.com", diagnosticsHost: "diagnostics.prod.eu-central-1.amplitude.com")
        XCTAssertFalse(us.amplitudeContext.remoteConfigClient === eu.amplitudeContext.remoteConfigClient)
        XCTAssertFalse(us.amplitudeContext.diagnosticsClient === eu.amplitudeContext.diagnosticsClient)

        us.track(eventType: "zone-test").flush()
        eu.track(eventType: "zone-test").flush()

        // Each diagnostics client applies its remote sampling configuration asynchronously.
        let flushTask = Task {
            while !Task.isCancelled {
                for amplitude in [us, eu] {
                    let diagnostics = amplitude.amplitudeContext.diagnosticsClient
                    await diagnostics.increment(name: "test", size: 1)
                    await diagnostics.flush()
                }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        defer { flushTask.cancel() }
        await fulfillment(of: [allRequests], timeout: 5)
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
