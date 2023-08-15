//
//  ContentView.swift
//  iOSAppClip
//
//  Created by Marvin Liu on 12/15/22.
//

import SwiftUI
import AmplitudeSwift

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button(action: {
                print("Send event")
                Amplitude.testInstance.setUserId(userId: "test-user")
                Amplitude.testInstance.track(eventType: "ios-app-clip")
            }) {
                Text("Send Event")
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
