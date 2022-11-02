//
//  File.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class AmplitudeDestinationPlugin: Plugin {
    public var type: PluginType = PluginType.destination

    public var amplitude: Amplitude?

    public func setup(amplitude: Amplitude) {
    }

    public func execute(event: BaseEvent) -> BaseEvent? {
        return event
    }
}
