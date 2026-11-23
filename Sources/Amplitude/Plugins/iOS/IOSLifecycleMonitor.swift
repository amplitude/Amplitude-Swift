#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import Foundation
import UIKit

/// Platform notifications and cold-start detection are independent of analytics processing.
class IOSLifecycleMonitor: ApplicationLifecycle {
    private enum ActivationFallback {
        case deferredStartup
        case foreground
    }

    private var activationFallback: ActivationFallback?

    @discardableResult
    override func start() -> Bool {
        guard super.start() else { return false }
        switch IOSVendorSystem.applicationState {
        case .active:
            becomeActive(launch: true)
        case .inactive:
            activationFallback = .deferredStartup
        case .background:
            activationFallback = .foreground
        default:
            break
        }
        return true
    }

    override func startObserving() {
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
    }

    @objc
    private func applicationDidFinishLaunchingNotification(notification: Notification) {
        // A background launch or an app without scenes may need activation as its foreground signal.
        if IOSVendorSystem.applicationState == .background || !IOSVendorSystem.usesScenes {
            activationFallback = .foreground
        }
        didFinishLaunching()
    }

    @objc
    private func applicationDidBecomeActive(notification: Notification) {
        let fallback = activationFallback
        activationFallback = nil
        switch fallback {
        case .deferredStartup:
            becomeActive(launch: true)
        case .foreground:
            enterForeground()
        case nil:
            break
        }
    }

    @objc
    private func applicationWillEnterForeground(notification: Notification) {
        activationFallback = nil
        enterForeground(fromBackground: IOSVendorSystem.applicationState == .background)
    }

    @objc
    private func applicationDidEnterBackground(notification: Notification) {
        enterBackground()
    }
}

#endif
