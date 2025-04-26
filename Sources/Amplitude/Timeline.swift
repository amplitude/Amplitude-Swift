//
//  Timeline.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import AmplitudeCore
import Foundation

public class Timeline {
    internal let plugins: [PluginType: Mediator]
    private var pluginsByName: [String: UniversalPlugin] = [:]

    init() {
        self.plugins = [
            PluginType.before: Mediator(),
            PluginType.enrichment: Mediator(),
            PluginType.destination: Mediator(),
            PluginType.utility: Mediator(),
            PluginType.observe: Mediator(),
        ]
    }

    func processEvent(event: BaseEvent) {
        let beforeResult = self.applyPlugin(pluginType: PluginType.before, event: event)
        let enrichmentResult = self.applyPlugin(pluginType: PluginType.enrichment, event: beforeResult)
        _ = self.applyPlugin(pluginType: PluginType.destination, event: enrichmentResult)
    }

    internal func applyPlugin(pluginType: PluginType, event: BaseEvent?) -> BaseEvent? {
        var result: BaseEvent? = event
        if let mediator = plugins[pluginType] {
            result = mediator.execute(event: event)
        }
        return result
    }

    internal func add(plugin: UniversalPlugin) {
        if let name = plugin.name {
            if pluginsByName[name] != nil {
                return
            }
            pluginsByName[name] = plugin
        }
        let pluginType: PluginType
        switch plugin {
        case let plugin as Plugin:
            pluginType = plugin.type
        default:
            pluginType = .enrichment
        }
        if let mediator = plugins[pluginType] {
            mediator.add(plugin: plugin)
        }
    }

    internal func remove(plugin: UniversalPlugin) {
        // remove all plugins with this name in every category
        for _plugin in plugins {
            let list = _plugin.value
            list.remove(plugin: plugin)
        }

        if let name = plugin.name {
            pluginsByName[name] = nil
        }
    }

    internal func apply(_ closure: (UniversalPlugin) -> Void) {
        for type in PluginType.allCases {
            if let plugins = plugins[type]?.plugins {
                plugins.forEach { (plugin) in
                    closure(plugin)
                    if let destPlugin = plugin as? DestinationPlugin {
                        destPlugin.apply(closure: closure)
                    }
                }
            }
        }
    }

    func plugin(name: String) -> UniversalPlugin? {
        return pluginsByName[name]
    }
}
