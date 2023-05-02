//
//  WatchOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/17/22.
//

#if os(watchOS)

    import Foundation
    import WatchKit

    public protocol WatchOSLifecycle {
        func applicationWillEnterForeground(watchExtension: WKExtension)
        func applicationDidEnterBackground(watchExtension: WKExtension)
    }

    extension WatchOSLifecycle {
        public func applicationWillEnterForeground(watchExtension: WKExtension) {}
        public func applicationDidEnterBackground(watchExtension: WKExtension) {}
    }

    class WatchOSLifecycleMonitor: Plugin {
        weak var amplitude: Amplitude?

        let type = PluginType.utility
        var wasBackgrounded: Bool = false

        private var watchExtension = WKExtension.shared()
        private var appNotifications: [NSNotification.Name] = [
            WKExtension.applicationWillEnterForegroundNotification,
            WKExtension.applicationDidEnterBackgroundNotification,
        ]

        required init() {
            watchExtension = WKExtension.shared()
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

            amplitude?.apply { (ext) in
                if let validExt = ext as? WatchOSLifecycle {
                    validExt.applicationWillEnterForeground(watchExtension: watchExtension)
                }
            }
        }

        func applicationDidEnterBackground(notification: NSNotification) {
            // make sure to denote that we were backgrounded.
            wasBackgrounded = true

            amplitude?.apply { (ext) in
                if let validExt = ext as? WatchOSLifecycle {
                    validExt.applicationDidEnterBackground(watchExtension: watchExtension)
                }
            }
        }
    }

    extension AmplitudeDestinationPlugin: WatchOSLifecycle {
        public func applicationWillEnterForeground(watchExtension: WKExtension) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
        }

        public func applicationDidEnterBackground(watchExtension: WKExtension) {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onExitForeground(timestamp: timestamp)
        }
    }

#endif
