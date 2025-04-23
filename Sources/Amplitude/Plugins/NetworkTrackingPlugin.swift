//
//  NetworkTrackingPlugin.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 3/17/25.
//

import Foundation
import ObjectiveC

public struct NetworkTrackingOptions {
    public struct CaptureRule {
        public var hosts: [String]
        public var statusCodeRange: String

        public init(hosts: [String], statusCodeRange: String = "500-599") {
            self.hosts = hosts
            self.statusCodeRange = statusCodeRange
        }
    }

    public var captureRules: [CaptureRule]
    public var ignoreHosts: [String]
    public var ignoreAmplitudeRequests: Bool

    public init(captureRules: [CaptureRule], ignoreHosts: [String] = [], ignoreAmplitudeRequests: Bool = true) {
        self.captureRules = captureRules
        self.ignoreHosts = ignoreHosts
        self.ignoreAmplitudeRequests = ignoreAmplitudeRequests
    }

    public static func defaultOptions() -> NetworkTrackingOptions {
        return NetworkTrackingOptions(captureRules: [CaptureRule(hosts: ["*"])])
    }
}

class NetworkTrackingPlugin: UtilityPlugin, NetworkTaskListener {

    var options: CompiledNetworkTrackingOptions?
    var ruleCache: [String: CompiledNetworkTrackingOptions.CaptureRule?] = [:]
    var optOut = true

    private let ruleCacheLock: NSLock = NSLock()

    var logger: (any Logger)? {
        amplitude?.logger
    }

    override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)

#if os(watchOS)
        logger?.warn(message: "NetworkTrackingPlugin is not supported on watchOS yet.")
        optOut = true
#else
        let originalOptions = amplitude.configuration.networkTrackingOptions

        do {
            options = try CompiledNetworkTrackingOptions(options: originalOptions)
            NetworkSwizzler.shared.addListener(listener: self)
            optOut = false
        } catch {
            logger?.error(message: "NetworkTrackingPlugin: Failed to parse options: \(originalOptions), error: \(error.localizedDescription)")
            optOut = true
        }
#endif
    }

    override func teardown() {
        super.teardown()

        NetworkSwizzler.shared.removeListener(listener: self)
    }

    func ruleForHost(_ host: String) -> CompiledNetworkTrackingOptions.CaptureRule? {
        guard let options = options else { return nil }

        ruleCacheLock.lock()
        defer { ruleCacheLock.unlock() }

        if let rule = ruleCache[host] {
            return rule
        }

        let rule: CompiledNetworkTrackingOptions.CaptureRule? = if options.ignoreHosts.matches(host) {
            nil
        } else {
            options.captureRules.last { rule in
                rule.hosts.matches(host)
            }
        }

        ruleCache[host] = rule
        return rule
    }

    func onTaskResume(_ task: URLSessionTask) {
        guard isListening(task),
              task.state != .completed,
              task.state != .canceling,
              let request = task.originalRequest,
              let url = request.url,
              let host = url.host,
              ruleForHost(host) != nil
        else { return }

        logger?.debug(message: "NetworkTrackingPlugin: onTaskResume(\(task)) for \(url)")

        task.requestTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
    }

    func onTask(_ task: URLSessionTask, setState state: URLSessionTask.State) {
        guard isListening(task),
              let request = task.originalRequest,
              let url: URL = request.url,
              let host = url.host,
              let rule = ruleForHost(host) else { return }

        logger?.debug(message: "NetworkTrackingPlugin: setState: \(state) for \(url)")

        let response = task.response as? HTTPURLResponse
        let statusCode = response?.statusCode ?? 0

        guard rule.statusCodeIndexSet.contains(statusCode) else { return }

        guard let method = request.httpMethod else { return }

        guard task.state == .running, state == .completed else { return }

        let responseTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)

        let event = NetworkRequestEvent(url: url,
                                        method: method,
                                        statusCode: response?.statusCode,
                                        error: task.error as? NSError,
                                        startTime: task.requestTimestamp,
                                        completionTime: responseTimestamp,
                                        requestBodySize: task.countOfBytesSent,
                                        responseBodySize: task.countOfBytesReceived)
        amplitude?.track(event: event)
    }

    func isListening(_ task: URLSessionTask) -> Bool {
        return !optOut &&
        (task is URLSessionDataTask || task is URLSessionUploadTask || task is URLSessionDownloadTask)
    }
}

// Key for associated object
private var sendTimeKey: UInt8 = 0

extension URLSessionTask {
    // Associate send time with URLSessionTask
    var requestTimestamp: Int64? {
        get {
            return objc_getAssociatedObject(self, &sendTimeKey) as? Int64
        }
        set {
            objc_setAssociatedObject(self, &sendTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

class CompiledNetworkTrackingOptions {

    class WildcardHosts {
        let hostSet: Set<String>
        let hostPatterns: [NSRegularExpression]

        init(hosts: [String]) throws {
            var hostPatterns: [NSRegularExpression] = []
            var hostSet: Set<String> = []
            for host in hosts {
                if host.contains("*") {
                    let regexPattern = host
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "*", with: ".*")
                    hostPatterns.append(try NSRegularExpression(pattern: "^" + regexPattern + "$",
                                                                options: [.caseInsensitive]))
                } else {
                    hostSet.insert(host)
                }
            }
            self.hostPatterns = hostPatterns
            self.hostSet = hostSet
        }

        func matches(_ host: String) -> Bool {
            return hostSet.contains(host) || hostPatterns.contains { regex in
                regex.firstMatch(in: host, range: NSRange(location: 0, length: host.utf16.count)) != nil
            }
        }
    }

    class CaptureRule {
        let hosts: WildcardHosts
        let statusCodeIndexSet: IndexSet

        init(hosts: [String], statusCodeRange: String) throws {
            self.hosts = try WildcardHosts(hosts: hosts)
            self.statusCodeIndexSet = try IndexSet(fromString: statusCodeRange)
        }
    }

    let captureRules: [CaptureRule]
    let ignoreHosts: WildcardHosts

    init(options: NetworkTrackingOptions) throws {
        self.captureRules = try options.captureRules.map { try CaptureRule(hosts: $0.hosts, statusCodeRange: $0.statusCodeRange) }

        var ignoreHosts = options.ignoreHosts
        if options.ignoreAmplitudeRequests {
            ignoreHosts.append("*.amplitude.com")
        }
        self.ignoreHosts = try WildcardHosts(hosts: ignoreHosts)
    }
}

extension IndexSet {
    enum ParseError: Error { case invalidFormat }

    /// Creates an `IndexSet` from a string like `"0,200-299,413,500-599"`.
    ///
    /// Accepts:
    /// * 0 -> local errors
    /// * single integers  → `413`
    /// * closed ranges    → `200-299`
    /// * mixed, comma‑separated, with optional spaces
    ///
    /// Throws `ParseError.invalidFormat` if **anything** is malformed.
    init(fromString string: String) throws {
        self.init()

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        for rawPart in trimmed.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            guard !part.isEmpty else { throw ParseError.invalidFormat }

            if let dash = part.firstIndex(of: "-") {
                let loSub = part[..<dash]
                let hiSub = part[part.index(after: dash)...]

                guard let lo = Int(loSub),
                      let hi = Int(hiSub),
                      lo <= hi
                else { throw ParseError.invalidFormat }

                self.insert(integersIn: lo...hi)
            } else {
                guard let value = Int(part) else {
                    throw ParseError.invalidFormat
                }
                self.insert(value)
            }
        }

        if self.isEmpty {
            throw ParseError.invalidFormat
        }
    }
}
