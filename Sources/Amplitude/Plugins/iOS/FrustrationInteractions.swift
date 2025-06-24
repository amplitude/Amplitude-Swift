//
//  FrustrationInteractions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 6/19/25.
//

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
import UIKit
import AmplitudeCore

struct FrustrationClickData {
    let time: Date
    let eventData: UIKitElementInteractions.EventData
    let location: CGPoint
    let action: String
    let source: UIKitElementInteractions.EventData.Source?
    let sourceName: String?
}

class DeadClickDetector: InterfaceSignalReceiver, @unchecked Sendable {
    private let CLICK_TIMEOUT_MS = 3000
    // Check all pending clicks to see if this UI change is related to any of them
    // Account for slight delay between click and UI change (typically < 500ms)
    private let UI_CHANGE_MAX_DELAY: TimeInterval = 0.5 // 500ms max delay between click and UI change

    private var pendingClicks: [UUID: (FrustrationClickData, Timer)] = [:]
    private let lock = NSLock()
    private weak var amplitude: Amplitude?

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
        self.amplitude?.interfaceSignalProvider?.addInterfaceSignalReceiver(self)
    }

    func interfaceSignalProviderDidChange() {
        self.amplitude?.interfaceSignalProvider?.addInterfaceSignalReceiver(self)
    }

    func processClick(_ clickData: FrustrationClickData) {
        lock.withLock {
            guard self.amplitude?.interfaceSignalProvider?.isProviding == true else {
                return
            }

            let timeoutMs = CLICK_TIMEOUT_MS
            let timeoutInterval = TimeInterval(timeoutMs) / 1000.0 + UI_CHANGE_MAX_DELAY

            let clickId = UUID()

            let timer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
                self?.triggerDeadClick(clickId: clickId)
            }

            pendingClicks[clickId] = (clickData, timer)
        }
    }

    @objc func onInterfaceChanged(signal: InterfaceChangeSignal) {
        lock.withLock {
            let interfaceChangeTimestamp = signal.time.timeIntervalSince1970

            var clicksToRemove: [UUID] = []

            // remove the clicks happend before UI change
            for (clickId, (clickData, timer)) in pendingClicks
            where clickData.time.timeIntervalSince1970 < interfaceChangeTimestamp {
                timer.invalidate()
                clicksToRemove.append(clickId)
            }

            for clickId in clicksToRemove {
                pendingClicks.removeValue(forKey: clickId)
            }
        }
    }

    func onStartProviding() {
        // do nothing
    }

    func onStopProviding() {
        // drop all unsend clicks because we can not get ui change any more
        reset()
    }

    private func triggerDeadClick(clickId: UUID) {
        lock.withLock {
            guard let (clickData, _) = pendingClicks.removeValue(forKey: clickId),
                  let amplitude = amplitude else { return }

            let deadClickEvent = DeadClickEvent(
                time: clickData.time,
                x: clickData.location.x,
                y: clickData.location.y,
                screenName: clickData.eventData.screenName,
                accessibilityLabel: clickData.eventData.accessibilityLabel,
                accessibilityIdentifier: clickData.eventData.accessibilityIdentifier,
                action: clickData.action,
                targetViewClass: clickData.eventData.targetViewClass,
                targetText: clickData.eventData.targetText,
                hierarchy: clickData.eventData.hierarchy,
                actionMethod: clickData.source == .actionMethod ? clickData.sourceName : nil,
                gestureRecognizer: clickData.source == .gestureRecognizer ? clickData.sourceName : nil
            )

            amplitude.track(event: deadClickEvent)

            trim(for: clickData.eventData.targetViewIdentifier)
        }
    }

    func trim(for elementIdentifier: ObjectIdentifier) {
        var clicksToRemove: [UUID] = []

        for (clickId, (clickData, timer)) in pendingClicks
        where clickData.eventData.targetViewIdentifier == elementIdentifier {
                timer.invalidate()
                clicksToRemove.append(clickId)
        }

        for clickId in clicksToRemove {
            pendingClicks.removeValue(forKey: clickId)
        }
    }

    func reset() {
        lock.withLock {
            for (_, (_, timer)) in pendingClicks {
                timer.invalidate()
            }
            pendingClicks.removeAll()
        }
    }
}

class RageClickDetector {
    private let CLICK_RANGE_THRESHOLD: CGFloat = 50
    private let CLICK_COUNT_THRESHOLD: Int = 3
    private let CLICK_TIMEOUT_MS: TimeInterval = 1000

    private var clickQueue: [FrustrationClickData] = []
    private var debounceTimer: Timer?
    private let lock = NSLock()
    private weak var amplitude: Amplitude?

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func processClick(_ clickData: FrustrationClickData) {
        lock.withLock {
            let timeoutInterval = TimeInterval(CLICK_TIMEOUT_MS) / 1000.0

            if let last = clickQueue.last, !isSameElement(last, clickData) || !isWithinRange(last.location, clickData.location) {
                self.triggerRageClick()
            }

            clickQueue.append(clickData)

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
                self?.triggerRageClick()
            }
        }
    }

    private func isSameElement(_ data1: FrustrationClickData, _ data2: FrustrationClickData) -> Bool {
        return data1.eventData.targetViewIdentifier == data2.eventData.targetViewIdentifier
    }

    private func isWithinRange(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
        let distance = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
        return distance <= CLICK_RANGE_THRESHOLD
    }

    private func triggerRageClick() {
        defer { clickQueue.removeAll() }

        guard clickQueue.count >= CLICK_COUNT_THRESHOLD,
              let amplitude = amplitude,
              let firstClick = clickQueue.first,
              let lastClick = clickQueue.last
        else { return }

        let clicks = clickQueue.map { clickData in
            Click(
                x: clickData.location.x,
                y: clickData.location.y,
                time: clickData.time.amp_iso8601String()
            )
        }

        let rageClickEvent = RageClickEvent(
            beginTime: firstClick.time,
            endTime: lastClick.time,
            clicks: clicks,
            screenName: firstClick.eventData.screenName,
            accessibilityLabel: firstClick.eventData.accessibilityLabel,
            accessibilityIdentifier: firstClick.eventData.accessibilityIdentifier,
            action: firstClick.action,
            targetViewClass: firstClick.eventData.targetViewClass,
            targetText: firstClick.eventData.targetText,
            hierarchy: firstClick.eventData.hierarchy,
            actionMethod: firstClick.source == .actionMethod ? firstClick.sourceName : nil,
            gestureRecognizer: firstClick.source == .gestureRecognizer ? firstClick.sourceName : nil
        )

        amplitude.track(event: rageClickEvent)
    }

    func reset() {
        lock.withLock {
            debounceTimer?.invalidate()
            debounceTimer = nil
            clickQueue.removeAll()
        }
    }
}

#endif
