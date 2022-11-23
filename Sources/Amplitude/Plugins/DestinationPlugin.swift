//
//  DestinationPlugin.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

public protocol DestinationPlugin: EventPlugin {
    var timeline: Timeline { get }
}

extension DestinationPlugin {

    var enabled: Bool {
        return true
    }

    var logger: (any Logger)? {
        return self.amplitude?.logger
    }

    @discardableResult
    func add(plugin: Plugin) -> Plugin {
        plugin.amplitude = self.amplitude
        timeline.add(plugin: plugin)
        return plugin
    }

    func remove(plugin: Plugin) {
        timeline.remove(plugin: plugin)
    }

    func process(event: BaseEvent?) -> BaseEvent? {
        // Skip this destination if it is disabled via settings
        if !enabled {
            return nil
        }
        let beforeResult = timeline.applyPlugin(pluginType: .before, event: event)
        let enrichmentResult = timeline.applyPlugin(pluginType: .enrichment, event: beforeResult)
        var destinationResult: BaseEvent?
        switch enrichmentResult {
        case let e as IdentifyEvent:
            destinationResult = identify(event: e)
        case let e as GroupIdentifyEvent:
            destinationResult = track(event: e)
        case let e as RevenueEvent:
            destinationResult = revenue(event: e)
        case let e?:
            destinationResult = track(event: e)
        default:
            break
        }
        return destinationResult
    }

    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }
}
