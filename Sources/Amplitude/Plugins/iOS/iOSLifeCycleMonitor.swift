//
//  iOSLifeCycleMonitor.swift
//  
//
//  Created by Hao Yu on 11/15/22.
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Foundation
import UIKit

public protocol iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication?)
    func applicationWillEnterForeground(application: UIApplication?)
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
}

public extension iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication?) { }
    func applicationWillEnterForeground(application: UIApplication?) { }
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) { }
}

class iOSLifecycleMonitor: Plugin {
    weak var amplitude: Amplitude?
    
    let type = PluginType.utility
    
    private var application: UIApplication? = nil
    private var appNotifications: [NSNotification.Name] = [UIApplication.didEnterBackgroundNotification,
                                                           UIApplication.willEnterForegroundNotification]

    required init() {
        // App extensions can't use UIAppication.shared, so
        // funnel it through something to check; Could be nil.
        application = UIApplication.safeShared
        setupListeners()
    }
    
    @objc
    func notificationResponse(notification: NSNotification) {
        switch (notification.name) {
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
            notificationCenter.addObserver(self, selector: #selector(notificationResponse(notification:)), name: notification, object: application)
        }

    }
    
    func applicationWillEnterForeground(notification: NSNotification) {
        amplitude?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillEnterForeground(application: application)
            }
        }
    }
    
    func didEnterBackground(notification: NSNotification) {
        amplitude?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidEnterBackground(application: application)
            }
        }
    }
    
   
}

extension AmplitudeDestinationPlugin: iOSLifecycle {
    public func applicationWillEnterForeground(application: UIApplication?) {
        let timestamp = NSDate().timeIntervalSince1970
        self.amplitude?.onEnterForeground(timestamp: timestamp)
    }
    
    public func applicationDidEnterBackground(application: UIApplication?) {
        self.amplitude?.onExitForeground()
    }
}

extension UIApplication {
    static var safeShared: UIApplication? {
        return nil
    }
}

#endif
