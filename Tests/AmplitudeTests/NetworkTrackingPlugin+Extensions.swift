//
//  NetworkTrackingPlugin+Extensions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 9/11/25.
//

@testable import AmplitudeSwift
import XCTest

extension NetworkTrackingPlugin {

    func waitforNetworkTrackingQueue() {
        let waitForQueueExpectation = XCTestExpectation(description: "Wait for networkTrackingQueue")
        networkTrackingQueue.async(flags: .barrier) {
            waitForQueueExpectation.fulfill()
        }
        XCTWaiter().wait(for: [waitForQueueExpectation], timeout: 10)
    }
}

#if !os(watchOS)
/// Counts, per URL, the calls a listener gets from `NetworkSwizzler` for a task's transition to
/// `.completed`. The swizzler makes one such call per entry in its listener list, so for one
/// request the count is the listener's number of entries.
final class CompletedTaskRecorder {
    private let lock = NSLock()
    private var counts: [URL: Int] = [:]
    private var expectations: [URL: XCTestExpectation] = [:]

    func record(_ task: URLSessionTask, state: URLSessionTask.State) {
        // The swizzler calls listeners before the original setState:, so task.state is still
        // the old state. URLSession can call setState(.completed) again on a task that has
        // already completed; like NetworkTrackingPlugin, count only the transition.
        guard state == .completed, task.state != .completed, let url = task.originalRequest?.url else { return }
        let expectation: XCTestExpectation? = lock.withLock {
            counts[url, default: 0] += 1
            return expectations[url]
        }
        expectation?.fulfill()
    }

    func count(for url: URL) -> Int {
        lock.withLock { counts[url, default: 0] }
    }

    func expectation(forCompletionOf url: URL) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "\(url) completed")
        expectation.assertForOverFulfill = false
        lock.withLock { expectations[url] = expectation }
        return expectation
    }
}

final class RecordingNetworkTaskListener: NetworkTaskListener {
    let recorder = CompletedTaskRecorder()

    func onTaskResume(_ task: URLSessionTask) {}

    func onTask(_ task: URLSessionTask, setState state: URLSessionTask.State) {
        recorder.record(task, state: state)
    }

    func onDataTaskCompletion(_ task: URLSessionDataTask, data: Data?, response: URLResponse?, error: Error?) {}
}

/// A NetworkTrackingPlugin that also records its swizzler calls, whether or not it tracks them.
final class RecordingNetworkTrackingPlugin: NetworkTrackingPlugin {
    let recorder = CompletedTaskRecorder()

    override func onTask(_ task: URLSessionTask, setState state: URLSessionTask.State) {
        recorder.record(task, state: state)
        super.onTask(task, setState: state)
    }
}

extension XCTestCase {

    /// Sends one request to `url` and returns once every NetworkSwizzler entry added before this
    /// call has been told it completed. The listener added here is last in the swizzler's list,
    /// and the swizzler calls its entries in order within one `setState:` call, so when that
    /// listener sees the completion, every earlier entry already has (and any event the plugin
    /// tracks for it is already queued).
    func sendRequestAndWaitForSwizzlerListeners(_ url: URL, session: URLSession) {
        let last = RecordingNetworkTaskListener()
        NetworkSwizzler.shared.addListener(last)
        defer { NetworkSwizzler.shared.removeListener(last) }

        let completed = last.recorder.expectation(forCompletionOf: url)
        session.dataTask(with: url).resume()
        wait(for: [completed], timeout: 30)
    }

    /// The number of entries `plugin` has in NetworkSwizzler, measured with one request to a
    /// unique URL. FakeURLProtocol answers it, or fails it when nothing is queued; either way
    /// the task completes.
    func swizzlerEntries(of plugin: RecordingNetworkTrackingPlugin) -> Int {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let url = URL(string: "https://swizzler-entries.example.com/\(UUID().uuidString)")!
        sendRequestAndWaitForSwizzlerListeners(url, session: session)
        return plugin.recorder.count(for: url)
    }
}
#endif
