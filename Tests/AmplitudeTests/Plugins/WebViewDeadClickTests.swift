//
//  WebViewDeadClickTests.swift
//  Amplitude-Swift
//
//  Dead click detection cannot work inside a `WKWebView`. Session Replay's `Snapshotter` never walks
//  into a web view's layer subtree (`captureChildren = false`, regardless of block status), and
//  `InterfaceChangeSignal` carries only a timestamp — no region. So a tap on web content produces no
//  signal about whether the page responded: it is reported dead whenever nothing else in the app
//  happens to change within the 3.5 s timeout, and cleared whenever something unrelated does.
//
//  Rage click does not depend on interface signals, so it stays enabled inside web views.
//

import XCTest

@testable import AmplitudeSwift

// WebKit does not exist in the tvOS and watchOS SDKs, so the import has to sit inside the guard.
#if os(iOS)
import WebKit
import UIKit.UIGestureRecognizerSubclass
@_spi(Internal) import AmplitudeCore

final class WebViewDeadClickTests: XCTestCase {

    private var window: UIWindow!
    /// `WKWebView.navigationDelegate` is weak; the delegate must outlive the navigation.
    private var navigationDelegate: NavigationDelegate?

    override func setUp() {
        super.setUp()
        UIKitElementInteractions.resetPhysicalTapDedupCandidates()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
    }

    override func tearDown() {
        UIKitElementInteractions.resetPhysicalTapDedupCandidates()
        navigationDelegate = nil
        window = nil
        super.tearDown()
    }

    // MARK: - What a web view looks like to the SDK

    /// Replicates the SDK's gate in `UIGestureRecognizer.amp_setState`.
    private func qualifiesAsPhysicalTap(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let tap = recognizer as? UITapGestureRecognizer else { return false }
        return tap.numberOfTapsRequired == 1 && tap.numberOfTouchesRequired == 1
    }

    private func allRecognizers(in root: UIView) -> [(view: UIView, recognizer: UIGestureRecognizer)] {
        var result: [(UIView, UIGestureRecognizer)] = []
        for recognizer in root.gestureRecognizers ?? [] {
            result.append((root, recognizer))
        }
        for subview in root.subviews {
            result.append(contentsOf: allRecognizers(in: subview))
        }
        return result
    }

    /// WebKit installs several single-tap recognizers on the same `WKContentView`, all of which pass
    /// the SDK's physical-tap gate. Measured with a real touch, two of them fire per tap
    /// (`WKSyntheticTapGestureRecognizer` then `UITextTapRecognizer`, under a millisecond apart).
    func testWebKitInstallsMultipleQualifyingTapRecognizersOnSameView() throws {
        let webView = try loadedWebView(
            "<html><body style='font-size:64px'><p>tap here</p>"
            + "<div id='btn' onclick='void 0'>BUTTON</div></body></html>")

        // Give WebKit a beat to install its text/selection interactions.
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let qualifying = allRecognizers(in: webView).filter { qualifiesAsPhysicalTap($0.recognizer) }
        print("=== recognizers the SDK would treat as a physical tap: \(qualifying.count) ===")
        for (view, recognizer) in qualifying {
            print(" - \(recognizer.descriptiveTypeName) on \(view.descriptiveTypeName)")
        }

        XCTAssertGreaterThan(qualifying.count, 1,
                             "Expected WebKit to install more than one single-tap recognizer")
    }

    // MARK: - Dead click is suppressed inside web views

