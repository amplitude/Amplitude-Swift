//
//  NetworkTrackingPluginTest.swift
//  Amplitude-SwiftTests
//
//  Created by Jin Xu on 4/10/25.
//

import XCTest

@_spi(NetworkTracking)
@testable import AmplitudeSwift

// swiftlint:disable force_cast
final class NetworkTrackingPluginTest: XCTestCase {

    private static let defaultTimeout: TimeInterval = 2
    private var amplitude: Amplitude!
    private var storageMem: FakeInMemoryStorage!
    private var eventCollector = EventCollectorPlugin()

    // Shared session for most requests - reused across tests in this class
    private static var sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = defaultTimeout
        configuration.protocolClasses = [FakeURLProtocol.self]
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }()

    // Track sessions with custom timeouts to invalidate in tearDown
    private var customTimeoutSessions: [URLSession] = []

    static override func setUp() {
        super.setUp()
        URLSessionConfiguration.enableMockDefault()
    }

    static override func tearDown() {
        sharedSession.invalidateAndCancel()
        URLSessionConfiguration.disableMockDefault()
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        storageMem = FakeInMemoryStorage()
    }

    override func tearDown() {
        super.tearDown()
        eventCollector.events.removeAll()
        // Only invalidate custom timeout sessions - shared session is reused
        customTimeoutSessions.forEach { $0.invalidateAndCancel() }
        customTimeoutSessions.removeAll()
    }

    func setupAmplitude(with options: NetworkTrackingOptions = NetworkTrackingOptions.default) {
        let configuration = Configuration(apiKey: "test-api-key",
                                          storageProvider: storageMem,
                                          flushMaxRetries: 0,
                                          autocapture: .networkTracking,
                                          offline: NetworkConnectivityCheckerPlugin.Disabled,
                                          networkTrackingOptions: options,
                                          enableAutoCaptureRemoteConfig: false)
        amplitude = Amplitude(configuration: configuration)
        amplitude.add(plugin: eventCollector)
    }

    var networkTrackingPlugin: NetworkTrackingPlugin? {
        return amplitude.timeline.plugins[PluginType.utility]?.plugins.first {
            $0 is NetworkTrackingPlugin
        } as? NetworkTrackingPlugin
    }

    func taskForRequest(_ url: String = "https://example.com",
                        method: String = "GET",
                        requestHeaders: [String: String]? = nil,
                        requestBody: Data? = nil,
                        timeout: TimeInterval = defaultTimeout,
                        _ completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.httpBody = requestBody

        requestHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Use shared session for default timeout, create new one only for custom timeouts
        let session: URLSession
        if timeout == Self.defaultTimeout {
            session = Self.sharedSession
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.protocolClasses = [FakeURLProtocol.self]
            session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
            customTimeoutSessions.append(session)
        }
        return session.dataTask(with: request, completionHandler: completionHandler)
    }

    @discardableResult
    func request(_ url: String = "https://example.com",
                 method: String = "GET") async throws -> (Data, URLResponse) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        // Always use shared session for async requests (default timeout)
        return try await Self.sharedSession.data(for: request)
    }

