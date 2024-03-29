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
        ]
        private var trackAppOpenedEventOnEnterForeground: Bool = true
        private var utils: DefaultEventUtils?

        override init() {
            // TODO: Check if lifecycle plugin works for app extension
            // App extensions can't use UIApplication.shared, so
            // funnel it through something to check; Could be nil.
            application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication
            super.init()
            setupListeners()
        }

        public override func setup(amplitude: Amplitude) {
            super.setup(amplitude: amplitude)
            utils = DefaultEventUtils(amplitude: amplitude)
            if amplitude.configuration.defaultTracking.screenViews {
                UIKitScreenViews.register(amplitude)
            }
        }

        @objc
        func notificationResponse(notification: NSNotification) {
            switch notification.name {
            case UIApplication.didEnterBackgroundNotification:
                self.didEnterBackground(notification: notification)
            case UIApplication.willEnterForegroundNotification:
                self.applicationWillEnterForeground(notification: notification)
            case UIApplication.didFinishLaunchingNotification:
                self.applicationDidFinishLaunchingNotification(notification: notification)
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

        func applicationWillEnterForeground(notification: NSNotification) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
            if self.amplitude?.configuration.defaultTracking.appLifecycles == true && self.trackAppOpenedEventOnEnterForeground {
                let info = Bundle.main.infoDictionary
                let currentBuild = info?["CFBundleVersion"] as? String
                let currentVersion = info?["CFBundleShortVersionString"] as? String
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_OPENED_EVENT, eventProperties: [
                    Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                    Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                    Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: true,
                ])
            }
        }

        func didEnterBackground(notification: NSNotification) {
            self.trackAppOpenedEventOnEnterForeground = true

            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onExitForeground(timestamp: timestamp)
            if self.amplitude?.configuration.defaultTracking.appLifecycles == true {
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
            }
        }

        func applicationDidFinishLaunchingNotification(notification: NSNotification) {
            self.trackAppOpenedEventOnEnterForeground = false

            utils?.trackAppUpdatedInstalledEvent()
        }
    }

#endif
