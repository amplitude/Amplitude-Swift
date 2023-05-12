//
//  MacOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/17/22.
//

#if os(macOS)
    import Cocoa

    public protocol MacOSLifecycle {
        func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?)
        func applicationDidBecomeActive()
        func applicationWillResignActive()
    }

    extension MacOSLifecycle {
        public func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?) {}
        public func applicationDidBecomeActive() {}
        public func applicationWillResignActive() {}
    }

    class MacOSLifecycleMonitor: Plugin {

        weak var amplitude: Amplitude?

        let type = PluginType.utility

        private var application: NSApplication
        private var appNotifications: [NSNotification.Name] =
            [
                NSApplication.didBecomeActiveNotification,
                NSApplication.willResignActiveNotification,
            ]

        required init() {
            self.application = NSApplication.shared
            setupListeners()
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

        func applicationDidBecomeActive(notification: NSNotification) {
            amplitude?.apply { (ext) in
                if let validExt = ext as? MacOSLifecycle {
                    validExt.applicationDidBecomeActive()
                }
            }
        }

        func applicationWillResignActive(notification: NSNotification) {
            amplitude?.apply { (ext) in
                if let validExt = ext as? MacOSLifecycle {
                    validExt.applicationWillResignActive()
                }
            }
        }
    }

    extension AmplitudeDestinationPlugin: MacOSLifecycle {
        public func applicationDidBecomeActive() {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onEnterForeground(timestamp: timestamp)
        }

        public func applicationWillResignActive() {
            let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
            self.amplitude?.onExitForeground(timestamp: timestamp)
        }
    }

#endif
