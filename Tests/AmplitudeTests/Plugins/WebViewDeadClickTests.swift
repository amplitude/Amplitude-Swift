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
    /// `Amplitude.interfaceSignalProvider` is weak; the provider must outlive the test body.
    private var interfaceSignalProvider: FakeInterfaceSignalProvider?

    override func setUp() {
        super.setUp()
        UIKitElementInteractions.resetPhysicalTapDedupCandidates()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
    }

    override func tearDown() {
        UIKitElementInteractions.resetPhysicalTapDedupCandidates()
        interfaceSignalProvider = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Finding the recognizers a tap on web content actually reaches
    //
    // WebKit installs five single-tap recognizers on the same `WKContentView`, all of which pass
    // the SDK's physical-tap gate. Measured with real touches on an iPhone 16 Pro Max, two of them
    // fire per tap — `WKSyntheticTapGestureRecognizer` and `UITextTapRecognizer`, in either order,
    // 0.10-2.64 ms apart. That is not asserted here: it is an Apple implementation detail that a
    // future iOS may change without any Amplitude regression.

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

    // MARK: - Dead click is suppressed inside web views

    func testDeadClickSuppressedInsideWebViewWhileRageClickStaysOn() throws {
        let webView = try attachedWebView()

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

        // `Amplitude.interfaceSignalProvider` is weak; without a strong reference here ARC may
        // release the provider immediately, `isProviding` goes nil, and the positive control fails
        // for a reason unrelated to the feature.
        let provider = FakeInterfaceSignalProvider()
        interfaceSignalProvider = provider
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
        let burstEnd = try fireRageClickBurst(on: nestedInWebView)

        // The rage click is reported by the detector's 1 s debounce timer: wait for the event, not
        // for a fixed time. Then stay past the dead click timeout (3.5 s after the tap) so a dead
        // click, had one been reported, would be in the collector as well.
        runLoop(until: collector, has: 1, ofType: Constants.AMP_RAGE_CLICK_EVENT)
        RunLoop.current.run(until: burstEnd.addingTimeInterval(4.2))
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_RAGE_CLICK_EVENT).count, 1,
                       "Rage click stays enabled inside the web view")
        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_DEAD_CLICK_EVENT).count, 0,
                       "No dead click may be reported for web content")

        // Positive control: the same tap on a plain view IS reported dead, proving the detector
        // and provider wiring in this test are live.
        fireTap(on: plainView)
        runLoop(until: collector, has: 1, ofType: Constants.AMP_DEAD_CLICK_EVENT)
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_DEAD_CLICK_EVENT).count, 1,
                       "The positive control must produce a dead click")
    }

    /// The ancestor lookup only matters if the capture path consults it. Every other ignore-hook
    /// test reads the flags or the helpers directly and would stay green if the wiring were
    /// reverted; this one drives the real swizzled `setState:` and checks what the SDK emits.
    func testGesturePathEmitsNoRageClickWhenTheWebViewIsIgnored() throws {
        let (amplitude, collector) = makeAmplitude()
        defer { UIKitElementInteractions.unregister(amplitude) }

        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        let nestedInWebView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        webView.addSubview(nestedInWebView)

        let plainView = UIView(frame: CGRect(x: 0, y: 600, width: 100, height: 100))
        window.addSubview(plainView)
        window.makeKeyAndVisible()
        amplitude.waitForTrackingQueue()

        // What a customer would write to silence one noisy web view.
        webView.amp_ignoreInteractionEvent(rageClick: true, deadClick: false)

        // Four rapid taps on web content the customer marked: enough to cross the rage threshold.
        let burstEnd = try fireRageClickBurst(on: nestedInWebView, at: CGPoint(x: 50, y: 50))
        // Past the 1 s debounce, so a rage click, had one been detected, would have been reported.
        RunLoop.current.run(until: burstEnd.addingTimeInterval(1.5))
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_RAGE_CLICK_EVENT).count, 0,
                       "The marked web view must produce no rage click")

        // Positive control: the same taps on an unmarked view still do, proving the detector was
        // live and the taps really reached the swizzled path.
        try fireRageClickBurst(on: plainView, at: CGPoint(x: 50, y: 650))
        runLoop(until: collector, has: 1, ofType: Constants.AMP_RAGE_CLICK_EVENT)
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(events(in: collector, ofType: Constants.AMP_RAGE_CLICK_EVENT).count, 1,
                       "The unmarked view must still produce a rage click")
    }

    /// The other capture path, `UIApplication.amp_sendAction`, gates on the same two helpers. Its
    /// inputs are pinned here; the call site itself is not, and cannot be from this target — the
    /// unit test bundle has no `UIApplication`, so `sendActions(for:)` never reaches the swizzled
    /// `sendAction:`. That wiring is exercised by the Frustration Interactions screen in the
    /// Session Replay example app, which runs in a real application process.
    ///
    /// The subject is deliberately a native `UIButton` hosted inside the web view's scroll view:
    /// the case the subtree-wide suppression knowingly gives up. It is native and would raise a
    /// real interface signal, and it still loses dead click detection.
    func testNativeControlInsideAWebViewIsNotEligibleForDeadClick() {
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        let buttonInWebView = UIButton(type: .system)
        webView.scrollView.addSubview(buttonInWebView)

        let plainButton = UIButton(type: .system)
        window.addSubview(plainButton)

        XCTAssertTrue(buttonInWebView.amp_isInsideWebView)
        XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: buttonInWebView),
                       "A native control inside a web view loses dead click, by design")
        XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: buttonInWebView),
                      "but keeps rage click")

        XCTAssertTrue(UIKitElementInteractions.shouldProcessDeadClick(for: plainButton))
        XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: plainButton))

        // The ignore flag reaches a control through its container on this path too.
        window.amp_ignoreInteractionEvent(rageClick: true, deadClick: true)
        XCTAssertFalse(UIKitElementInteractions.shouldProcessRageClick(for: plainButton))
        XCTAssertFalse(UIKitElementInteractions.shouldProcessDeadClick(for: plainButton))
    }

    // MARK: - The ignore hook reaches the view the SDK actually checks

    /// The reason the hook exists: an app can only reach the `WKWebView`, while the SDK attributes
    /// interactions to the private `WKContentView` two levels below it. Before the lookup walked
    /// ancestors, `webView.amp_ignoreInteractionEvent()` was a silent no-op.
    func testIgnoreHookOnWebViewReachesTheRecognizerView() throws {
        let webView = try attachedWebView()

        let qualifying = allRecognizers(in: webView).filter { qualifiesAsPhysicalTap($0.recognizer) }
        XCTAssertFalse(qualifying.isEmpty)

        // Rage click only, which is what a customer suppressing a noisy web view would ask for.
        webView.amp_ignoreInteractionEvent(rageClick: true, deadClick: false)

        for (view, recognizer) in qualifying {
            let chain = sequence(first: view, next: \.superview).map { $0.descriptiveTypeName }
                .joined(separator: " -> ")

            XCTAssertTrue(view.amp_ignoreRageClick,
                          "The flag set on WKWebView must reach \(recognizer.descriptiveTypeName) "
                          + "on \(chain)")
            XCTAssertFalse(UIKitElementInteractions.shouldProcessRageClick(for: view),
                           "rage click must be suppressed for \(view.descriptiveTypeName)")
            // `deadClick: false` was passed, so nothing here marks dead click — it is suppressed
            // only because this is web content.
            XCTAssertFalse(view.amp_ignoreDeadClick)
        }
    }

    /// Marking a view controller's root view covers the whole screen — the shape a customer would
    /// use to silence one noisy surface such as a webview-hosting view controller.
    func testIgnoreOnAViewControllerRootViewCoversTheWholeScreen() {
        let viewController = UIViewController()
        viewController.title = "Noisy Screen"
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        let webView = WKWebView(frame: viewController.view.bounds)
        viewController.view.addSubview(webView)
        let nestedInWebView = UIView()
        webView.addSubview(nestedInWebView)
        let nativeButton = UIButton(type: .system)
        viewController.view.addSubview(nativeButton)

        viewController.view.amp_ignoreInteractionEvent(rageClick: true, deadClick: false)

        for view in [viewController.view!, webView, nestedInWebView, nativeButton] {
            XCTAssertTrue(view.amp_ignoreRageClick,
                          "\(view.descriptiveTypeName) is on the ignored screen")
            XCTAssertFalse(UIKitElementInteractions.shouldProcessRageClick(for: view))
        }
    }

    /// The gap was never webview-specific: marking any container has to cover the subviews the taps
    /// actually land on.
    func testIgnoreOnAContainerCoversItsSubviews() {
        let container = UIView(frame: window.bounds)
        window.addSubview(container)

        var leaf: UIView = container
        for _ in 0..<5 {
            let next = UIView()
            leaf.addSubview(next)
            leaf = next
        }

        let sibling = UIView()
        window.addSubview(sibling)

        container.amp_ignoreInteractionEvent(rageClick: true, deadClick: true)

        XCTAssertTrue(leaf.amp_ignoreRageClick, "A descendant five levels down is covered")
        XCTAssertTrue(leaf.amp_ignoreDeadClick)
        XCTAssertFalse(UIKitElementInteractions.shouldProcessRageClick(for: leaf))

        XCTAssertFalse(sibling.amp_ignoreRageClick, "A view outside the marked subtree is not")
        XCTAssertTrue(UIKitElementInteractions.shouldProcessRageClick(for: sibling))
    }

    /// Marking is monotonic: a subview cannot opt back in, because the stored `Bool` cannot tell
    /// "never set" from "set to false". This pins that decision.
    func testASubviewCannotOptBackIntoAnIgnoredSubtree() {
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        let child = UIView()
        container.addSubview(child)

        container.amp_ignoreInteractionEvent(rageClick: true, deadClick: true)
        child.amp_ignoreInteractionEvent(rageClick: false, deadClick: false)

        XCTAssertTrue(child.amp_ignoreRageClick, "The ancestor's marking still wins")
        XCTAssertTrue(child.amp_ignoreDeadClick)
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

    /// Four taps on `view`, 10 ms apart: past the SDK's 5 ms physical-tap dedup window and well
    /// inside the rage click detector's 1 s window. Click timestamps are taken synchronously in
    /// `amp_setState`, so the spacing is exactly this loop's pacing and no run-loop turn is needed
    /// between taps. Turning the run loop there let unrelated work (WebKit IPC, layout) stretch a
    /// burst past 1 s on a loaded CI runner, and the detector then correctly saw no rage click.
    /// Returns when the last tap was fired. Skips the test if the host stalled so badly that even
    /// this burst exceeded the window: the SDK was then never given four taps within a second.
    @discardableResult
    private func fireRageClickBurst(on view: UIView,
                                    at location: CGPoint = CGPoint(x: 50, y: 50),
                                    file: StaticString = #filePath,
                                    line: UInt = #line) throws -> Date {
        let start = Date()
        for i in 0..<4 {
            if i > 0 {
                Thread.sleep(forTimeInterval: 0.01)
            }
            fireTap(on: view, at: location)
        }
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        if elapsed > 0.9 {
            throw XCTSkip("Host stalled: four taps took \(elapsed) s, longer than the 1 s rage click window",
                          file: file, line: line)
        }
        return end
    }

    /// Turns the main run loop until `collector` holds `count` events of `eventType`, or `timeout`
    /// passes. The detectors report from main-run-loop timers (rage click 1 s after the last tap,
    /// dead click 3.5 s after the tap), so the loop has to turn while waiting; a fixed turn read
    /// the collector before a late timer had fired on a loaded CI runner. The caller's assertion
    /// still reports a missing event; this only removes the fixed budget.
    private func runLoop(until collector: EventCollectorPlugin,
                         has count: Int,
                         ofType eventType: String,
                         timeout: TimeInterval = 15) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, events(in: collector, ofType: eventType).count < count {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            Thread.sleep(forTimeInterval: 0.01)
        }
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

    /// A web view in the key window with WebKit's tap recognizers attached to its `WKContentView`.
    ///
    /// Nothing is loaded into it. The tests using this only inspect the view hierarchy WebKit
    /// builds in this process, and `WKContentView` gets its recognizers in `didMoveToWindow`, so
    /// they are present within milliseconds of `addSubview` (measured 0.1-6 ms on an iPhone 16 Pro
    /// simulator). Earlier versions loaded an HTML string and waited for `didFinish`, which made
    /// these tests depend on WebKit's WebContent and GPU processes launching. On a CI simulator
    /// that has taken over six minutes (`GPU process took 366 seconds to launch`), so every load
    /// timed out whatever the budget, while nothing here ever asserted on page content.
    private func attachedWebView() throws -> WKWebView {
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        window.makeKeyAndVisible()
        try waitForTapRecognizers(in: webView)
        return webView
    }

    private struct TapRecognizersMissing: Error {}

    /// Polls for the first recognizer that passes the SDK's physical-tap gate. Fails and throws if
    /// none appears, so a caller never reaches its assertions with an empty hierarchy.
    private func waitForTapRecognizers(in webView: WKWebView,
                                       timeout: TimeInterval = 10,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if allRecognizers(in: webView).contains(where: { qualifiesAsPhysicalTap($0.recognizer) }) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let present = allRecognizers(in: webView).map { "\($0.recognizer.descriptiveTypeName) on \($0.view.descriptiveTypeName)" }
        XCTFail("No single-tap recognizer appeared on the web view within \(timeout)s; present: \(present)",
                file: file, line: line)
        throw TapRecognizersMissing()
    }
}

#endif
