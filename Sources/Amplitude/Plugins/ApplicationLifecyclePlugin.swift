/// Orders analytics lifecycle work before the existing session and event APIs enqueue processing.
internal final class ApplicationLifecyclePlugin: UtilityPlugin, ApplicationLifecycleObserver {
    // App lifecycle autocapture is currently supported on UIKit platforms.
    private var utils: DefaultEventUtils?

    override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        amplitude.appLifecycle.addObserver(self)

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
        utils = DefaultEventUtils(amplitude: amplitude)
        updateAutocaptureSetup()
        amplitude.autocaptureManager.onChange { [weak self] _ in
            self?.updateAutocaptureSetup()
        }
#endif
    }

    func applicationDidFinishLaunching() {
        utils?.trackAppUpdatedInstalledEvent()
    }

    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
        // Update foreground state immediately, before a subsequent track() snapshots it.
        amplitude?.onEnterForeground(timestamp: timestamp)
        utils?.trackAppOpenedEvent(fromBackground: fromBackground)
    }

    func applicationDidEnterBackground(timestamp: Int64) {
        amplitude?.onExitForeground(timestamp: timestamp)
        utils?.trackAppBackgroundedEvent()
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
