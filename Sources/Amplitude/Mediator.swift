//
//  File.swift
//  
//
//  Created by Hao Yu on 11/9/22.
//

import Foundation

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
        var result : BaseEvent? = event;
        plugins.forEach { plugin in
            if let r = result {
                if plugin is DestinationPlugin {
                    _ = plugin.execute(event: r)
                } else if let p = plugin as? EventPlugin {
                    result = p.execute(event: r)
                    if let rr = result {
                        if let identifyEvent = rr as? IdentifyEvent {
                            result = p.identify(event: identifyEvent)
                        } else if let groupIdentifyEvent = rr as? GroupIdentifyEvent {
                            result = p.groupIdentify(event: groupIdentifyEvent)
                        } else if let revenueEvent = rr as? RevenueEvent {
                            result = p.revenue(event: revenueEvent)
                        } else {
                            result = p.track(event: rr)
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
