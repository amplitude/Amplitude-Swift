//
//  RemoteConfigMockServer.swift
//  Amplitude-Swift
//

import AmplitudeCore
@testable import AmplitudeSwift
import Foundation
import ObjectiveC
import XCTest

/// Process-wide, in-memory stand-in for the remote-config and diagnostics endpoints.
///
/// Installed once per test process by `TestBundlePrincipal`, it answers every
/// `https://sr-client-cfg.*` and `https://diagnostics.prod.*` request made from a
/// `URLSession` built on `URLSessionConfiguration.ephemeral` -- which is what
/// `RemoteConfigClient` and `DiagnosticsClient` use -- so no test reaches the real
/// services. `Configuration.init` constructs both clients unconditionally, so without
/// this every `Configuration(...)` in the bundle (about a hundred) started a real
/// HTTPS fetch with a made-up API key, got a 4xx, and retried with backoff in the
/// background while later tests ran.
///
/// Two behaviours, keyed on the API key in the request path:
///
/// - Keys with `testApiKeyPrefix` (see `RemoteConfigClient.setNextFetchedRemoteConfig`):
///   serve the config the test queued, but **hold the response until the test calls
///   `release(apiKey:)`**. That gives a test a point at which the remote config
///   provably has not arrived (assert defaults there) and a point after which it is on
///   its way -- with no wall-clock delay to lose a race against. The previous mock
///   answered after a fixed 500 ms, which the CI runners regularly beat.
/// - Any other key: `200 {"configs":{}}` immediately. Subscribers see the same `nil`
///   they saw when the real fetch failed; nothing else in the bundle observes remote
///   config.
enum RemoteConfigMockServer {

    static let testApiKeyPrefix = "remote-config-test-"

    private struct Entry {
        var queued: [RemoteConfigClient.RemoteConfig] = []
        var released = false
        var waiting: [RemoteConfigUrlProtocol] = []
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]
    private static var installed = false

    /// Puts `RemoteConfigUrlProtocol` in front of every `URLSession` created from
    /// `URLSessionConfiguration.ephemeral` from now on. Idempotent: swizzling with
    /// `method_exchangeImplementations` toggles, so a second call must be a no-op.
    static func install() {
        lock.withLock {
            guard !installed else { return }
            installed = true

            let metaClass: AnyClass = object_getClass(URLSessionConfiguration.self)!
            guard let original = class_getClassMethod(metaClass, #selector(getter: URLSessionConfiguration.ephemeral)),
                  let swizzled = class_getClassMethod(metaClass, #selector(URLSessionConfiguration.amp_ephemeral)) else {
                preconditionFailure("RemoteConfigMockServer: could not swizzle URLSessionConfiguration.ephemeral")
            }
            method_exchangeImplementations(original, swizzled)
        }
    }

    /// Queue `config` as the next response for `apiKey`, held until `release(apiKey:)`.
    static func enqueue(_ config: RemoteConfigClient.RemoteConfig, apiKey: String) {
        lock.withLock {
            var entry = entries[apiKey] ?? Entry()
            entry.queued.append(config)
            entry.released = false
            entries[apiKey] = entry
        }
    }

    /// Let the queued response for `apiKey` go out. Safe to call before the SDK has
    /// started the request: the response is delivered as soon as it does.
    static func release(apiKey: String) {
        let toDeliver: [RemoteConfigUrlProtocol] = lock.withLock {
            var entry = entries[apiKey] ?? Entry()
            entry.released = true
            let waiting = entry.waiting
            entry.waiting = []
            entries[apiKey] = entry
            return waiting
        }
        toDeliver.forEach { $0.deliver() }
    }

    /// Called from `startLoading`. Non-test keys and released test keys deliver at
    /// once; unreleased test keys park the protocol until `release(apiKey:)`.
    fileprivate static func handle(_ urlProtocol: RemoteConfigUrlProtocol, apiKey: String) {
        let deliverNow: Bool = lock.withLock {
            guard apiKey.hasPrefix(testApiKeyPrefix) else {
                return true
            }
            var entry = entries[apiKey] ?? Entry()
            if entry.released {
                return true
            }
            entry.waiting.append(urlProtocol)
            entries[apiKey] = entry
            return false
        }
        if deliverNow {
            urlProtocol.deliver()
        }
    }

    /// The config to serve, consumed at delivery time rather than at `startLoading`
    /// so that a request retried before delivery still finds it. Non-test keys get an
    /// empty config; a test key with nothing queued gets nil (a test-setup error).
    fileprivate static func dequeue(apiKey: String) -> RemoteConfigClient.RemoteConfig? {
        lock.withLock {
            guard apiKey.hasPrefix(testApiKeyPrefix) else {
                return [:]
            }
            guard var entry = entries[apiKey], !entry.queued.isEmpty else {
                return nil
            }
            let config = entry.queued.removeFirst()
            entries[apiKey] = entry
            return config
        }
    }
}

/// Serves `RemoteConfigMockServer`'s responses. Consulted first by every ephemeral
/// session once `RemoteConfigMockServer.install()` has run; declines everything that
/// is not a remote-config or diagnostics request, so other protocols (`FakeURLProtocol`)
/// and the network are unaffected.
final class RemoteConfigUrlProtocol: URLProtocol {

