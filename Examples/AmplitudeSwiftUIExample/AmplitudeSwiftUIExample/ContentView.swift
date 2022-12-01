//
//  ContentView.swift
//  AmplitudeSwiftUIExample
//
//  Created by Hao Yu on 11/30/22.
//

import Amplitude_Swift
import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var userId: String = ""
    // TODO: get current deviceId
    @State var deviceId: String = "xxx-xxx-xxx"
    @State var eventType: String = ""
    @State var productId: String = ""
    @State var price: Double = 0.00
    @State var quantity: Int = 1
    @State var userPropertyKey = ""
    @State var userPropertyValue = ""
    @State var groupType = ""
    @State var groupProperty = ""
    @State var groupUserPropertyKey = ""
    @State var groupUserPropertyValue = ""

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("IDENTITY")) {
                        HStack {
                            TextField("UserId", text: $userId)
                            Button(action: {
                                _ = Amplitude.main.setUserId(userId: userId)
                            }) {
                                Text("Set UserId")
                            }.buttonStyle(AmplitudeButton())
                        }
                        HStack {
                            TextField("DeviceId", text: $deviceId)
                            Button(action: {
                                _ = Amplitude.main.setDeviceId(deviceId: deviceId)
                            }) {
                                Text("Reset DeviceId")
                            }.buttonStyle(AmplitudeButton())

                        }
                    }
                    Section(header: Text("GENERAL EVENT")) {
                        HStack {
                            TextField("Event Name", text: $eventType)
                            Button(action: {
                                let event = BaseEvent(eventType: eventType)
                                _ = Amplitude.main.track(event: event)
                            }) {
                                Text("Send Event")
                            }.buttonStyle(AmplitudeButton())

                        }
                    }
                    Section(header: Text("REVENUE EVENT")) {
                        TextField("Product Id", text: $productId)
                        TextField("Price", value: $price, formatter: decimalFormatter())
                        TextField("Quantity", value: $quantity, formatter: NumberFormatter())
                        Button(action: {
                            // TODO: trigger revenue event
                        }) {
                            Text("Send Revenue Event")
                        }.buttonStyle(AmplitudeButton())
                    }
                    Section(header: Text("IDENTIFY")) {
                        HStack {
                            TextField("User Property Key", text: $userPropertyKey)
                            TextField("User Property Value", text: $userPropertyValue)
                        }
                        Button(action: {
                            // TODO: trigger identify event
                        }) {
                            Text("Send Identify Event")
                        }.buttonStyle(AmplitudeButton())
                    }
                    Section(header: Text("GROUP IDENTIFY")) {
                        HStack {
                            TextField("Group Type", text: $groupType)
                            TextField("Group Property", text: $groupProperty)
                        }
                        HStack {
                            TextField("User Property Key", text: $groupUserPropertyKey)
                            TextField("User Property Value", text: $groupUserPropertyValue)
                        }
                        Button(action: {
                            // TODO: trigger group identify event
                        }) {
                            Text("Send Group Identify Event")
                        }.buttonStyle(AmplitudeButton())
                    }
                    Button(action: {
                        _ = Amplitude.main.flush()
                    }) {
                        Text("Flush All Events")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(AmplitudeButton())

                }
                .navigationBarTitle("Amplitude Example")
            }
        }
    }
}

func decimalFormatter() -> NumberFormatter {
    let decimalFormatter = NumberFormatter()
    decimalFormatter.numberStyle = .decimal
    decimalFormatter.minimumFractionDigits = 2
    return decimalFormatter
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
