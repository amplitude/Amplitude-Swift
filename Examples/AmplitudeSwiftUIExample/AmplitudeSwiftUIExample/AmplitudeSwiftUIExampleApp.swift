//
//  AmplitudeSwiftUIExampleApp.swift
//  AmplitudeSwiftUIExample
//
//  Created by Hao Yu on 11/30/22.
//

import AmplitudeSwift
import AppTrackingTransparency
import Experiment
import SwiftUI

@main
struct AmplitudeSwiftUIExampleApp: App {
    let persistenceController = PersistenceController.shared

    // Overriding the initializer in the App in order to config amplitude
    init() {
        Amplitude.testInstance.add(plugin: IDFACollectionPlugin())
        Amplitude.testInstance.add(plugin: LocationPlugin())
        // add the trouble shooting plugin for debugging
        Amplitude.testInstance.add(plugin: TroubleShootingPlugin())
        Amplitude.testInstance.add(plugin: FilterPlugin())

        Amplitude.experimentClient.fetch(user: nil, completion: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    let status = ATTrackingManager.trackingAuthorizationStatus
                    if status == .notDetermined {
                        askForPermission()
                    }
                }
        }
    }

    func askForPermission() {
        // Popup modal to request the tracking autorization
        ATTrackingManager.requestTrackingAuthorization { status in
            // send a track event that shows the results of asking the user for permission.
            Amplitude.testInstance.track(
                event: BaseEvent(
                    eventType: "Ask For IDFA permission",
                    eventProperties: ["status": statusToString(status)]
                )
            )
        }
    }

    func statusToString(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        var result = "unknown"
        switch status {
        case .notDetermined:
            result = "notDetermined"
        case .restricted:
            result = "restricted"
        case .denied:
            result = "denied"
        case .authorized:
            result = "authorized"
        @unknown default:
            break
        }
        return result
    }
}

extension Amplitude {
    static var testInstance = Amplitude(
        configuration: Configuration(
            apiKey: "TEST-API-KEY",
            logLevel: LogLevelEnum.DEBUG,
            callback: { (event: BaseEvent, code: Int, message: String) -> Void in
                print("eventcallback: \(event), code: \(code), message: \(message)")
            },
            trackingOptions: TrackingOptions().disableTrackCarrier().disableTrackDMA(),
            flushEventsOnClose: true,
            minTimeBetweenSessionsMillis: 15000
        )
    )

    static var experimentClient = Experiment.initializeWithAmplitudeAnalytics(
        apiKey: "TEST-EXPERIMENT-KEY",
        config: ExperimentConfigBuilder()
            .instanceName(testInstance.configuration.instanceName)
            .build()
    )
}
