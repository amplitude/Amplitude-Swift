//
//  HttpClientTests.swift
//
//
//  Created by Marvin Liu on 11/24/22.
//

import XCTest

@testable import Amplitude_Swift

final class HttpClientTests: XCTestCase {
    private var configuration: Configuration!

    override func setUp() {
        super.setUp()
        configuration = Configuration(apiKey: "testApiKey")
    }

    func testGetUrlWithDefault() {
        let httpClient = HttpClient(configuration: configuration)
        XCTAssertEqual(httpClient.getUrl(), Constants.DEFAULT_API_HOST)
    }

    func testGetUrlWithCustomUrl() {
        let customUrl = "https//localhost.test"
        configuration.serverUrl = customUrl
        let httpClient = HttpClient(configuration: configuration)
        XCTAssertEqual(httpClient.getUrl(), customUrl)
    }

    func testGetRequestWithInvalidUrl() {
        let invalidUrl = "local host"
        configuration.serverUrl = invalidUrl
        let httpClient = HttpClient(configuration: configuration)

        XCTAssertThrowsError(try httpClient.getRequest()) { error in
            guard case HttpClient.Exception.invalidUrl(let url) = error else {
                return XCTFail("not getting invalidUrl error")
            }
            XCTAssertEqual(url, invalidUrl)
        }
    }

    func testUploadWithInvalidApiKey() {
        // TODO: currently this test is sending request to real Amplitude host, update to mock for better stability
        let httpClient = HttpClient(configuration: configuration)
        let asyncExpectation = expectation(description: "Async function")
        let event1 = BaseEvent(userId: "unit-test user", deviceId: "unit-test device", eventType: "unit-test event")
        httpClient.upload(events: "[\(event1.toString())]") { result in
            guard case .failure(let error) = result else {
                return XCTFail("not getting upload failure")
            }
            guard case HttpClient.Exception.httpError(let code, let data) = error else {
                return XCTFail("not getting httpError error")
            }
            XCTAssertEqual(code, 400)
            XCTAssertTrue(String(decoding: data!, as: UTF8.self).contains("Invalid API key: testApiKey"))
            asyncExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [asyncExpectation], timeout: 5)
    }
}
