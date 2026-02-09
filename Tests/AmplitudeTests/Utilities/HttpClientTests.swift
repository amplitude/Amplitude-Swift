//
//  HttpClientTests.swift
//
//
//  Created by Marvin Liu on 11/24/22.
//

import XCTest

@testable import AmplitudeSwift

final class HttpClientTests: XCTestCase {
    private var configuration: Configuration!
    private let diagonostics: Diagnostics = Diagnostics()

    override func setUp() {
        super.setUp()
        configuration = Configuration(apiKey: "testApiKey")
    }

    func testGetUrlWithDefault() {
        let httpClient = HttpClient(configuration: configuration, diagnostics: diagonostics)
        XCTAssertEqual(httpClient.getUrl(), Constants.DEFAULT_API_HOST)
    }

    func testGetUrlWithCustomUrl() {
        let customUrl = "https//localhost.test"
        configuration.serverUrl = customUrl
        let httpClient = HttpClient(configuration: configuration, diagnostics: diagonostics)
        XCTAssertEqual(httpClient.getUrl(), customUrl)
    }

    func testGetRequestWithInvalidUrl() {
        let invalidUrl = "local host"
        configuration.serverUrl = invalidUrl
        let httpClient = HttpClient(configuration: configuration, diagnostics: diagonostics)

        XCTAssertThrowsError(try httpClient.getRequest(isGzipEncoded: false)) { error in
            guard case HttpClient.Exception.invalidUrl(let url) = error else {
                return XCTFail("not getting invalidUrl error")
            }
            XCTAssertEqual(url, invalidUrl)
        }
    }

    func testGetRequestData() {
        let httpClient = FakeHttpClient(configuration: configuration, diagnostics: diagonostics)
        let event = BaseEvent(userId: "unit-test user", eventType: "unit-test event")

        let expectedRequestPayload = """
            {"api_key":"testApiKey","client_upload_time":"2023-10-24T18:16:24.000Z","events":[\(event.toString())]}
            """.data(using: .utf8)

        let (result, isGzipEncoded) = httpClient.getRequestData(events: "[\(event.toString())]")

        XCTAssertEqual(result?.gunzipped(), expectedRequestPayload)
        XCTAssertTrue(isGzipEncoded)
    }

    func testGetResponseDataWithDiagnostic() {
        let httpClient = FakeHttpClient(configuration: configuration, diagnostics: diagonostics)
        let event = BaseEvent(userId: "unit-test user", eventType: "unit-test event")
        diagonostics.addMalformedEvent("malformed event")
        let expectedRequestPayload: Data? = """
            {"api_key":"testApiKey","client_upload_time":"2023-10-24T18:16:24.000Z","events":[\(event.toString())],"request_metadata":{"sdk":{"malformed_events":["malformed event"]}}}
            """.data(using: .utf8)
        let (result, isGzipEncoded) = httpClient.getRequestData(events: "[\(event.toString())]")

        XCTAssertEqual(result?.gunzipped(), expectedRequestPayload)
        XCTAssertTrue(isGzipEncoded)
    }

    func testUploadWithInvalidApiKey() {
        // TODO: currently this test is sending request to real Amplitude host, update to mock for better stability
        let httpClient = HttpClient(configuration: configuration, diagnostics: diagonostics)
        let asyncExpectation = expectation(description: "Async function")
        let event1 = BaseEvent(userId: "unit-test user", deviceId: "unit-test device", eventType: "unit-test event")
        _ = httpClient.upload(events: "[\(event1.toString())]") { result in
            guard case .failure(let error) = result else {
                return XCTFail("not getting upload failure")
            }
            guard case HttpClient.Exception.httpError(let code, let data) = error else {
                return XCTFail("not getting httpError error")
            }
            XCTAssertEqual(code, 400)
            XCTAssertTrue(String(data: data!, encoding: .utf8)!.contains("Invalid API key: testApiKey"))
            asyncExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [asyncExpectation], timeout: 5)
    }

    func testUploadWithCannotConnectToHostError() {
        let config = Configuration(apiKey: "fake", serverUrl: "http://localhost:3000", offline: false)
        let httpClient = HttpClient(configuration: config, diagnostics: diagonostics)
        let uploadExpectation = expectation(description: "Did Call Upload")
        let event = BaseEvent(userId: "unit-test user", eventType: "unit-test event")

        _ = httpClient.upload(events: "[\(event.toString())]") { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, NSURLErrorCannotConnectToHost)
            }

            uploadExpectation.fulfill()
        }

        waitForExpectations(timeout: 15)
        XCTAssertEqual(config.offline, true)
    }

    func testGetRequestSetsGzipHeaderWhenEnabled() throws {
        let httpClient = HttpClient(configuration: configuration, diagnostics: diagonostics)
        let request = try httpClient.getRequest(isGzipEncoded: true)

        let contentEncoding = request.value(forHTTPHeaderField: "Content-Encoding")
        XCTAssertEqual(contentEncoding, "gzip")
    }

    func testShouldCompressUploads() throws {
        // Any default URL should use compression
        for serverZone in [ServerZone.US, ServerZone.EU] {
            for useBatch in [true, false] {
                for enableRequestBodyCompression in [true, false] {
                    let config = Configuration(apiKey: "aaa",
                                               useBatch: useBatch,
                                               serverZone: serverZone,
                                               enableRequestBodyCompression: enableRequestBodyCompression)
                    let httpClient = HttpClient(configuration: config, diagnostics: diagonostics)
                    XCTAssertTrue(httpClient.shouldCompressUploadBody)

                    let (_, isGzipEncoded) = httpClient.getRequestData(events: "events")
                    XCTAssertTrue(isGzipEncoded)
                }
            }
        }

        // Custom URLs should only compress if specified
        let enabledConfig = Configuration(apiKey: "aaa",
                                          serverUrl: "https://www.google.com",
                                          enableRequestBodyCompression: true)
        let enabledHttpClient = HttpClient(configuration: enabledConfig,
                                           diagnostics: diagonostics)
        XCTAssertTrue(enabledHttpClient.shouldCompressUploadBody)
        let (_, enabledRequestIsGzipEncoded) = enabledHttpClient.getRequestData(events: "events")
        XCTAssertTrue(enabledRequestIsGzipEncoded)

        let disabledConfig = Configuration(apiKey: "aaa",
                                          serverUrl: "https://www.google.com",
                                          enableRequestBodyCompression: false)
        let disabledHttpClient = HttpClient(configuration: disabledConfig,
                                           diagnostics: diagonostics)
        XCTAssertFalse(disabledHttpClient.shouldCompressUploadBody)
        let (_, disabledRequestIsGzipEncoded) = disabledHttpClient.getRequestData(events: "events")
        XCTAssertFalse(disabledRequestIsGzipEncoded)
    }
}
