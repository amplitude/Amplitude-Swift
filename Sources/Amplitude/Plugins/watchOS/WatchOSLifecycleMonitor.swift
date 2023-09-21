//
//  WatchOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/17/22.
//

#if os(watchOS)

    import Foundation
    import WatchKit

    class WatchOSLifecycleMonitor: UtilityPlugin {
        var wasBackgrounded: Bool = false

        private var watchExtension = WKExtension.shared()
        private var appNotifications: [NSNotification.Name] = [
            WKExtension.applicationWillEnterForegroundNotification,
            WKExtension.applicationDidEnterBackgroundNotification,
        ]

        override init() {
            watchExtension = WKExtension.shared()
            super.init()
            setupListeners()
        }

        @objc
        func notificationResponse(notification: NSNotification) {
            switch notification.name {
            case WKExtension.applicationWillEnterForegroundNotification:
                self.applicationWillEnterForeground(notification: notification)
            case WKExtension.applicationDidEnterBackgroundNotification:
                self.applicationDidEnterBackground(notification: notification)
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
                    object: nil
                )
            }
        }

        func applicationWillEnterForeground(notification: NSNotification) {
            // watchOS will receive this after didFinishLaunching, which is different
            // from iOS, so ignore until we've been backgrounded at least once.
            if wasBackgrounded == false { return }

            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
        }

        func applicationDidEnterBackground(notification: NSNotification) {
            // make sure to denote that we were backgrounded.
            wasBackgrounded = true

            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onExitForeground(timestamp: timestamp)
        }
    }

#endif
