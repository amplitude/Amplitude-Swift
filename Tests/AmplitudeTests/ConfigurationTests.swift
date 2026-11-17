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

    func testServerZoneSetBeforeAmplitudeInitRoutesCoreRequestsToEU() async throws {
        let fetched = expectation(description: "EU remote configuration")
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
            }
            return (body, try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
        }
        let config = Configuration(apiKey: apiKey, instanceName: UUID().uuidString, httpClient: transport)
        ObjCConfiguration(configuration: config).serverZone = .EU
        let amplitude = Amplitude(configuration: config)
        XCTAssertEqual(amplitude.amplitudeContext.serverZone, .EU)
        await fulfillment(of: [fetched], timeout: 5)

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

    func testChangingZoneAfterStartupKeepsEU() {
        let config = Configuration(apiKey: apiKey, serverZone: .EU, httpClient: RemoteConfigMockServer())
        let amplitude = Amplitude(configuration: config)
        ObjCConfiguration(configuration: config).serverZone = .US
        XCTAssertEqual(config.serverZone, .US)
        XCTAssertEqual(amplitude.amplitudeContext.serverZone, .EU)
        let pipeline = EventPipeline(amplitude: amplitude)
        XCTAssertEqual(pipeline.httpClient.getUrl(), Constants.EU_DEFAULT_API_HOST)
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
