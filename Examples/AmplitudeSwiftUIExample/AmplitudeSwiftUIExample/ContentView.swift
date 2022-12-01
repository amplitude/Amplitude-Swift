//
//  ContentView.swift
//  AmplitudeSwiftUIExample
//
//  Created by Hao Yu on 11/30/22.
//

import SwiftUI
import CoreData
import Amplitude_Swift

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var userId: String = ""
    @State var deviceId: String = "xxx-xxx-xxx"
    @State var isPrivate: Bool = true
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("IDENTITY")) {
                    TextField("UserId", text: $userId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                       Text("Set UserId")
                    }.buttonStyle(AmplitudeButton())

                    TextField("DeviceId", text: $deviceId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                        Text("Regenerate DeviceId")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(AmplitudeButton())
                }
                Section(header: Text("GENERAL EVENT")) {
                    TextField("Event Name", text: $userId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                       Text("Send Event")
                    }.buttonStyle(AmplitudeButton())
                }
                Section(header: Text("REVENUE EVENT")) {
                    TextField("Product Id", text: $userId)
                    TextField("Price", text: $userId)
                    TextField("Quantity", text: $userId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                       Text("Send Revenue Event")
                    }.buttonStyle(AmplitudeButton())
                }
                Section(header: Text("IDENTIFY")) {
                    TextField("User Property Key", text: $userId)
                    TextField("User Property Value", text: $userId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                       Text("Send Identify Event")
                    }.buttonStyle(AmplitudeButton())
                }
                Section(header: Text("GROUP IDENTIFY")) {
                    TextField("Group Type", text: $userId)
                    TextField("Group Property", text: $userId)
                    TextField("User Property Key", text: $userId)
                    TextField("User Property Value", text: $userId)
                    Button(action: {
                        print("Perform an action here...")
                    }) {
                       Text("Send Group Identify Event")
                    }.buttonStyle(AmplitudeButton())
                }
                Button(action: {
                    print("Perform an action here...")
                }) {
                    Text("Flush All Events")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(AmplitudeButton())

            }
            .navigationBarTitle("Amplitude Example")
        }
    }
}


struct AmplitudeButton: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(Color(red: 0.16, green: 0.46, blue: 0.87))
            .foregroundColor(.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
