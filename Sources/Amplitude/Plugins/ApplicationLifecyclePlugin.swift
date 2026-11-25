import Foundation

/// Orders analytics lifecycle work before the existing session and event APIs enqueue processing.
internal final class ApplicationLifecyclePlugin: UtilityPlugin, ApplicationLifecycleObserver {
    // App lifecycle autocapture is currently supported on UIKit platforms.
    private var utils: DefaultEventUtils?
    private var previousAppVersion: DefaultEventUtils.AppVersion?
    private var activationCompletesForeground = false

    override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
        utils = DefaultEventUtils(amplitude: amplitude)
#endif
        amplitude.appLifecycle.addObserver(self)
        // Observe transitions and capture initial state before setting up UI autocapture.
        amplitude.appLifecycle.start { state in
            activationCompletesForeground = state == .background
            if state != .active {
                // Later notification callbacks can enqueue events without waiting on version storage.
                previousAppVersion = utils?.storedAppVersion(in: amplitude.storage)
            }
        }

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
        updateAutocaptureSetup()
        amplitude.autocaptureManager.onChange { [weak self] _ in
            self?.updateAutocaptureSetup()
        }
#endif
    }

    func applicationDidFinishLaunching(inBackground: Bool) {
        guard !inBackground, let previous = takePendingAppVersion() else { return }
        utils?.enqueueAppUpdatedInstalledEvent(previous: previous)
    }

    func applicationDidBecomeActive(launch: Bool) {
        if !launch || activationCompletesForeground {
            // Activation substitutes for a missing foreground callback. Enqueue before later caller events.
            trackForeground(timestamp: Int64(Date().timeIntervalSince1970 * 1000), fromBackground: false)
            return
        }

        // Startup historically defers generation, identity capture, and the session timestamp.
        let previous = takePendingAppVersion()
        amplitude?.trackingQueue.async { [self] in
            amplitude?.onEnterForeground(timestamp: Int64(Date().timeIntervalSince1970 * 1000))
            if launch {
                if let previous {
                    utils?.trackAppUpdatedInstalledEvent(previous: previous, persistOn: nil)
                } else {
                    utils?.trackAppUpdatedInstalledEvent()
                }
            }
            utils?.trackAppOpenedEvent()
        }
    }

    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
        trackForeground(timestamp: timestamp, fromBackground: fromBackground)
    }

    private func trackForeground(timestamp: Int64, fromBackground: Bool) {
        // Update foreground state immediately, before a subsequent track() snapshots it.
        amplitude?.onEnterForeground(timestamp: timestamp)
        trackPendingAppVersion()
        utils?.trackAppOpenedEvent(fromBackground: fromBackground)
    }

    func applicationDidEnterBackground(timestamp: Int64) {
        amplitude?.onExitForeground(timestamp: timestamp)
        utils?.trackAppBackgroundedEvent()
    }

    private func trackPendingAppVersion() {
        guard let amplitude, let previous = takePendingAppVersion() else { return }
        utils?.trackAppUpdatedInstalledEvent(previous: previous, persistOn: amplitude.trackingQueue)
    }

    private func takePendingAppVersion() -> DefaultEventUtils.AppVersion? {
        defer { previousAppVersion = nil }
        return previousAppVersion
    }

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
    private func updateAutocaptureSetup() {
        guard let amplitude else { return }
        let manager = amplitude.autocaptureManager

        if manager.isEnabled(.screenViews) {
            UIKitScreenViews.register(amplitude)
        } else {
            UIKitScreenViews.unregister(amplitude)
        }

        // Register UIKitElementInteractions if either element interactions or frustration interactions is enabled
        let needsElementInteractions = manager.isEnabled(.elementInteractions) || manager.isEnabled(.frustrationInteractions)
        if needsElementInteractions {
            UIKitElementInteractions.register(amplitude)
        } else {
            UIKitElementInteractions.unregister(amplitude)
        }
    }

    override func teardown() {
        super.teardown()

        if let amplitude {
            UIKitScreenViews.unregister(amplitude)
            UIKitElementInteractions.unregister(amplitude)
        }
    }
#endif
}
