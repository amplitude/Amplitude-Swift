//
//  iOSAppClipApp.swift
//  iOSAppClip
//
//  Created by Marvin Liu on 12/15/22.
//

import SwiftUI
import AmplitudeSwift

@main
struct iOSAppClipApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension Amplitude {
    static var testInstance = Amplitude(
        configuration: Configuration(
            apiKey: "TEST-API-KEY",
            logLevel: LogLevelEnum.debug,
            callback: { (event: BaseEvent, code: Int, message: String) -> Void in
                print("eventcallback: \(event), code: \(code), message: \(message)")
            },
            trackingOptions: TrackingOptions().disableTrackDMA(),
            flushEventsOnClose: true,
            minTimeBetweenSessionsMillis: 15000
        )
    )
}
