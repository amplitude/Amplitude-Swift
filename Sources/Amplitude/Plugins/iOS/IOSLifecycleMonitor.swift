//
//  IOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Foundation
import SwiftUI

class IOSLifecycleMonitor: UtilityPlugin {
    private var application: UIApplication?
    private var appNotifications: [NSNotification.Name] = [
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willEnterForegroundNotification,
        UIApplication.didFinishLaunchingNotification,
        UIApplication.didBecomeActiveNotification,
    ]
    private var utils: DefaultEventUtils?
    private var sendApplicationOpenedOnDidBecomeActive = false

    override init() {
        // TODO: Check if lifecycle plugin works for app extension
        // App extensions can't use UIApplication.shared, so
        // funnel it through something to check; Could be nil.
        application = IOSVendorSystem.sharedApplication
        super.init()
        setupListeners()
    }

    public override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        utils = DefaultEventUtils(amplitude: amplitude)
        if amplitude.configuration.autocapture.contains(.screenViews) {
            UIKitScreenViews.register(amplitude)
        }
        if amplitude.configuration.autocapture.contains(.elementInteractions) {
            UIKitElementInteractions.register(amplitude)
        }
    }

    @objc
    func notificationResponse(notification: Notification) {
        switch notification.name {
        case UIApplication.didEnterBackgroundNotification:
            didEnterBackground(notification: notification)
        case UIApplication.willEnterForegroundNotification:
            applicationWillEnterForeground(notification: notification)
        case UIApplication.didFinishLaunchingNotification:
            applicationDidFinishLaunchingNotification(notification: notification)
        case UIApplication.didBecomeActiveNotification:
            applicationDidBecomeActive(notification: notification)
        default:
            break
        }
    }

    func setupListeners() {
        // Configure the current life cycle events
        let notificationCenter = NotificationCenter.default
        for notification in appNotifications {
            notificationCenter.addObserver(
                self,
                selector: #selector(notificationResponse(notification:)),
                name: notification,
                object: application
            )
        }

    }

    func applicationWillEnterForeground(notification: Notification) {
        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)

        let fromBackground: Bool
        if let sharedApplication = application {
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

        amplitude?.onEnterForeground(timestamp: timestamp)
        sendApplicationOpened(fromBackground: fromBackground)
    }

    func didEnterBackground(notification: Notification) {
        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        self.amplitude?.onExitForeground(timestamp: timestamp)
        if amplitude?.configuration.autocapture.contains(.appLifecycles) ?? false {
            self.amplitude?.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
        }
    }

    func applicationDidFinishLaunchingNotification(notification: Notification) {
        utils?.trackAppUpdatedInstalledEvent()

        // Pre SceneDelegate apps wil not fire a willEnterForeground notification on app launch.
        // Instead, use the initial applicationDidBecomeActive
        let usesSceneDelegate = application?.delegate?.responds(to: #selector(UIApplicationDelegate.application(_:configurationForConnecting:options:))) ?? false
        if !usesSceneDelegate {
            sendApplicationOpenedOnDidBecomeActive = true
        }
    }

    func applicationDidBecomeActive(notification: Notification) {
        guard sendApplicationOpenedOnDidBecomeActive else {
            return
        }
        sendApplicationOpenedOnDidBecomeActive = false

        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        amplitude?.onEnterForeground(timestamp: timestamp)
        sendApplicationOpened(fromBackground: false)
    }

    private func sendApplicationOpened(fromBackground: Bool) {
        guard amplitude?.configuration.autocapture.contains(.appLifecycles) ?? false else {
            return
        }
        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] as? String
        let currentVersion = info?["CFBundleShortVersionString"] as? String
        self.amplitude?.track(eventType: Constants.AMP_APPLICATION_OPENED_EVENT, eventProperties: [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: fromBackground,
        ])
    }
}

#endif
