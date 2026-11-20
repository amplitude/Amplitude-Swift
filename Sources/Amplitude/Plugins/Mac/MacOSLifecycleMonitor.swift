//
//  MacOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/17/22.
//

#if os(macOS)
    import Cocoa

    class MacOSLifecycleMonitor: ApplicationLifecycle {
        private var application: NSApplication
        private var appNotifications: [NSNotification.Name] =
            [
                NSApplication.didBecomeActiveNotification,
                NSApplication.willResignActiveNotification,
            ]

        override init() {
            self.application = NSApplication.shared
            super.init()
        }

        @objc
        func notificationResponse(notification: NSNotification) {
            switch notification.name {
            case NSApplication.didBecomeActiveNotification:
                self.applicationDidBecomeActive(notification: notification)
            case NSApplication.willResignActiveNotification:
                self.applicationWillResignActive(notification: notification)
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
                    object: application
                )
            }
        }

        func applicationDidBecomeActive(notification: NSNotification) {
            enterForeground()
        }

        func applicationWillResignActive(notification: NSNotification) {
            enterBackground()
        }
    }

#endif