#if !os(watchOS)
    func testDefaultNetworkTrackingOptionsShouldCapture500() {
        setupAmplitude()
        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]

        let expectation = XCTestExpectation(description: "Network request finished")
        taskForRequest("https://example.com?test=1#hash") { _, _, _ in
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 2)

        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://example.com")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_QUERY_PROPERTY] as! String, "test=1")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_FRAGMENT_PROPERTY] as! String, "hash")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY] as! String, "GET")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 500)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_START_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_COMPLETION_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_DURATION_PROPERTY] as! Int64 > 0)
    }

    func testDefaultNetworkTrackingOptionsShouldNotCapture200() {
        setupAmplitude()
        FakeURLProtocol.mockResponses = [.init(statusCode: 200)]

        let expectation = XCTestExpectation(description: "Network request finished")
        taskForRequest { _, _, _ in
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 2)

        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 0, "Should not capture network request event with status code 200")
    }

    func testDefaultNetworkTrackingOptionsShouldNotCaptureAmplitude() {
        setupAmplitude()

        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]

        amplitude.track(eventType: "Test")
        amplitude.flush()

        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0] is NetworkRequestEvent)
    }

    func testNetworkTrackingOptionsIgnoreAmplitudeRequestsFalse() {
        var options = NetworkTrackingOptions.default
        options.ignoreAmplitudeRequests = false
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]

        amplitude.track(eventType: "Test")
        amplitude.flush()

        wait(for: 0.1)
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2)
        let event = events[1] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://api2.amplitude.com/2/httpapi")
    }

    func testNetworkTrackingOptionsIgnoreHosts() {
        var options = NetworkTrackingOptions.default
        options.ignoreHosts = ["*.example.com", "example2.com"]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [.init(statusCode: 500), .init(statusCode: 500)]

        let expectations = (0..<2).map { _ in XCTestExpectation(description: "Network request finished") }
        taskForRequest("https://api.example.com/api") { _, _, _ in
            expectations[0].fulfill()
        }.resume()
        taskForRequest("https://example2.com/api") { _, _, _ in
            expectations[1].fulfill()
        }.resume()
        wait(for: expectations, timeout: 2)

        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 0)
    }

    func testNetworkTrackingOptionsCaptureHosts() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [.init(hosts: ["*.example.com", "example2.com"])]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [.init(statusCode: 500), .init(statusCode: 500)]

        let url0 = "https://api.example.com/api"
        let url1 = "https://example2.com/api"
        let url3 = "https://example.com/api"

        let expectations = (0..<2).map { _ in XCTestExpectation(description: "Network request finished") }
        taskForRequest(url0) { _, _, _ in
            expectations[0].fulfill()
        }.resume()
        taskForRequest(url1) { _, _, _ in
            expectations[1].fulfill()
        }.resume()
        wait(for: expectations, timeout: 2)

        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2, "Should capture two network requests")
        let event = events[0] as! NetworkRequestEvent
        let event2 = events[1] as! NetworkRequestEvent
        let urls = [event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String,
                    event2.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String]
        XCTAssertFalse(urls.contains(url3), "Should not capture requests to other hosts")
        XCTAssertTrue(urls.contains(url0), "Should capture requests to the specified hosts")
        XCTAssertTrue(urls.contains(url1), "Should capture requests to the specified hosts")
    }

    func testNetworkTrackingOptionsCaptureStatusCode() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [.init(hosts: ["*"], statusCodeRange: "413,500-599")]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [.init(statusCode: 200), .init(statusCode: 413), .init(statusCode: 500)]

        let expectations = (0..<3).map { _ in XCTestExpectation(description: "Network request finished") }

        taskForRequest { _, _, _ in
            expectations[0].fulfill()
        }.resume()
        taskForRequest { _, _, _ in
            expectations[1].fulfill()
        }.resume()
        taskForRequest { _, _, _ in
            expectations[2].fulfill()
        }.resume()
        wait(for: expectations, timeout: 2)

        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2, "Should capture two network requests")
        let event = events[0] as! NetworkRequestEvent
        let event2 = events[1] as! NetworkRequestEvent
        let statusCodes = [event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int,
                           event2.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int]
        XCTAssertFalse(statusCodes.contains(200), "Should not capture requests with status codes outside the specified range")
        XCTAssertTrue(statusCodes.contains(413), "Should capture requests with status codes inside the specified range")
        XCTAssertTrue(statusCodes.contains(500), "Should capture requests with status codes inside the specified range")
    }

    func testNetworkTrackingOptionsCaptureLocalError() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [.init(hosts: ["*"], statusCodeRange: "0")]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [.init(statusCode: 200, delay: 2)]

        let expectation = XCTestExpectation(description: "Network request finished")
        taskForRequest(timeout: 0.1) { _, _, _ in
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 2)

        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://example.com")
        XCTAssertNil(event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as Any?)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_ERROR_CODE_PROPERTY] as! Int, -1001)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_ERROR_MESSAGE_PROPERTY] as! String, "The request timed out.")
    }

    func testCapturingAsyncTasks() {
        setupAmplitude()
        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]

        let expectation = XCTestExpectation(description: "Network request finished")
        Task {
            try await request("https://example.com")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        wait() // Wait for Autocapture works
        amplitude.waitForTrackingQueue()

        wait(for: 1)

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://example.com")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_START_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_COMPLETION_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_DURATION_PROPERTY] as! Int64 > 0)
    }

    func testCapturingUploadTask() {
        setupAmplitude()
        let responseBodyData = "Bar".data(using: .utf8)!
        FakeURLProtocol.mockResponses = [.init(statusCode: 500, data: responseBodyData)]

        let expectation = XCTestExpectation(description: "Network request finished")
        let requestBodyData = "Foo".data(using: .utf8)!
        let url = URL(string: "https://httpbin.org/status/500")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        Self.sharedSession.uploadTask(with: request, from: requestBodyData, completionHandler: { _, _, _ in
            expectation.fulfill()
        }).resume()
        wait(for: [expectation], timeout: 2)

        wait() // Wait for Autocapture works
        amplitude.waitForTrackingQueue()
        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://httpbin.org/status/500")

        // This can only pass when sending a real network request becase there is no public api for URLProtocol to mock upload data
        // XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] as! Int64, Int64(requestBodyData.count))
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, Int64(responseBodyData.count))
    }

    func testCapturingDownloadTask() {
        setupAmplitude()

        let responseBodyData = "Bar".data(using: .utf8)!
        FakeURLProtocol.mockResponses = [.init(statusCode: 500, data: responseBodyData)]

        let expectation = XCTestExpectation(description: "Network request finished")
        let url = URL(string: "https://httpbin.org/status/500")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        Self.sharedSession.downloadTask(with: request, completionHandler: { _, _, _ in
            expectation.fulfill()
        }).resume()
        wait(for: [expectation], timeout: 2)

        wait() // Wait for Autocapture works
        amplitude.waitForTrackingQueue()
        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://httpbin.org/status/500")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, Int64(responseBodyData.count))
    }

    func testRuleForHost() {
        let options = NetworkTrackingOptions(captureRules: [
            .init(hosts: ["*.example.com"], statusCodeRange: "0,500-599"),
            .init(hosts: ["api.example.com"], statusCodeRange: "400-499"),
            .init(hosts: ["*.test.com"], statusCodeRange: "500-599")
        ])
        setupAmplitude(with: options)

        let plugin = networkTrackingPlugin!

        let rule = plugin.ruleForRequest(URLRequest(url: URL(string: "https://api.example.com/foo")!))
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule!.statusCodeIndexSet, IndexSet(400...499))

        let rule2 = plugin.ruleForRequest(URLRequest(url: URL(string: "https://api2.example.com/foo")!))
        XCTAssertNotNil(rule2)
        XCTAssertEqual(rule2!.statusCodeIndexSet,
                       IndexSet(integer: 0).union(IndexSet(500...599)))

        let rule3 = plugin.ruleForRequest(URLRequest(url: URL(string: "https://example.com/foo")!))
        XCTAssertNil(rule3)

        // Run requests sequentially to ensure deterministic mock response assignment.
        // Parallel execution causes race conditions where the wrong URL may receive the wrong status code.

        // Request 1: api.example.com with 400 -> should be captured (matches rule for 400-499)
        FakeURLProtocol.mockResponses = [.init(statusCode: 400)]
        let expectation1 = XCTestExpectation(description: "Request 1 finished")
        taskForRequest("https://api.example.com") { _, _, _ in
            expectation1.fulfill()
        }.resume()
        wait(for: [expectation1], timeout: 2)

        // Request 2: api.example.com with 500 -> should NOT be captured (rule only allows 400-499)
        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]
        let expectation2 = XCTestExpectation(description: "Request 2 finished")
        taskForRequest("https://api.example.com") { _, _, _ in
            expectation2.fulfill()
        }.resume()
        wait(for: [expectation2], timeout: 2)

        // Request 3: api2.example.com with 500 -> should be captured (matches wildcard rule for 0,500-599)
        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]
        let expectation3 = XCTestExpectation(description: "Request 3 finished")
        taskForRequest("https://api2.example.com") { _, _, _ in
            expectation3.fulfill()
        }.resume()
        wait(for: [expectation3], timeout: 2)

        wait()
        plugin.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        XCTAssertTrue(events[1] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://api.example.com")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 400)
        let event2 = events[1] as! NetworkRequestEvent
        XCTAssertEqual(event2.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://api2.example.com")
        XCTAssertEqual(event2.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 500)
    }

    func testCaptureHeaderFields() {
        let requestHeaders = ["custom-header-1": "value1", "custom-header-2": "value2", "other-header": "value-other"]
        let responseHeaders = ["custom-header-3": "value3", "custom-header-4": "value4", "other-header": "value-other"]
        let expectedRequestHeaders = requestHeaders.filter { ["custom-header-1", "custom-header-2"].contains($0.key) }
        let expectedResponseHeaders = responseHeaders.filter { ["custom-header-3", "custom-header-4"].contains($0.key) }

        let options: NetworkTrackingOptions = .init(captureRules: [
            .init(urls: [.regex("https://example\\.com.*")],
                  requestHeaders: .init(allowlist: ["custom-header-1", "custom-header-2"]),
                  responseHeaders: .init(allowlist: ["custom-header-3", "custom-header-4"]))
        ])
        setupAmplitude(with: options)
        FakeURLProtocol.mockResponses = [.init(statusCode: 500, headers: responseHeaders)]

        let expectation = XCTestExpectation(description: "Network request finished")
        taskForRequest("https://example.com?test=1#hash", requestHeaders: requestHeaders) { _, _, _ in
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 2)

        wait() // Wait for Autocapture works
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://example.com")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_QUERY_PROPERTY] as! String, "test=1")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_FRAGMENT_PROPERTY] as! String, "hash")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY] as! String, "GET")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 500)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_START_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_COMPLETION_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_DURATION_PROPERTY] as! Int64 > 0)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_HEADERS_PROPERTY] as! NSDictionary, expectedRequestHeaders as NSDictionary)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_HEADERS_PROPERTY] as! NSDictionary, expectedResponseHeaders as NSDictionary)
    }

    // MARK: - URL Pattern Matching Tests

    func testURLExactMatching() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [.exact("https://api.example.com/v1/users")],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<3).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - exact URL
        taskForRequest("https://api.example.com/v1/users") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should NOT match - different path
        taskForRequest("https://api.example.com/v1/posts") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should NOT match - extra query params
        taskForRequest("https://api.example.com/v1/users?id=123") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1, "Should capture only matching URLs")

        // Verify event captured correctly
        for event in events {
            let networkEvent = event as! NetworkRequestEvent
            XCTAssertEqual(networkEvent.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://api.example.com/v1/users")
            XCTAssertNil(networkEvent.eventProperties?[Constants.AMP_NETWORK_URL_QUERY_PROPERTY])
            XCTAssertNil(networkEvent.eventProperties?[Constants.AMP_NETWORK_URL_FRAGMENT_PROPERTY])
        }
    }

    func testURLRegexMatching() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [
                    .regex(".*\\/api\\/v[0-9]+\\/users.*"),
                    .regex(".*\\/health.*")
                ],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<5).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - v1 users endpoint
        taskForRequest("https://api.example.com/api/v1/users") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should match - v2 users endpoint
        taskForRequest("https://api.example.com/api/v2/users/123") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should NOT match - posts endpoint
        taskForRequest("https://api.example.com/api/v1/posts") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        // Should match - health check
        taskForRequest("https://monitoring.example.com/health/status") { _, _, _ in
            expectations[3].fulfill()
        }.resume()

        // Should NOT match - no pattern match
        taskForRequest("https://api.example.com/login") { _, _, _ in
            expectations[4].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 3, "Should capture only regex matching URLs")

        // Verify matched URLs
        let capturedURLs = events.compactMap { event in
            (event as? NetworkRequestEvent)?.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as? String
        }
        XCTAssertTrue(capturedURLs.contains("https://api.example.com/api/v1/users"))
        XCTAssertTrue(capturedURLs.contains("https://api.example.com/api/v2/users/123"))
        XCTAssertTrue(capturedURLs.contains("https://monitoring.example.com/health/status"))
    }

    func testURLRegexAnchors() {
        // Test regex patterns with ^ (start) and $ (end) anchors
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [
                    .regex("^https://api\\.example\\.com/v1/.*"),     // Starts with specific domain/path
                    .regex(".*\\/users$"),                            // Ends with /users
                    .regex("^https://exact\\.example\\.com/path$")    // Exact match with anchors
                ],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = Array(repeating: FakeURLProtocol.MockResponse(statusCode: 200), count: 8)

        let expectations = (0..<8).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - starts with https://api.example.com/v1/
        taskForRequest("https://api.example.com/v1/posts") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should NOT match - different domain prefix
        taskForRequest("https://staging-api.example.com/v1/posts") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should match - ends with /users
        taskForRequest("https://any.domain.com/api/users") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        // Should NOT match - has something after /users
        taskForRequest("https://any.domain.com/api/users/123") { _, _, _ in
            expectations[3].fulfill()
        }.resume()

        // Should match - exact match with anchors
        taskForRequest("https://exact.example.com/path") { _, _, _ in
            expectations[4].fulfill()
        }.resume()

        // Should NOT match - has extra path after
        taskForRequest("https://exact.example.com/path/extra") { _, _, _ in
            expectations[5].fulfill()
        }.resume()

        // Should NOT match - different prefix
        taskForRequest("https://other.exact.example.com/path") { _, _, _ in
            expectations[6].fulfill()
        }.resume()

        // Should match - both patterns (starts with api.example.com/v1 AND ends with /users)
        taskForRequest("https://api.example.com/v1/users") { _, _, _ in
            expectations[7].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 4, "Should capture only URLs matching the anchored regex patterns")

        // Verify the matched URLs
        let capturedURLs = events.compactMap { event in
            (event as? NetworkRequestEvent)?.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as? String
        }

        XCTAssertTrue(capturedURLs.contains("https://api.example.com/v1/posts"), "Should match URL starting with api.example.com/v1/")
        XCTAssertTrue(capturedURLs.contains("https://any.domain.com/api/users"), "Should match URL ending with /users")
        XCTAssertTrue(capturedURLs.contains("https://exact.example.com/path"), "Should match exact URL with anchors")
        XCTAssertTrue(capturedURLs.contains("https://api.example.com/v1/users"), "Should match URL matching multiple patterns")

        // Verify non-matched URLs are not captured
        XCTAssertFalse(capturedURLs.contains("https://staging-api.example.com/v1/posts"), "Should not match different prefix")
        XCTAssertFalse(capturedURLs.contains("https://any.domain.com/api/users/123"), "Should not match with extra path after /users")
        XCTAssertFalse(capturedURLs.contains("https://exact.example.com/path/extra"), "Should not match with extra path")
        XCTAssertFalse(capturedURLs.contains("https://other.exact.example.com/path"), "Should not match different subdomain")
    }

    func testURLPatternPriority() {
        // Test that URL patterns take priority over host patterns when both are specified
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [.exact("https://api.example.com/v1/specific")],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<2).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - exact URL match
        taskForRequest("https://api.example.com/v1/specific") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should NOT match - host matches but URL pattern doesn't
        taskForRequest("https://api.example.com/v1/other") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1, "URL patterns should take priority over host patterns")

        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://api.example.com/v1/specific")
    }

    // MARK: - HTTP Method Matching Tests

    func testHTTPMethodMatching() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [.regex(".*\\.example\\.com.*")],
                methods: ["GET", "POST"],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<4).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - GET request
        taskForRequest("https://api.example.com/data", method: "GET") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should match - POST request
        taskForRequest("https://api.example.com/data", method: "POST") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should NOT match - PUT request
        taskForRequest("https://api.example.com/data", method: "PUT") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        // Should NOT match - DELETE request
        taskForRequest("https://api.example.com/data", method: "DELETE") { _, _, _ in
            expectations[3].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2, "Should capture only GET and POST requests")

        // Verify captured methods
        let capturedMethods = events.compactMap { event in
            (event as? NetworkRequestEvent)?.eventProperties?[Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY] as? String
        }
        XCTAssertTrue(capturedMethods.contains("GET"))
        XCTAssertTrue(capturedMethods.contains("POST"))
    }

    func testHTTPMethodWildcard() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [.regex(".*\\.example\\.com.*")],
                methods: ["*"],  // Wildcard - capture all methods
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<3).map { _ in XCTestExpectation(description: "Network request finished") }

        // All methods should match with wildcard
        taskForRequest("https://api.example.com/data", method: "GET") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        taskForRequest("https://api.example.com/data", method: "PUT") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        taskForRequest("https://api.example.com/data", method: "DELETE") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 3, "Should capture all HTTP methods with wildcard")
    }

    func testHTTPMethodCaseInsensitive() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [.regex(".*\\.example\\.com.*")],
                methods: ["get", "POST"],  // Mixed case
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200),
            .init(statusCode: 200),
            .init(statusCode: 200)
        ]

        let expectations = (0..<3).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match regardless of case
        taskForRequest("https://api.example.com/data", method: "GET") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        taskForRequest("https://api.example.com/data", method: "get") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        taskForRequest("https://api.example.com/data", method: "post") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 3, "Method matching should be case-insensitive")
    }

    func testCombinedURLAndMethodFiltering() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(
                urls: [
                    .exact("https://api.example.com/v1/users"),
                    .regex(".*\\/products\\/.*")
                ],
                methods: ["POST", "PUT"],
                statusCodeRange: "200-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = Array(repeating: FakeURLProtocol.MockResponse(statusCode: 200), count: 6)

        let expectations = (0..<6).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match - correct URL and method
        taskForRequest("https://api.example.com/v1/users", method: "POST") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should NOT match - correct URL, wrong method
        taskForRequest("https://api.example.com/v1/users", method: "GET") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should match - regex URL match with correct method
        taskForRequest("https://store.example.com/products/123", method: "PUT") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        // Should NOT match - regex URL match but wrong method
        taskForRequest("https://store.example.com/products/456", method: "DELETE") { _, _, _ in
            expectations[3].fulfill()
        }.resume()

        // Should NOT match - wrong URL, correct method
        taskForRequest("https://api.example.com/v1/orders", method: "POST") { _, _, _ in
            expectations[4].fulfill()
        }.resume()

        // Should NOT match - wrong URL and wrong method
        taskForRequest("https://api.example.com/v1/orders", method: "GET") { _, _, _ in
            expectations[5].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2, "Should capture only requests matching both URL and method criteria")

        // Verify the captured events (order independent)
        let capturedRequests = events.compactMap { event -> (url: String, method: String)? in
            let networkEvent = event as! NetworkRequestEvent
            guard let url = networkEvent.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as? String,
                  let method = networkEvent.eventProperties?[Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY] as? String else {
                return nil
            }
            return (url: url, method: method)
        }

        XCTAssertTrue(capturedRequests.contains { $0.url == "https://api.example.com/v1/users" && $0.method == "POST" })
        XCTAssertTrue(capturedRequests.contains { $0.url == "https://store.example.com/products/123" && $0.method == "PUT" })
    }

    func testResponseBodyCapture() {
        // Setup network tracking with response body capture
        let options = NetworkTrackingOptions(
            captureRules: [
                NetworkTrackingOptions.CaptureRule(
                    urls: [.exact("https://api.example.com/v1/users")],
                    methods: ["POST"],
                    statusCodeRange: "200-299",
                    requestHeaders: NetworkTrackingOptions.CaptureHeader(),
                    responseHeaders: NetworkTrackingOptions.CaptureHeader(),
                    requestBody: NetworkTrackingOptions.CaptureBody(
                        allowlist: ["name", "email"],
                        blocklist: ["password"]
                    ),
                    responseBody: NetworkTrackingOptions.CaptureBody(
                        allowlist: ["id", "name", "created_at"],
                        blocklist: ["internal_data"]
                    )
                )
            ]
        )

        setupAmplitude(with: options)

        let responseData = """
        {
            "id": "user_123",
            "name": "John Doe",
            "created_at": "2025-01-01T00:00:00Z",
            "internal_data": "should_be_filtered"
        }
        """.data(using: .utf8)!

        // Setup mock response with response body
        FakeURLProtocol.mockResponses = [
            .init(statusCode: 201, data: responseData)
        ]

        // Create POST request with JSON body
        let url = URL(string: "https://api.example.com/v1/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = """
        {
            "name": "John Doe",
            "email": "john@example.com",
            "password": "secret123"
        }
        """.data(using: .utf8)

        let expectation = XCTestExpectation(description: "Network request finished")

        // Create a data task with completion handler using the shared session
        let task = Self.sharedSession.dataTask(with: request) { _, _, _ in
            expectation.fulfill()
        }

        task.resume()

        wait(for: [expectation], timeout: 2.0)
        wait(for: 0.2)
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1, "Should capture 1 POST request")

        let event = events[0]
        XCTAssertEqual(event.eventType, "[Amplitude] Network Request")

        let props = event.eventProperties
        XCTAssertNotNil(props)

        // Check request body was captured and filtered
        if let requestBodyString = props?[Constants.AMP_NETWORK_REQUEST_BODY_PROPERTY] as? String {
            let requestBodyData = requestBodyString.data(using: .utf8)!
            let requestJson = try? JSONSerialization.jsonObject(with: requestBodyData, options: []) as? [String: Any]
            XCTAssertNotNil(requestJson)
            XCTAssertEqual(requestJson?["name"] as? String, "John Doe")
            XCTAssertEqual(requestJson?["email"] as? String, "john@example.com")
            XCTAssertNil(requestJson?["password"], "Password should be filtered out")
        }

        // Check if response body is captured (may be nil currently due to swizzling limitations)
        if let responseBodyString = props?[Constants.AMP_NETWORK_RESPONSE_BODY_PROPERTY] as? String {
            print("Response body captured: \(responseBodyString)")
            let responseBodyData = responseBodyString.data(using: .utf8)!
            let responseJson = try? JSONSerialization.jsonObject(with: responseBodyData, options: []) as? [String: Any]
            XCTAssertNotNil(responseJson)
            XCTAssertEqual(responseJson?["id"] as? String, "user_123")
            XCTAssertEqual(responseJson?["name"] as? String, "John Doe")
            XCTAssertEqual(responseJson?["created_at"] as? String, "2025-01-01T00:00:00Z")
            XCTAssertNil(responseJson?["internal_data"], "Internal data should be filtered out")
        } else {
            XCTFail("Note: Response body not captured")
        }
    }

    func testResponseBodyCaptureWithURL() {
        // Test response body capture with dataTask(with: URL, completionHandler:)
        let options = NetworkTrackingOptions(
            captureRules: [
                NetworkTrackingOptions.CaptureRule(
                    urls: [.exact("https://api.example.com/v1/products")],
                    methods: ["GET"],
                    statusCodeRange: "200-299",
                    requestHeaders: NetworkTrackingOptions.CaptureHeader(),
                    responseHeaders: NetworkTrackingOptions.CaptureHeader(),
                    requestBody: nil,  // GET requests typically don't have body
                    responseBody: NetworkTrackingOptions.CaptureBody(
                        allowlist: ["products", "total"],
                        blocklist: ["internal_metadata"]
                    )
                )
            ]
        )

        setupAmplitude(with: options)

        let responseData = """
        {
            "products": [
                {"id": "prod_1", "name": "Product 1", "price": 99.99},
                {"id": "prod_2", "name": "Product 2", "price": 149.99}
            ],
            "total": 2,
            "internal_metadata": {
                "cache_key": "secret",
                "debug_info": "should_not_be_captured"
            }
        }
        """.data(using: .utf8)!

        // Setup mock response with response body
        FakeURLProtocol.mockResponses = [
            .init(statusCode: 200, data: responseData)
        ]

        // Create URL directly (not URLRequest)
        let url = URL(string: "https://api.example.com/v1/products")!

        let expectation = XCTestExpectation(description: "Network request finished")

        // Use dataTask with URL directly (not URLRequest) via shared session
        let task = Self.sharedSession.dataTask(with: url) { _, _, _ in
            expectation.fulfill()
        }

        task.resume()

        wait(for: [expectation], timeout: 2.0)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 1, "Should capture 1 GET request")

        let event = events[0]
        XCTAssertEqual(event.eventType, "[Amplitude] Network Request")

        let props = event.eventProperties
        XCTAssertNotNil(props)

        // Check URL and method
        XCTAssertEqual(props?[Constants.AMP_NETWORK_URL_PROPERTY] as? String, "https://api.example.com/v1/products")
        XCTAssertEqual(props?[Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY] as? String, "GET")

        // Check if response body is captured and filtered
        if let responseBodyString = props?[Constants.AMP_NETWORK_RESPONSE_BODY_PROPERTY] as? String {
            print("Response body captured with URL-based dataTask: \(responseBodyString)")
            let responseBodyData = responseBodyString.data(using: .utf8)!
            let responseJson = try? JSONSerialization.jsonObject(with: responseBodyData, options: []) as? [String: Any]
            XCTAssertNotNil(responseJson)

            // Check that allowed fields are present
            XCTAssertNotNil(responseJson?["products"], "Products should be captured")
            XCTAssertEqual(responseJson?["total"] as? Int, 2)

            // Check that blocked field is filtered out
            XCTAssertNil(responseJson?["internal_metadata"], "Internal metadata should be filtered out")

            // Verify products array content
            if let products = responseJson?["products"] as? [[String: Any]] {
                XCTAssertEqual(products.count, 2)
                XCTAssertEqual(products[0]["id"] as? String, "prod_1")
                XCTAssertEqual(products[0]["name"] as? String, "Product 1")
            }
        } else {
            XCTFail("Response body should be captured for URL-based dataTask")
        }
    }

    func testMultipleRulesWithDifferentPatterns() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            // Rule 1: Specific API endpoints with POST only
            .init(
                urls: [.exact("https://api.example.com/v1/users")],
                methods: ["POST"],
                statusCodeRange: "200-599"
            ),
            // Rule 2: All health endpoints with any method
            .init(
                urls: [.regex(".*\\/health.*")],
                methods: ["*"],
                statusCodeRange: "200-599"
            ),
            // Rule 3: Legacy host-based rule for backwards compatibility
            .init(
                hosts: ["legacy.example.com"],
                statusCodeRange: "400-599"
            )
        ]
        setupAmplitude(with: options)

        FakeURLProtocol.mockResponses = Array(repeating: FakeURLProtocol.MockResponse(statusCode: 200), count: 5)

        let expectations = (0..<5).map { _ in XCTestExpectation(description: "Network request finished") }

        // Should match rule 1
        taskForRequest("https://api.example.com/v1/users", method: "POST") { _, _, _ in
            expectations[0].fulfill()
        }.resume()

        // Should match rule 2
        taskForRequest("https://monitoring.example.com/health/check", method: "GET") { _, _, _ in
            expectations[1].fulfill()
        }.resume()

        // Should NOT match any rule (legacy host with 200 status)
        taskForRequest("https://legacy.example.com/api", method: "GET") { _, _, _ in
            expectations[2].fulfill()
        }.resume()

        // Should NOT match - wrong method for rule 1
        taskForRequest("https://api.example.com/v1/users", method: "GET") { _, _, _ in
            expectations[3].fulfill()
        }.resume()

        // Should match rule 2 with different method
        taskForRequest("https://api.example.com/health/status", method: "POST") { _, _, _ in
            expectations[4].fulfill()
        }.resume()

        wait(for: expectations, timeout: 2)
        wait()
        networkTrackingPlugin?.waitforNetworkTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 3, "Should capture requests matching any of the rules")
    }
#else
    func testShouldOptOutOnWatchOS() {
        setupAmplitude()

        let plugin = amplitude.timeline.plugins[PluginType.utility]?.plugins.first {
            $0 is NetworkTrackingPlugin
        } as! NetworkTrackingPlugin

        XCTAssertTrue(plugin.optOut, "Should opt out on watchOS")
    }
#endif

    func wait(for interval: TimeInterval = 0.1) {
        let expectation = XCTestExpectation(description: "Wait for time interval")
        XCTWaiter().wait(for: [expectation], timeout: interval)
    }
}
// swiftlint:enable force_cast

// swiftlint:disable force_try
final class NetworkTrackingOptionsInternalTest: XCTestCase {
    func testInitWithDefaultOptions() throws {
        let options = NetworkTrackingOptions.default
        let internalOptions = try CompiledNetworkTrackingOptions(options: options)

        XCTAssertEqual(internalOptions.captureRules.count, 1)
        XCTAssertEqual(internalOptions.ignoreHosts.hostSet.count, 0)
        XCTAssertEqual(internalOptions.ignoreHosts.hostPatterns.count, 1)
        XCTAssertEqual(internalOptions.ignoreHosts.hostPatterns,
                       [try! NSRegularExpression(pattern: "^.*\\.amplitude\\.com$", options: [.caseInsensitive])])
        XCTAssertEqual(internalOptions.captureRules[0].statusCodeIndexSet, IndexSet(500...599))
    }

    func testHostWithPort() throws {
        let options = NetworkTrackingOptions(captureRules: [.init(hosts: ["*.example.com:8080"])])

        let internalOptions = try CompiledNetworkTrackingOptions(options: options)
        XCTAssertEqual(internalOptions.captureRules[0].hosts?.hostPatterns.count, 1)
        XCTAssertEqual(internalOptions.captureRules[0].hosts?.hostPatterns,
                       [try! NSRegularExpression(pattern: "^.*\\.example\\.com:8080$", options: [.caseInsensitive])])
        XCTAssertTrue(internalOptions.captureRules[0].hosts!.matches("api.example.com:8080"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts!.matches("api.example.com"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts!.matches("api.example.com:8081"))
    }

    func testInitWithCustomOptions() throws {
        var options = NetworkTrackingOptions.default
        options.ignoreHosts = ["example.com", "*.test.com"]
        options.ignoreAmplitudeRequests = false
        options.captureRules = [
            .init(hosts: ["api.example.com"], statusCodeRange: "400-499"),
            .init(hosts: ["*.test.com"], statusCodeRange: "500-599")
        ]

        let internalOptions = try CompiledNetworkTrackingOptions(options: options)

        XCTAssertEqual(internalOptions.ignoreHosts.hostSet.count, 1) // example.com
        XCTAssertEqual(internalOptions.ignoreHosts.hostSet, ["example.com"])
        XCTAssertEqual(internalOptions.ignoreHosts.hostPatterns.count, 1) // *.test.com
        XCTAssertEqual(internalOptions.ignoreHosts.hostPatterns,
                       [try! NSRegularExpression(pattern: "^.*\\.test\\.com$", options: [.caseInsensitive])])

        XCTAssertEqual(internalOptions.captureRules.count, 2)
        XCTAssertEqual(internalOptions.captureRules[0].statusCodeIndexSet, IndexSet(400...499))
        XCTAssertEqual(internalOptions.captureRules[0].hosts!.hostSet.count, 1)
        XCTAssertEqual(internalOptions.captureRules[0].hosts!.hostSet, ["api.example.com"])
        XCTAssertEqual(internalOptions.captureRules[0].hosts!.hostPatterns.count, 0)
        XCTAssertEqual(internalOptions.captureRules[1].statusCodeIndexSet, IndexSet(500...599))
        XCTAssertEqual(internalOptions.captureRules[1].hosts!.hostSet.count, 0)
        XCTAssertEqual(internalOptions.captureRules[1].hosts!.hostPatterns.count, 1)
        XCTAssertEqual(internalOptions.captureRules[1].hosts!.hostPatterns,
                       [try! NSRegularExpression(pattern: "^.*\\.test\\.com$", options: [.caseInsensitive])])
    }

    func testHostMatching() throws {
        var options = NetworkTrackingOptions.default
        options.ignoreHosts = ["example.com", "*.test.com"]
        options.captureRules = [
            .init(hosts: ["api.example.com"], statusCodeRange: "400-499"),
            .init(hosts: ["*.test.com"], statusCodeRange: "500-599")
        ]

        let internalOptions = try CompiledNetworkTrackingOptions(options: options)

        // Test exact host matching
        XCTAssertTrue(internalOptions.ignoreHosts.matches("example.com"))
        XCTAssertFalse(internalOptions.ignoreHosts.matches("api.example.com"))

        // Test wildcard host matching
        XCTAssertTrue(internalOptions.ignoreHosts.matches("sub.test.com"))
        XCTAssertTrue(internalOptions.ignoreHosts.matches("another.sub.test.com"))
        XCTAssertFalse(internalOptions.ignoreHosts.matches("test.com"))

        // Test capture rule host matching
        XCTAssertTrue(internalOptions.captureRules[0].hosts!.matches("api.example.com"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts!.matches("example.com"))
        XCTAssertTrue(internalOptions.captureRules[1].hosts!.matches("sub.test.com"))
        XCTAssertTrue(internalOptions.captureRules[1].hosts!.matches("another.sub.test.com"))
    }

    func testStatusCodeRangeParsing() throws {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(hosts: ["*"], statusCodeRange: "0,400-499,500-599")
        ]

        let internalOptions = try CompiledNetworkTrackingOptions(options: options)
        let rule = internalOptions.captureRules[0]

        let expectedIndexSet = IndexSet(integer: 0).union(IndexSet(400...499)).union(IndexSet(500...599))
        XCTAssertEqual(rule.statusCodeIndexSet, expectedIndexSet)
    }

    func testInvalidStatusCodeRange() {
        var options = NetworkTrackingOptions.default
        options.captureRules = [
            .init(hosts: ["*"], statusCodeRange: "invalid")
        ]

        XCTAssertThrowsError(try CompiledNetworkTrackingOptions(options: options)) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }
}
// swiftlint:enable force_try

final class IndexSetExtensionTest: XCTestCase {
    func testIndexSetFromStringSingleRange() throws {
        let indexSet = try IndexSet(fromString: "200-299")
        let expectedIndexSet = IndexSet(200...299)
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringSingleValue() throws {
        let indexSet = try IndexSet(fromString: "413")
        let expectedIndexSet = IndexSet(integer: 413)
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringMultipleRanges() throws {
        let indexSet = try IndexSet(fromString: "200-299,413,500-599")
        let expectedIndexSet = IndexSet(200...299).union(IndexSet(integer: 413)).union(IndexSet(500...599))
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringMultipleRangesWithSpaces() throws {
        let indexSet = try IndexSet(fromString: "  200-299, 413, 500-599  ")
        let expectedIndexSet = IndexSet(200...299).union(IndexSet(integer: 413)).union(IndexSet(500...599))
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringMultipleRangesWithEmptyValues() throws {
        let indexSet = try IndexSet(fromString: "200-299,,413,500-599")
        let expectedIndexSet = IndexSet(200...299).union(IndexSet(integer: 413)).union(IndexSet(500...599))
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringSingleRangeWithEmptyValues() throws {
        let indexSet = try IndexSet(fromString: "200-200")
        let expectedIndexSet = IndexSet(integer: 200)
        XCTAssertEqual(indexSet, expectedIndexSet)
    }

    func testIndexSetFromStringReverseOrder() throws {
        XCTAssertThrowsError(try IndexSet(fromString: "299-200")) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }

    func testIndexSetFromStringInvalidInput() {
        XCTAssertThrowsError(try IndexSet(fromString: "invalid")) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }

    func testIndexSetFromStringEmptyInput() throws {
        XCTAssertThrowsError(try IndexSet(fromString: "")) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }

    func testIndexSetFromStringSingleInvalidRange() {
        XCTAssertThrowsError(try IndexSet(fromString: "200-")) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }

    func testIndexSetFromStringInvalidRangeFormat() {
        XCTAssertThrowsError(try IndexSet(fromString: "200-299-400")) { error in
            XCTAssertTrue(error is IndexSet.ParseError)
        }
    }
}
