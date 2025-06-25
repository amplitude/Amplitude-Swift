//
//  IOSLifecycleMonitor.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT

import AmplitudeCore
import Foundation
import SwiftUI

class IOSLifecycleMonitor: UtilityPlugin {

    private var utils: DefaultEventUtils?
    private var sendApplicationOpenedOnDidBecomeActive = false
    private var remoteConfigSubscription: Any?
    private(set) var trackScreenViews = false
    private(set) var trackElementInteractions = false

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidFinishLaunchingNotification(notification:)),
                                               name: UIApplication.didFinishLaunchingNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive(notification:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground(notification:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(notification:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    public override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        utils = DefaultEventUtils(amplitude: amplitude)
        trackScreenViews = amplitude.configuration.autocapture.contains(.screenViews)
        trackElementInteractions = amplitude.configuration.autocapture.contains(.elementInteractions)

        // If we are already in the foreground, dispatch installed / opened events now
        // we want to dispatch this from the initiating thread to maintain event ordering.
        if IOSVendorSystem.applicationState == .active {
            // this is added in init - launch on trackingQueue to allow identity to be set
            // prior to firing the event
            amplitude.trackingQueue.async { [self] in
                utils?.trackAppUpdatedInstalledEvent()
                amplitude.onEnterForeground(timestamp: currentTimestamp)
                utils?.trackAppOpenedEvent()
            }
        }

        updateAutocaptureSetup()

        if amplitude.configuration.enableAutoCaptureRemoteConfig {
            remoteConfigSubscription = amplitude
                .amplitudeContext
                .remoteConfigClient
                .subscribe(key: Constants.RemoteConfig.Key.autocapture) { [weak self] config, _, _ in
                    guard let self, let config else {
                        return
                    }

                    if let pageViews = config["pageViews"] as? Bool {
                        trackScreenViews = pageViews
                    }

                    if let interactions = config["elementInteractions"] as? Bool {
                        trackElementInteractions = interactions
                    }

                    updateAutocaptureSetup()
                }
        }
    }

    private func updateAutocaptureSetup() {
        guard let amplitude else {
            return
        }

        if trackScreenViews {
            UIKitScreenViews.register(amplitude)
        } else {
            UIKitScreenViews.unregister(amplitude)
        }

        // Register UIKitElementInteractions if either element interactions or frustration interactions is enabled
        let needsElementInteractions = trackElementInteractions || amplitude.configuration.autocapture.contains(.frustrationInteractions)
        if needsElementInteractions {
            UIKitElementInteractions.register(amplitude)
        } else {
            UIKitElementInteractions.unregister(amplitude)
        }
    }

    @objc
    func applicationDidFinishLaunchingNotification(notification: Notification) {
        utils?.trackAppUpdatedInstalledEvent()

        // Pre SceneDelegate apps wil not fire a willEnterForeground notification on app launch.
        // Instead, use the initial applicationDidBecomeActive
        if !IOSVendorSystem.usesScenes {
            sendApplicationOpenedOnDidBecomeActive = true
        }
    }

    @objc
    func applicationDidBecomeActive(notification: Notification) {
        guard sendApplicationOpenedOnDidBecomeActive else {
            return
        }
        sendApplicationOpenedOnDidBecomeActive = false

        amplitude?.onEnterForeground(timestamp: currentTimestamp)
        utils?.trackAppOpenedEvent()
    }

    @objc
    func applicationWillEnterForeground(notification: Notification) {
        let fromBackground: Bool
        switch IOSVendorSystem.applicationState {
        case nil, .active, .inactive:
            fromBackground = false
        case .background:
            fromBackground = true
        @unknown default:
            fromBackground = false
        }

        amplitude?.onEnterForeground(timestamp: currentTimestamp)
        utils?.trackAppOpenedEvent(fromBackground: fromBackground)
    }

    @objc
    func applicationDidEnterBackground(notification: Notification) {
        guard let amplitude = amplitude else {
            return
        }
        amplitude.onExitForeground(timestamp: currentTimestamp)
        if amplitude.configuration.autocapture.contains(.appLifecycles) {
            amplitude.track(eventType: Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
        }
    }

    private var currentTimestamp: Int64 {
        return Int64(NSDate().timeIntervalSince1970 * 1000)
    }

    override func teardown() {
        super.teardown()

        if let amplitude {
            if let remoteConfigSubscription {
                amplitude.amplitudeContext.remoteConfigClient.unsubscribe(remoteConfigSubscription)
            }
            UIKitScreenViews.unregister(amplitude)
            UIKitElementInteractions.unregister(amplitude)
        }
    }

    deinit {
        if let amplitude, let remoteConfigSubscription {
            amplitude.amplitudeContext.remoteConfigClient.unsubscribe(remoteConfigSubscription)
        }
    }
}

#endif
