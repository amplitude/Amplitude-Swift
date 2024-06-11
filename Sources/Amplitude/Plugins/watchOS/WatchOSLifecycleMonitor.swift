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

        var isSingleTargetApplication: Bool {
            return Bundle.main.infoDictionary?.keys.contains("WKApplication") == true
        }

        private var appNotifications: [NSNotification.Name] {
            if #available(watchOS 9.0, *) {
                // `WKApplication` works on both dual-target and single-target apps
                // When running on watchOS 9.0+
                return [
                    WKApplication.willEnterForegroundNotification,
                    WKApplication.didEnterBackgroundNotification
                ]
            } else if !isSingleTargetApplication {
                return [
                    WKExtension.applicationWillEnterForegroundNotification,
                    WKExtension.applicationDidEnterBackgroundNotification
                ]
            } else {
                // Before watchOS 9.0, single-target apps don't allow using `WKExtension` or `WKApplication`
                // So we can't utilize any notifications
                return []
            }
        }

        override init() {
            super.init()
            setupListeners()
        }

        @objc
        func notificationResponse(notification: NSNotification) {
            if #available(watchOS 9.0, *) {
                switch notification.name {
                case WKApplication.willEnterForegroundNotification:
                    self.applicationWillEnterForeground(notification: notification)
                case WKApplication.didEnterBackgroundNotification:
                    self.applicationDidEnterBackground(notification: notification)
                default:
                    break
                }
            } else if !isSingleTargetApplication {
                switch notification.name {
                case WKExtension.applicationWillEnterForegroundNotification:
                    self.applicationWillEnterForeground(notification: notification)
                case WKExtension.applicationDidEnterBackgroundNotification:
                    self.applicationDidEnterBackground(notification: notification)
                default:
                    break
                }
            } else {
                return
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
