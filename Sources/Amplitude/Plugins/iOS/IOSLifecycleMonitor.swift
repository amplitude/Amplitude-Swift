#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import Foundation
import UIKit

/// Platform notifications and cold-start detection are independent of analytics processing.
class IOSLifecycleMonitor: ApplicationLifecycle {
    private var awaitingInitialActivation = false
    private var launchPending = false

    override var initialState: InitialState {
        switch IOSVendorSystem.applicationState {
        case .active: return .active
        case .inactive: return .inactive
        case .background: return .background
        default: return .unknown
        }
    }

    override func reconcileInitialState(_ state: InitialState) {
        switch state {
        case .active:
            becomeActive(launch: true)
        case .inactive, .background:
            awaitingInitialActivation = true
            launchPending = true
        case .unknown:
            break
        }
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
        let inBackground = IOSVendorSystem.applicationState == .background
        // Apps without scenes and background launches may only get an activation notification.
        if inBackground || !IOSVendorSystem.usesScenes {
            awaitingInitialActivation = true
        }
        launchPending = false
        didFinishLaunching(inBackground: inBackground)
    }

    @objc
    private func applicationDidBecomeActive(notification: Notification) {
        guard awaitingInitialActivation else { return }
        awaitingInitialActivation = false
        let launch = launchPending
        launchPending = false
        becomeActive(launch: launch)
    }

    @objc
    private func applicationWillEnterForeground(notification: Notification) {
        awaitingInitialActivation = false
        launchPending = false
        enterForeground(fromBackground: IOSVendorSystem.applicationState == .background)
    }

    @objc
    private func applicationDidEnterBackground(notification: Notification) {
        enterBackground()
    }
}

#endif