    func testDeadClickSuppressedInsideWebViewWhileRageClickStaysOn() throws {
        let webView = try loadedWebView("<html><body style='font-size:64px'><p>tap here</p></body></html>")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        XCTAssertTrue(webView.amp_isInsideWebView, "The web view itself counts as web content")
        XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: webView))
        XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: webView))

        let qualifying = allRecognizers(in: webView).filter { qualifiesAsPhysicalTap($0.recognizer) }
        XCTAssertFalse(qualifying.isEmpty)

        for (view, recognizer) in qualifying {
            XCTAssertTrue(view.amp_isInsideWebView,
                          "\(recognizer.descriptiveTypeName) on \(view.descriptiveTypeName) is web content")
            XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: view),
                           "dead click must be off for \(view.descriptiveTypeName)")
            XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: view),
                          "rage click must stay on for \(view.descriptiveTypeName)")
        }
    }

    func testDeadClickStaysEnabledOutsideWebViews() {
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        let nested = UIView()
        container.addSubview(nested)

        for view in [container, nested] {
            XCTAssertFalse(view.amp_isInsideWebView)
            XCTAssertTrue(UIKitElementInteractions.shouldProcessDeadClick(for: view))
            XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: view))
        }
    }

    /// Apps routinely subclass `WKWebView`, so the check has to be class-kind, not class-name.
    func testWebViewSubclassIsRecognisedAsWebContent() {
        final class CustomWebView: WKWebView {}

        let webView = CustomWebView(frame: window.bounds)
        window.addSubview(webView)
        let nested = UIView()
        webView.addSubview(nested)

        XCTAssertTrue(webView.amp_isInsideWebView)
        XCTAssertTrue(nested.amp_isInsideWebView)
        XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: nested))
        XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: nested))
    }

    /// A view detached from any web view must not be suppressed just because it once was inside one.
    func testDetachedViewIsNotTreatedAsWebContent() {
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        let nested = UIView()
        webView.addSubview(nested)
        XCTAssertTrue(nested.amp_isInsideWebView)

        nested.removeFromSuperview()
        XCTAssertFalse(nested.amp_isInsideWebView)
        XCTAssertTrue(UIKitElementInteractions.shouldProcessDeadClick(for: nested))
    }

    /// The explicit opt-out keeps working for both detectors outside web views.
    func testExplicitIgnoreStillSuppressesBothDetectors() {
        let view = UIView(frame: window.bounds)
        window.addSubview(view)

        view.amp_ignoreInteractionEvent(rageClick: true, deadClick: true)
        XCTAssertFalse(UIKitElementInteractions.shouldProcessRageClick(for: view))
        XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: view))
    }

    // MARK: - End-to-end wiring through the swizzled gesture path

    /// The suppression only exists if the call sites in `amp_setState` actually consult
    /// `shouldProcessDeadClick` — every other test in this file calls the helpers directly and
    /// would stay green if the wiring were reverted. This one drives the real swizzled setter.
    ///
    /// Slow by necessity: a dead click is only reported 3.5 s after the tap, and the test needs a
    /// negative (web view) and a positive control (plain view) to prove the detector was live.
    func testGesturePathEmitsNoDeadClickInsideWebViewButStillDetectsRageClicks() throws {
        let (amplitude, collector) = makeAmplitude()
        defer { UIKitElementInteractions.unregister(amplitude) }

        let provider = FakeInterfaceSignalProvider()
        amplitude.interfaceSignalProvider = provider
        defer { amplitude.interfaceSignalProvider = nil }

        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        let nestedInWebView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        webView.addSubview(nestedInWebView)

        let plainView = UIView(frame: CGRect(x: 0, y: 300, width: 100, height: 100))
        window.addSubview(plainView)
        window.makeKeyAndVisible()
        amplitude.waitForTrackingQueue()

        // Four rapid taps inside the web view: rage click must still fire, dead click must not,
        // even though no interface change signal ever arrives.
        for _ in 0..<4 {
            fireTap(on: nestedInWebView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        // Past the rage debounce (1 s) and the dead click timeout (3.5 s).
        RunLoop.current.run(until: Date().addingTimeInterval(4.2))
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_RAGE_CLICK_EVENT).count, 1,
                       "Rage click stays enabled inside the web view")
        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_DEAD_CLICK_EVENT).count, 0,
                       "No dead click may be reported for web content")

        // Positive control: the same tap on a plain view IS reported dead, proving the detector
        // and provider wiring in this test are live.
        fireTap(on: plainView)
        RunLoop.current.run(until: Date().addingTimeInterval(4.2))
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_DEAD_CLICK_EVENT).count, 1,
                       "The positive control must produce a dead click")
    }

    // MARK: - Known gap: the public ignore hook does not reach a webview's recognizer view

    /// `amp_ignoreRageClick` / `amp_ignoreDeadClick` read an associated object on *that view only*.
    /// Inside a `WKWebView` the recognizers belong to `WKContentView`, two levels below the
    /// `WKWebView` an app can actually reach, so the documented workaround
    /// `webView.amp_ignoreInteractionEvent(...)` never reaches the view the SDK checks.
    /// This test pins the current behaviour; it should be inverted when the lookup walks ancestors.
    func testIgnoreHookOnWebViewDoesNotReachTheRecognizerView() throws {
        let webView = try loadedWebView("<html><body style='font-size:64px'><p>tap here</p></body></html>")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        webView.amp_ignoreInteractionEvent(rageClick: true, deadClick: true)
        XCTAssertTrue(webView.amp_ignoreDeadClick, "The flag is set on the WKWebView itself")

        let qualifying = allRecognizers(in: webView).filter { qualifiesAsPhysicalTap($0.recognizer) }
        XCTAssertFalse(qualifying.isEmpty)

        for (view, recognizer) in qualifying {
            let chain = sequence(first: view, next: \.superview).map { $0.descriptiveTypeName }
                .joined(separator: " -> ")
            print("=== \(recognizer.descriptiveTypeName): \(chain)")

            XCTAssertFalse(view.amp_ignoreDeadClick,
                           "Known gap: the flag set on WKWebView does not reach \(view.descriptiveTypeName)")
            XCTAssertFalse(view.amp_ignoreRageClick,
                           "Known gap: the flag set on WKWebView does not reach \(view.descriptiveTypeName)")
        }
    }

    // MARK: - Helpers

    /// Real recognizers report a centroid only while they hold touches; without them the location
    /// is unusable garbage, so the test recognizer pins it.
    private final class FixedLocationTapRecognizer: UITapGestureRecognizer {
        var fixedLocation: CGPoint = .zero
        override func location(in view: UIView?) -> CGPoint { fixedLocation }
        /// Runs the swizzled `setState:` the way UIKit does when a tap completes.
        func fireEnded() { state = .ended }
    }

    private final class FakeInterfaceSignalProvider: InterfaceSignalProvider {
        var isProviding: Bool = true
        func addInterfaceSignalReceiver(_ receiver: any InterfaceSignalReceiver) {}
        func removeInterfaceSignalReceiver(_ receiver: any InterfaceSignalReceiver) {}
    }

    private func fireTap(on view: UIView, at location: CGPoint = CGPoint(x: 50, y: 50)) {
        let recognizer = FixedLocationTapRecognizer()
        recognizer.fixedLocation = location
        view.addGestureRecognizer(recognizer)
        recognizer.fireEnded()
        view.removeGestureRecognizer(recognizer)
    }

    private func events(in collector: EventCollectorPlugin, ofType eventType: String) -> [BaseEvent] {
        return collector.events.filter { $0.eventType == eventType }
    }

    private func makeAmplitude() -> (Amplitude, EventCollectorPlugin) {
        let configuration = Configuration(
            apiKey: "test-api-key",
            instanceName: "webview-dead-click-\(UUID().uuidString)",
            storageProvider: FakeInMemoryStorage(),
            identifyStorageProvider: FakeInMemoryStorage(),
            autocapture: [.frustrationInteractions],
            enableAutoCaptureRemoteConfig: false,
            interactionsOptions: InteractionsOptions(rageClick: .init(enabled: true),
                                                     deadClick: .init(enabled: true)))
        let amplitude = Amplitude(configuration: configuration)
        let collector = EventCollectorPlugin()
        amplitude.add(plugin: collector)
        return (amplitude, collector)
    }

    private func loadedWebView(_ html: String) throws -> WKWebView {
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        window.makeKeyAndVisible()

        let loaded = expectation(description: "html loaded")
        let delegate = NavigationDelegate { loaded.fulfill() }
        navigationDelegate = delegate
        webView.navigationDelegate = delegate
        webView.loadHTMLString(html, baseURL: nil)
        wait(for: [loaded], timeout: 10)
        return webView
    }

    private final class NavigationDelegate: NSObject, WKNavigationDelegate {
        private let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinish()
        }
    }
}

#endif
