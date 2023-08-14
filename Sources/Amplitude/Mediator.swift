//
//  Mediator.swift
//
//
//  Created by Hao Yu on 11/9/22.
//

internal class Mediator {
    // create an array with certain type.
    internal var plugins = [Plugin]()

    internal func add(plugin: Plugin) {
        plugins.append(plugin)
    }

    internal func remove(plugin: Plugin) {
        plugins.removeAll { (storedPlugin) -> Bool in
            return storedPlugin === plugin
        }
    }

    internal func execute(event: BaseEvent) -> BaseEvent? {
        var result: BaseEvent? = event
        plugins.forEach { plugin in
            if let r = result {
                if let p = plugin as? DestinationPlugin {
                    _ = p.execute(event: r)
                } else if let p = plugin as? EventPlugin {
                    if let rr = result {
                        if let identifyEvent = rr as? IdentifyEvent {
                            p.identify(event: identifyEvent)
                        } else if let groupIdentifyEvent = rr as? GroupIdentifyEvent {
                            p.groupIdentify(event: groupIdentifyEvent)
                        } else if let revenueEvent = rr as? RevenueEvent {
                            p.revenue(event: revenueEvent)
                        } else {
                            p.track(event: rr)
                        }
                    }
                } else {
                    result = plugin.execute(event: event)
                }
            }
        }
        return result
    }

    internal func applyClosure(_ closure: (Plugin) -> Void) {
        plugins.forEach { plugin in
            closure(plugin)
        }
    }
}
