//
//  Timeline.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Timeline {
    internal let plugins: [PluginType: Mediator]

    init() {
        self.plugins = [
            PluginType.before: Mediator(),
            PluginType.enrichment: Mediator(),
            PluginType.destination: Mediator(),
            PluginType.utility: Mediator(),
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

    internal func add(plugin: Plugin) {
        if let mediator = plugins[plugin.type] {
            mediator.add(plugin: plugin)
        }
    }

    internal func remove(plugin: Plugin) {
        // remove all plugins with this name in every category
        for _plugin in plugins {
            let list = _plugin.value
            list.remove(plugin: plugin)
        }
    }

    internal func apply(_ closure: (Plugin) -> Void) {
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                mediator.plugins.forEach { (plugin) in
                    closure(plugin)
                    if let destPlugin = plugin as? DestinationPlugin {
                        destPlugin.apply(closure: closure)
                    }
                }
            }
        }
    }

    func onUserIdChanged(_ userId: String?) {
        apply { $0.onUserIdChanged(userId) }
    }

    func onDeviceIdChanged(_ deviceId: String?) {
        apply { $0.onDeviceIdChanged(deviceId) }
    }

    func onSessionIdChanged(_ sessionId: Int64) {
        apply { $0.onSessionIdChanged(sessionId) }
    }

    func onOptOutChanged(_ optOut: Bool) {
        apply { $0.onOptOutChanged(optOut) }
    }
}
