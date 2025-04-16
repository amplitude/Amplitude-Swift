//
//  Mediator.swift
//
//
//  Created by Hao Yu on 11/9/22.
//

import AmplitudeCore
import Foundation

internal class Mediator {
    // create an array with certain type.
    internal var plugins = [UniversalPlugin]()
    private let lock = NSLock()

    internal func add(plugin: UniversalPlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugins.append(plugin)
    }

    internal func remove(plugin: UniversalPlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugins.removeAll { (storedPlugin) -> Bool in
            if storedPlugin === plugin {
                storedPlugin.teardown()
                return true
            }
            return false
        }
    }

    internal func execute(event: BaseEvent?) -> BaseEvent? {
        lock.lock()
        defer { lock.unlock() }

        var result: BaseEvent? = event
        plugins.forEach { plugin in
            if var r = result {
                if let p = plugin as? DestinationPlugin {
                    _ = p.execute(event: r)
                } else if let p = plugin as? EventPlugin {
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
                } else if let plugin = plugin as? Plugin {
                    result = plugin.execute(event: r)
                } else {
                    plugin.execute(&r)
                }
            }
        }
        return result
    }

    internal func applyClosure(_ closure: (UniversalPlugin) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        plugins.forEach { plugin in
            closure(plugin)
        }
    }
}
