//
//  AmplitudeSwiftUIExampleApp.swift
//  AmplitudeSwiftUIExample
//
//  Created by Hao Yu on 11/30/22.
//

import Amplitude_Swift
import SwiftUI

@main
struct AmplitudeSwiftUIExampleApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

extension Amplitude {
    static var main = Amplitude(configuration: Configuration(apiKey: "TEST-API-KEY"))
}
