//
//  FakeURLProtocol.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 4/10/25.
//

import Foundation

class FakeURLProtocol: URLProtocol {
    static var mockResponses: [MockResponse] = []

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

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "FakeURLProtocol", code: -1, userInfo: nil))
            return
        }

        print("FakeURLProtocol: Starting to load \(url)")

        guard !Self.mockResponses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "FakeURLProtocol", code: -2, userInfo: [NSLocalizedDescriptionKey: "No mock responses available"]))
            return
        }

        let mockResponse = Self.mockResponses.removeFirst()

        let response = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockResponse.headers ?? ["Content-Type": "application/json"]
        )!

        let delay = mockResponse.delay

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = mockResponse.data {
                self.client?.urlProtocol(self, didLoad: data)
            }

            if let error = mockResponse.error {
                self.client?.urlProtocol(self, didFailWithError: error)
            }

            self.client?.urlProtocolDidFinishLoading(self)

            print("FakeURLProtocol: Finished loading \(url)")
        }
    }

    override func stopLoading() {
        // Nothing to do here
    }

    static func clearMockResponses() {
        mockResponses.removeAll()
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
