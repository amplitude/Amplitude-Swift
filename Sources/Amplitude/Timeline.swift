//
//  File.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Timeline {
    var amplitude: Amplitude
    var plugins = [PluginType: [any Plugin]]()

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func process(event: BaseEvent) {

    }

    func add(plugin: Plugin) {

    }

    func remove(plugin: Plugin) {

    }

    func apply(event: BaseEvent) -> BaseEvent? {
        return event
    }
}
