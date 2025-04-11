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

        init(statusCode: Int = 200, data: Data? = nil, error: Error? = nil, delay: TimeInterval = 0.01) {
            self.statusCode = statusCode
            self.data = data
            self.error = error
            self.delay = delay
        }
    }

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        return true
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

        let mockResponse = Self.mockResponses.removeFirst()

        let response = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
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
