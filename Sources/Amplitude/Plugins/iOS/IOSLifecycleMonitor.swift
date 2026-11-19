//
//  IOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import AmplitudeCore
import Foundation
import SwiftUI

class IOSLifecycleMonitor: UtilityPlugin, ApplicationLifecycleObserver {

    private var utils: DefaultEventUtils?

    public override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        utils = DefaultEventUtils(amplitude: amplitude)

        amplitude.appLifecycle.addObserver(self)

        updateAutocaptureSetup()

        // Listen for autocapture config changes from the manager
        amplitude.autocaptureManager.onChange { [weak self] _ in
            self?.updateAutocaptureSetup()
        }
    }

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

    func applicationDidFinishLaunching() {
        amplitude?.trackingQueue.async { [self] in
            utils?.trackAppUpdatedInstalledEvent()
        }
    }

    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
        amplitude?.trackingQueue.async { [self] in
            utils?.trackAppOpenedEvent(fromBackground: fromBackground)
        }
    }

    func applicationDidEnterBackground(timestamp: Int64) {
        amplitude?.trackingQueue.async { [self] in
            if let amplitude, amplitude.autocaptureManager.isEnabled(.appLifecycles) {
                amplitude.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
            }
        }
    }

    override func teardown() {
        super.teardown()

        if let amplitude {
            UIKitScreenViews.unregister(amplitude)
            UIKitElementInteractions.unregister(amplitude)
        }
    }
}

/// Platform notifications and cold-start detection are independent of analytics processing.
class IOSApplicationLifecycle: ApplicationLifecycle {
    private var sendAppInstalledOnDidBecomeActive = false
    private var sendAppOpenedOnDidBecomeActive = false

    override func start() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidFinishLaunchingNotification(notification:)),
                                               name: UIApplication.didFinishLaunchingNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive(notification:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground(notification:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(notification:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        switch IOSVendorSystem.applicationState {
        case .active:
            didFinishLaunching()
            enterForeground()
        case .inactive:
            sendAppInstalledOnDidBecomeActive = true
            sendAppOpenedOnDidBecomeActive = true
        default:
            break
        }
    }

    @objc
    private func applicationDidFinishLaunchingNotification(notification: Notification) {
        didFinishLaunching()
        // Apps without scenes use their initial activation as the foreground signal.
        if !IOSVendorSystem.usesScenes {
            sendAppOpenedOnDidBecomeActive = true
        }
    }

    @objc
    private func applicationDidBecomeActive(notification: Notification) {
        guard sendAppInstalledOnDidBecomeActive || sendAppOpenedOnDidBecomeActive else { return }
        let sendInstall = sendAppInstalledOnDidBecomeActive
        sendAppInstalledOnDidBecomeActive = false
        sendAppOpenedOnDidBecomeActive = false
        if sendInstall {
            didFinishLaunching()
        }
        enterForeground()
    }

    @objc
    private func applicationWillEnterForeground(notification: Notification) {
        enterForeground(fromBackground: IOSVendorSystem.applicationState == .background)
    }

    @objc
    private func applicationDidEnterBackground(notification: Notification) {
        enterBackground()
    }
}

#endif
