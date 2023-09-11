//
//  IOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    import Foundation
    import SwiftUI

    public protocol IOSLifecycle {
        func applicationDidEnterBackground(application: UIApplication?)
        func applicationWillEnterForeground(application: UIApplication?)
        func applicationDidFinishLaunchingNotification(application: UIApplication?)
    }

    extension IOSLifecycle {
        public func applicationDidEnterBackground(application: UIApplication?) {}
        public func applicationWillEnterForeground(application: UIApplication?) {}
        public func applicationDidFinishLaunchingNotification(application: UIApplication?) {}
    }

    class IOSLifecycleMonitor: UtilityPlugin {
        private var application: UIApplication?
        private var appNotifications: [NSNotification.Name] = [
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.didFinishLaunchingNotification,
        ]

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
            amplitude?.apply { (ext) in
                if let validExt = ext as? IOSLifecycle {
                    validExt.applicationWillEnterForeground(application: application)
                }
            }
        }

        func didEnterBackground(notification: NSNotification) {
            amplitude?.apply { (ext) in
                if let validExt = ext as? IOSLifecycle {
                    validExt.applicationDidEnterBackground(application: application)
                }
            }
        }

        func applicationDidFinishLaunchingNotification(notification: NSNotification) {
            amplitude?.apply { (ext) in
                if let validExt = ext as? IOSLifecycle {
                    validExt.applicationDidFinishLaunchingNotification(application: application)
                }
            }
        }
    }

    extension AmplitudeDestinationPlugin: IOSLifecycle {
        public func applicationWillEnterForeground(application: UIApplication?) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
            if self.amplitude?.configuration.defaultTracking.appLifecycles == true {
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

        public func applicationDidEnterBackground(application: UIApplication?) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onExitForeground(timestamp: timestamp)
            if self.amplitude?.configuration.defaultTracking.appLifecycles == true {
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
            }
        }

        public func applicationDidFinishLaunchingNotification(application: UIApplication?) {
            let info = Bundle.main.infoDictionary
            let currentBuild = info?["CFBundleVersion"] as? String
            let currentVersion = info?["CFBundleShortVersionString"] as? String
            let previousBuild: String? = amplitude?.storage.read(key: StorageKey.APP_BUILD)
            let previousVersion: String? = amplitude?.storage.read(key: StorageKey.APP_VERSION)

            if self.amplitude?.configuration.defaultTracking.appLifecycles == true {
                let lastEventTime: Int64? = amplitude?.storage.read(key: StorageKey.LAST_EVENT_TIME)
                if lastEventTime == nil {
                    self.amplitude?.track(eventType: Constants.AMP_APPLICATION_INSTALLED_EVENT, eventProperties: [
                        Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                        Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                    ])
                } else if currentBuild != previousBuild {
                    self.amplitude?.track(eventType: Constants.AMP_APPLICATION_UPDATED_EVENT, eventProperties: [
                        Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                        Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                        Constants.AMP_APP_PREVIOUS_BUILD_PROPERTY: previousBuild ?? "",
                        Constants.AMP_APP_PREVIOUS_VERSION_PROPERTY: previousVersion ?? "",
                    ])
                }
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_OPENED_EVENT, eventProperties: [
                    Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                    Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                    Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false,
                ])
            }

            if currentBuild != previousBuild {
                try? amplitude?.storage.write(key: StorageKey.APP_BUILD, value: currentBuild)
            }
            if currentVersion != previousVersion {
                try? amplitude?.storage.write(key: StorageKey.APP_VERSION, value: currentVersion)
            }
        }
    }

#endif
