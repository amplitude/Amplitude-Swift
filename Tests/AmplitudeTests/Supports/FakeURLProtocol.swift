//
//  FakeURLProtocol.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 4/10/25.
//

import Foundation

class FakeURLProtocol: URLProtocol {

    /// Scripted responses for the requests a test issues itself, consumed in order.
    static var mockResponses: [MockResponse] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mockResponses
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _mockResponses = newValue
        }
    }

    /// Scripted responses for the SDK's own uploads to api2 / api.eu.amplitude.com. Kept apart
    /// from `mockResponses` because those uploads are not under the current test's control: an
    /// Amplitude instance from an earlier test is still flushing while the next test runs, and
    /// with one shared queue such a stray upload consumed a response the next test had queued
    /// for its own request -- which then failed with "No mock responses available", carried
    /// no status code, matched no capture rule, and left the test one event short. Uploads get
    /// a plain 200 when nothing is queued here, and never touch `mockResponses`.
    static var amplitudeResponses: [MockResponse] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _amplitudeResponses
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _amplitudeResponses = newValue
        }
    }

    /// Called, off the main thread, once a response to an SDK upload has been fully delivered.
    /// A test that asserts its upload was *not* captured has to wait for this first: until the
    /// request has completed, "no network event yet" proves nothing.
    static var onAmplitudeRequestFinished: ((URL) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onAmplitudeRequestFinished
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onAmplitudeRequestFinished = newValue
        }
    }

    private static let amplitudeHosts: Set<String> = ["api2.amplitude.com", "api.eu.amplitude.com"]
    private static let defaultAmplitudeResponse = MockResponse(statusCode: 200)

    // startLoading runs on the URL loading system's threads, one per in-flight request, and a
    // test with three parallel requests reaches the queue from three of them at once.
    private static let lock = NSLock()
    private static var _mockResponses: [MockResponse] = []
    private static var _amplitudeResponses: [MockResponse] = []
    private static var _onAmplitudeRequestFinished: ((URL) -> Void)?

    private static let responseQueue = DispatchQueue(label: "FakeURLProtocol.responseQueue")

    struct MockResponse {
        let statusCode: Int
        let data: Data?
        let error: Error?
        let delay: TimeInterval
        let headers: [String: String]?

        init(statusCode: Int = 200,
             data: Data? = nil,
             error: Error? = nil,
             delay: TimeInterval = 0.01,
             headers: [String: String]? = nil) {
            self.statusCode = statusCode
            self.data = data
            self.error = error
            self.delay = delay
            self.headers = headers
        }
    }

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        let isRemoteConfig = request.url?.absoluteString.hasPrefix("https://sr-client-cfg.") ?? false
        return !isRemoteConfig
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Pops the next response for `url` under the lock; nil when a test request has nothing queued.
    private static func dequeueResponse(for url: URL) -> MockResponse? {
        lock.lock()
        defer { lock.unlock() }
        if amplitudeHosts.contains(url.host ?? "") {
            return _amplitudeResponses.isEmpty ? defaultAmplitudeResponse : _amplitudeResponses.removeFirst()
        }
        return _mockResponses.isEmpty ? nil : _mockResponses.removeFirst()
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "FakeURLProtocol", code: -1, userInfo: nil))
            return
        }

        print("FakeURLProtocol: Starting to load \(url)")

        guard let mockResponse = Self.dequeueResponse(for: url) else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "FakeURLProtocol", code: -2, userInfo: [NSLocalizedDescriptionKey: "No mock responses available"]))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockResponse.headers ?? ["Content-Type": "application/json"]
        )!

        let delay = mockResponse.delay

        Self.responseQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = mockResponse.data {
                self.client?.urlProtocol(self, didLoad: data)
            }

            if let error = mockResponse.error {
                self.client?.urlProtocol(self, didFailWithError: error)
            }

            self.client?.urlProtocolDidFinishLoading(self)

            print("FakeURLProtocol: Finished loading \(url), response: \(mockResponse)")

            if Self.amplitudeHosts.contains(url.host ?? "") {
                Self.onAmplitudeRequestFinished?(url)
            }
        }
    }

    override func stopLoading() {
        // Nothing to do here
    }

    /// Call from tearDown: responses a test queued but never consumed would otherwise be served
    /// to the next test's requests, and its upload hook would fire for the next test's uploads.
    static func clearMockResponses() {
        lock.lock()
        defer { lock.unlock() }
        _mockResponses.removeAll()
        _amplitudeResponses.removeAll()
        _onAmplitudeRequestFinished = nil
    }
}

extension URLSessionConfiguration {

    static func enableMockDefault() {
        guard !_isSwizzled else { return }

        let metaClass: AnyClass = object_getClass(URLSessionConfiguration.self)!
        let originalSel = #selector(getter: URLSessionConfiguration.default)
        let swizzledSel = #selector(URLSessionConfiguration._mock_default)

        guard let original = class_getClassMethod(metaClass, originalSel),
              let swizzled = class_getClassMethod(metaClass, swizzledSel) else {
            preconditionFailure("Unable to locate methods for swizzling")
        }

        method_exchangeImplementations(original, swizzled)
        _original = original
        _swizzled = swizzled
        _isSwizzled = true
    }

    static func disableMockDefault() {
        guard _isSwizzled,
              let original = _original,
              let swizzled = _swizzled else { return }

        method_exchangeImplementations(swizzled, original)
        _original = nil
        _swizzled = nil
        _isSwizzled = false
    }

    private static var _isSwizzled = false
    private static var _original: Method?
    private static var _swizzled: Method?

    /// The swapped-in implementation.
    @objc class func _mock_default() -> URLSessionConfiguration {
        let cfg = _mock_default()
        cfg.protocolClasses = [FakeURLProtocol.self]
        return cfg
    }
}
