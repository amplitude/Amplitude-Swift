//
//  NetworkTrackingPluginTest.swift
//  Amplitude-SwiftTests
//
//  Created by Jin Xu on 4/10/25.
//

import XCTest

@testable import AmplitudeSwift

// swiftlint:disable force_cast
final class NetworkTrackingPluginTest: XCTestCase {

    private var amplitude: Amplitude!
    private var storageMem: FakeInMemoryStorage!
    private var eventCollector = EventCollectorPlugin()

    static override func setUp() {
        super.setUp()
        URLSessionConfiguration.enableMockDefault()
    }

    static override func tearDown() {
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
    }

    func setupAmplitude(with options: NetworkTrackingOptions = NetworkTrackingOptions.default) {
        let configuration = Configuration(apiKey: "test-api-key",
                                          storageProvider: storageMem,
                                          flushMaxRetries: 0,
                                          autocapture: .networkTracking,
                                          networkTrackingOptions: options)
        amplitude = Amplitude(configuration: configuration)
        amplitude.add(plugin: eventCollector)
    }

    func taskForRequest(_ url: String = "https://example.com",
                        method: String = "GET",
                        requestBody: Data? = nil,
                        timeout: TimeInterval = 2,
                        _ completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.httpBody = requestBody

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.protocolClasses = [FakeURLProtocol.self]
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return session.dataTask(with: request, completionHandler: completionHandler)
    }

    @discardableResult
    func request(_ url: String = "https://example.com",
                 method: String = "GET") async throws -> (Data, URLResponse) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeURLProtocol.self]
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return try await session.data(for: request)
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

        wait() // Wait for Autocapture works
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
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_DURATION_PROPERTY] as! Int64 > 0)
    }

    func testDefaultNetworkTrackingOptionsShouldNotCapture200() {
        setupAmplitude()
        FakeURLProtocol.mockResponses = [.init(statusCode: 200)]

        let expectation = XCTestExpectation(description: "Network request finished")
        taskForRequest { _, _, _ in
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 2)

        amplitude.waitForTrackingQueue()
        wait()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 0, "Should not capture network request event with status code 200")
    }

    func testDefaultNetworkTrackingOptionsShouldNotCaptureAmplitude() {
        setupAmplitude()

        FakeURLProtocol.mockResponses = [.init(statusCode: 500)]

        amplitude.track(eventType: "Test")
        amplitude.flush()

        amplitude.waitForTrackingQueue()
        wait()

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

        amplitude.waitForTrackingQueue()
        wait()

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
        let events = eventCollector.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, "https://example.com")
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] as! Int64, 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_START_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_COMPLETION_TIME_PROPERTY] as! Int64 > 0)
        XCTAssertTrue(event.eventProperties?[Constants.AMP_NETWORK_DURATION_PROPERTY] as! Int64 > 0)
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

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeURLProtocol.self]
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        session.uploadTask(with: request, from: requestBodyData, completionHandler: { _, _, _ in
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

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeURLProtocol.self]
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        session.downloadTask(with: request, completionHandler: { _, _, _ in
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

        let plugin = amplitude.timeline.plugins[PluginType.utility]?.plugins.first {
            $0 is NetworkTrackingPlugin
        } as! NetworkTrackingPlugin

        let rule = plugin.ruleForHost("api.example.com")
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule!.statusCodeIndexSet, IndexSet(400...499))

        let rule2 = plugin.ruleForHost("api2.example.com")
        XCTAssertNotNil(rule2)
        XCTAssertEqual(rule2!.statusCodeIndexSet,
                       IndexSet(integer: 0).union(IndexSet(500...599)))

        let rule3 = plugin.ruleForHost("example.com")
        XCTAssertNil(rule3)

        FakeURLProtocol.mockResponses = [.init(statusCode: 400), .init(statusCode: 500), .init(statusCode: 500, delay: 0.1)]

        let url = ["https://api.example.com", "https://api.example.com", "https://api2.example.com"]
        let expectations = (0..<3).map { _ in XCTestExpectation(description: "Network request finished") }
        taskForRequest(url[0]) { _, _, _ in
            expectations[0].fulfill()
        }.resume()
        taskForRequest(url[1]) { _, _, _ in
            expectations[1].fulfill()
        }.resume()
        taskForRequest(url[2]) { _, _, _ in
            expectations[2].fulfill()
        }.resume()
        wait(for: expectations, timeout: 2)

        wait()
        amplitude.waitForTrackingQueue()

        let events = eventCollector.events
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events[0] is NetworkRequestEvent)
        XCTAssertTrue(events[1] is NetworkRequestEvent)
        let event = events[0] as! NetworkRequestEvent
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, url[0])
        XCTAssertEqual(event.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 400)
        let event2 = events[1] as! NetworkRequestEvent
        XCTAssertEqual(event2.eventProperties?[Constants.AMP_NETWORK_URL_PROPERTY] as! String, url[2])
        XCTAssertEqual(event2.eventProperties?[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] as! Int, 500)
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
        XCTAssertEqual(internalOptions.captureRules[0].hosts.hostPatterns.count, 1)
        XCTAssertEqual(internalOptions.captureRules[0].hosts.hostPatterns,
                       [try! NSRegularExpression(pattern: "^.*\\.example\\.com:8080$", options: [.caseInsensitive])])
        XCTAssertTrue(internalOptions.captureRules[0].hosts.matches("api.example.com:8080"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts.matches("api.example.com"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts.matches("api.example.com:8081"))
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
        XCTAssertEqual(internalOptions.captureRules[0].hosts.hostSet.count, 1)
        XCTAssertEqual(internalOptions.captureRules[0].hosts.hostSet, ["api.example.com"])
        XCTAssertEqual(internalOptions.captureRules[0].hosts.hostPatterns.count, 0)
        XCTAssertEqual(internalOptions.captureRules[1].statusCodeIndexSet, IndexSet(500...599))
        XCTAssertEqual(internalOptions.captureRules[1].hosts.hostSet.count, 0)
        XCTAssertEqual(internalOptions.captureRules[1].hosts.hostPatterns.count, 1)
        XCTAssertEqual(internalOptions.captureRules[1].hosts.hostPatterns,
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
        XCTAssertTrue(internalOptions.captureRules[0].hosts.matches("api.example.com"))
        XCTAssertFalse(internalOptions.captureRules[0].hosts.matches("example.com"))
        XCTAssertTrue(internalOptions.captureRules[1].hosts.matches("sub.test.com"))
        XCTAssertTrue(internalOptions.captureRules[1].hosts.matches("another.sub.test.com"))
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
