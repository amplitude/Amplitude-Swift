//
//  WatchOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/17/22.
//

#if os(watchOS)

    import Foundation
    import WatchKit

    class WatchOSLifecycleMonitor: ApplicationLifecycle {
        private var appNotifications: [NSNotification.Name] = [
            WKExtension.applicationWillEnterForegroundNotification,
            WKExtension.applicationDidEnterBackgroundNotification,
        ]

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

        override func startObserving() {
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
            enterForeground()
        }

        func applicationDidEnterBackground(notification: NSNotification) {
            enterBackground()
        }
    }

#endif