    private static let remoteConfigPrefix = "https://sr-client-cfg."
    private static let diagnosticsPrefix = "https://diagnostics.prod."

    // Deliveries hop through a queue so the URL loading system is never re-entered
    // from inside startLoading, and so a delivery from the test thread (release) and
    // one from the loading thread (immediate) never interleave.
    private static let deliveryQueue = DispatchQueue(label: "com.amplitude.tests.RemoteConfigUrlProtocol")

    private var stopped = false

    override static func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else {
            return false
        }
        return url.hasPrefix(remoteConfigPrefix) || url.hasPrefix(diagnosticsPrefix)
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    private var isRemoteConfig: Bool {
        request.url?.absoluteString.hasPrefix(Self.remoteConfigPrefix) ?? false
    }

    // https://sr-client-cfg.amplitude.com/config/{apiKey}?config_keys=...
    // pathComponents already excludes the query.
    private var apiKey: String? {
        request.url?.pathComponents.last
    }

    override func startLoading() {
        guard isRemoteConfig, let apiKey else {
            deliver()
            return
        }
        RemoteConfigMockServer.handle(self, apiKey: apiKey)
    }

    override func stopLoading() {
        Self.deliveryQueue.async { [self] in
            stopped = true
        }
    }

    fileprivate func deliver() {
        Self.deliveryQueue.async { [self] in
            guard !stopped, let url = request.url else {
                return
            }

            let body: [String: Any]
            if isRemoteConfig {
                guard let config = RemoteConfigMockServer.dequeue(apiKey: apiKey ?? "") else {
                    client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
                    return
                }
                body = ["configs": config]
            } else {
                body = [:]
            }

            let response = HTTPURLResponse(url: url,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

extension URLSessionConfiguration {

    // Swizzled with `ephemeral`, so calling amp_ephemeral here runs the original.
    @objc class func amp_ephemeral() -> URLSessionConfiguration {
        let config = amp_ephemeral()
        config.protocolClasses = [RemoteConfigUrlProtocol.self] + (config.protocolClasses ?? [])
        return config
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

/// Named as `NSPrincipalClass` in `Amplitude_SwiftTests_Info.plist`. XCTest instantiates
/// it once, before any test class is loaded -- the only point early enough to put a
/// URLProtocol in front of the sessions that `Configuration.init` creates.
@objc(AMPTestBundlePrincipal)
final class TestBundlePrincipal: NSObject {

    override init() {
        super.init()
        RemoteConfigMockServer.install()
    }
}
