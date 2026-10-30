import AmplitudeCore
@testable import AmplitudeSwift
import Foundation
import XCTest

/// Injected SDK transport. Remote-config fixtures wait for an explicit release;
/// unrelated SDK requests succeed without reaching the network.
struct RemoteConfigMockServer: HttpClient {
    static let testApiKeyPrefix = "remote-config-test-"

    private struct Entry {
        var queued: [RemoteConfigClient.RemoteConfig] = []
        var released = false
        var waiting: [UUID: CheckedContinuation<Void, Error>] = [:]
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]

    static func enqueue(_ config: RemoteConfigClient.RemoteConfig, apiKey: String) {
        lock.withLock {
            var entry = entries[apiKey] ?? Entry()
            entry.queued.append(config)
            entry.released = false
            entries[apiKey] = entry
        }
    }

    static func release(apiKey: String) {
        let waiting = lock.withLock {
            var entry = entries[apiKey] ?? Entry()
            entry.released = true
            let waiting = Array(entry.waiting.values)
            entry.waiting.removeAll()
            entries[apiKey] = entry
            return waiting
        }
        waiting.forEach { $0.resume() }
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = try XCTUnwrap(request.url)
        var body: [String: Any] = [:]
        if url.host?.hasPrefix("sr-client-cfg.") == true {
            let apiKey = url.lastPathComponent
            if apiKey.hasPrefix(Self.testApiKeyPrefix) {
                let id = UUID()
                try await withTaskCancellationHandler(operation: {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        Self.lock.withLock {
                            if Task.isCancelled {
                                continuation.resume(throwing: CancellationError())
                            } else if Self.entries[apiKey]?.released == true {
                                continuation.resume()
                            } else {
                                Self.entries[apiKey, default: Entry()].waiting[id] = continuation
                            }
                        }
                    }
                }, onCancel: {
                    let waiting = Self.lock.withLock {
                        Self.entries[apiKey]?.waiting.removeValue(forKey: id)
                    }
                    waiting?.resume(throwing: CancellationError())
                })
                try Task.checkCancellation()
                let config = Self.lock.withLock { () -> RemoteConfigClient.RemoteConfig? in
                    guard Self.entries[apiKey]?.queued.isEmpty == false else { return nil }
                    return Self.entries[apiKey]?.queued.removeFirst()
                }
                body = ["configs": try XCTUnwrap(config, "No remote config queued for \(apiKey)")]
            } else {
                body = ["configs": [:]]
            }
        }
        return (try JSONSerialization.data(withJSONObject: body),
                try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
    }
}

extension RemoteConfigClient {

    static func setNextFetchedRemoteConfig(_ remoteConfig: RemoteConfig, forApiKey apiKey: String) {
        RemoteConfigMockServer.enqueue(remoteConfig, apiKey: apiKey)
    }

    static func resetStorage(instanceName: String) {
        let suiteName = "com.amplitude.remoteconfig.cache.\(instanceName)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

extension Amplitude {

    /// Fulfilled once a non-nil autocapture remote config has been applied to this
    /// instance's `AutocaptureManager` *and* handed to every plugin that registered an
    /// `onChange` callback before this call. `AutocaptureManager.handleRemoteConfig`
    /// updates its state, then runs the callbacks synchronously in registration order,
    /// so by the time this fires `NetworkTrackingPlugin` and the lifecycle monitor have
    /// consumed the config -- no sleep needed to "let other callbacks finish".
    ///
    /// Register after `init` (so the plugins are ahead of it) and before releasing the
    /// mock response.
    func remoteConfigAppliedExpectation() -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "autocapture remote config applied")
        expectation.assertForOverFulfill = false
        autocaptureManager.onChange { config in
            if config != nil {
                expectation.fulfill()
            }
        }
        return expectation
    }
}
