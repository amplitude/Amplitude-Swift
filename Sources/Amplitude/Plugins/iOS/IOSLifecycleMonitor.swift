//
//  IOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import Foundation
import SwiftUI

class IOSLifecycleMonitor: UtilityPlugin {

    private var utils: DefaultEventUtils?
    private var sendApplicationOpenedOnDidBecomeActive = false

    override init() {
        super.init()

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

    public override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        utils = DefaultEventUtils(amplitude: amplitude)

        // If we are already in the foreground, dispatch installed / opened events now
        // Use keypath vs applicationState property to avoid main thread checker warning,
        // we want to dispatch this from the initiating thread to maintain event ordering.
        if let application = IOSVendorSystem.sharedApplication,
           let rawState = application.value(forKey: #keyPath(UIApplication.applicationState)) as? Int,
           let applicationState = UIApplication.State(rawValue: rawState),
           applicationState == .active {
            utils?.trackAppUpdatedInstalledEvent()
            amplitude.onEnterForeground(timestamp: currentTimestamp)
            utils?.trackAppOpenedEvent()
        }

        if amplitude.configuration.autocapture.contains(.screenViews) {
            UIKitScreenViews.register(amplitude)
        }
        if amplitude.configuration.autocapture.contains(.elementInteractions) {
            UIKitElementInteractions.register(amplitude)
        }
    }

    @objc
    func applicationDidFinishLaunchingNotification(notification: Notification) {
        utils?.trackAppUpdatedInstalledEvent()

        // Pre SceneDelegate apps wil not fire a willEnterForeground notification on app launch.
        // Instead, use the initial applicationDidBecomeActive
        let sceneManifest = Bundle.main.infoDictionary?["UIApplicationSceneManifest"] as? [String: Any]
        let sceneConfigurations = sceneManifest?["UISceneConfigurations"] as? [String: Any] ?? [:]
        let hasSceneConfigurations = !sceneConfigurations.isEmpty

        let appDelegate = IOSVendorSystem.sharedApplication?.delegate
        let selector = #selector(UIApplicationDelegate.application(_:configurationForConnecting:options:))
        let usesSceneDelegate = appDelegate?.responds(to: selector) ?? false

        if !(hasSceneConfigurations || usesSceneDelegate) {
            sendApplicationOpenedOnDidBecomeActive = true
        }
    }

    @objc
    func applicationDidBecomeActive(notification: Notification) {
        guard sendApplicationOpenedOnDidBecomeActive else {
            return
        }
        sendApplicationOpenedOnDidBecomeActive = false

        amplitude?.onEnterForeground(timestamp: currentTimestamp)
        utils?.trackAppOpenedEvent()
    }

    @objc
    func applicationWillEnterForeground(notification: Notification) {
        let fromBackground: Bool
        if let sharedApplication = IOSVendorSystem.sharedApplication {
            switch sharedApplication.applicationState {
            case .active, .inactive:
                fromBackground = false
            case .background:
                fromBackground = true
            @unknown default:
                fromBackground = false
            }
        } else {
            fromBackground = false
        }

        amplitude?.onEnterForeground(timestamp: currentTimestamp)
        utils?.trackAppOpenedEvent(fromBackground: fromBackground)
    }

    @objc
    func applicationDidEnterBackground(notification: Notification) {
        guard let amplitude = amplitude else {
            return
        }
        amplitude.onExitForeground(timestamp: currentTimestamp)
        if amplitude.configuration.autocapture.contains(.appLifecycles) {
            amplitude.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
        }
    }

    private var currentTimestamp: Int64 {
        return Int64(NSDate().timeIntervalSince1970 * 1000)
    }

    override func teardown() {
        super.teardown()

        if let amplitude {
            UIKitScreenViews.unregister(amplitude)
            UIKitElementInteractions.unregister(amplitude)
        }
    }
}

#endif
