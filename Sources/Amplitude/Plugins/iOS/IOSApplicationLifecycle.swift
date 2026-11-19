#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import Foundation
import UIKit

/// Platform notifications and cold-start detection are independent of analytics processing.
class IOSApplicationLifecycle: ApplicationLifecycle {
    private var emitLaunchOnActivation = false
    private var emitForegroundOnActivation = false

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
            emitLaunchOnActivation = true
            emitForegroundOnActivation = true
        default:
            break
        }
    }

    @objc
    private func applicationDidFinishLaunchingNotification(notification: Notification) {
        didFinishLaunching()
        // Apps without scenes use their initial activation as the foreground signal.
        if !IOSVendorSystem.usesScenes {
            emitForegroundOnActivation = true
        }
    }

    @objc
    private func applicationDidBecomeActive(notification: Notification) {
        guard emitLaunchOnActivation || emitForegroundOnActivation else { return }
        let emitLaunch = emitLaunchOnActivation
        emitLaunchOnActivation = false
        emitForegroundOnActivation = false
        if emitLaunch {
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
