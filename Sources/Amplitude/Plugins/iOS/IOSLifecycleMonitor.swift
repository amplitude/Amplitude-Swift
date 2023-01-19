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
        func application(
            _ application: UIApplication?,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        )
    }

    extension IOSLifecycle {
        public func applicationDidEnterBackground(application: UIApplication?) {}
        public func applicationWillEnterForeground(application: UIApplication?) {}
        public func application(
            _ application: UIApplication?,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) {}
    }

    class IOSLifecycleMonitor: Plugin {
        weak var amplitude: Amplitude?

        let type = PluginType.utility

        private var application: UIApplication?
        private var appNotifications: [NSNotification.Name] = [
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification,
        ]

        required init() {
            // TODO: Check if lifecycle plugin works for app extension
            // App extensions can't use UIAppication.shared, so
            // funnel it through something to check; Could be nil.
            application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication
            setupListeners()
        }

        @objc
        func notificationResponse(notification: NSNotification) {
            switch notification.name {
            case UIApplication.didEnterBackgroundNotification:
                self.didEnterBackground(notification: notification)
            case UIApplication.willEnterForegroundNotification:
                self.applicationWillEnterForeground(notification: notification)
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
        
        func execute(event: BaseEvent?) -> BaseEvent? {
            return event
        }

        func setup(amplitude: Amplitude) {
            self.amplitude = amplitude
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

    }

    extension AmplitudeDestinationPlugin: IOSLifecycle {
        public func applicationWillEnterForeground(application: UIApplication?) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
        }

        public func applicationDidEnterBackground(application: UIApplication?) {
            self.amplitude?.onExitForeground()
        }
    }

#endif
