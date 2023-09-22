//
//  TroubleShootingPlugin.swift
//  AmplitudeSwiftUIExample
//
//  Created by Alyssa.Yu on 6/27/23.
//

import Foundation
import AmplitudeSwift

class TroubleShootingPlugin: DestinationPlugin {
    open override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        let apiKey = amplitude.configuration.apiKey;
        let serverZone = amplitude.configuration.serverZone.rawValue;
        let serverUrl = amplitude.configuration.serverUrl ?? "null";

        self.amplitude?.logger?.debug(message: "Current Configuration : {\"apiKey\": "+apiKey+", \"serverZone\": "+serverZone.rawValue+", \"serverUrl\": "+serverUrl+"}")
    }

    open override func track(event: BaseEvent) -> BaseEvent? {
        let jsonEncoder = JSONEncoder()
        let eventJsonData = try! jsonEncoder.encode(event)
        let eventJson = String(data: eventJsonData, encoding: String.Encoding.utf8)

        self.amplitude?.logger?.debug(message: "Processed event: \(String(describing: eventJson))")
        return event
    }
}
