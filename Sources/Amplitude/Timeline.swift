//
//  Timeline.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Timeline : TimelineBase {
    public var amplitude: Amplitude?
    
    internal let plugins: [PluginType: Mediator]
    var sessionId: Int64 = -1
    var lastEventId: Int64 = 0
    var lastEventTime: Int64 = -1
    
    init() {
        self.plugins = [
            PluginType.before: Mediator(),
            PluginType.enrichment: Mediator(),
            PluginType.destination: Mediator(),
            PluginType.utility: Mediator(),
        ]
    }
    
    func start(amplitude: Amplitude) {
        Task {
            sessionId = await amplitude.storage.read(key: .PREVIOUS_SESSION_ID) ?? -1
            lastEventId = await amplitude.storage.read(key: .LAST_EVENT_ID) ?? -1
            lastEventTime = await amplitude.storage.read(key: .LAST_EVENT_TIME) ?? -1
            self.amplitude = amplitude
        }
    }

    func process(event: BaseEvent) async {
            let eventTimeStamp = event.timestamp!
            var skipEvent : Bool = false
            var sessionEvents: Array<BaseEvent>? = nil
            
            if event.eventType == Constants.AMP_SESSION_START_EVENT {
                if (event.sessionId! < 0) {
                    skipEvent = true
                    sessionEvents = await self.amplitude?.startOrContinueSession(timestamp: eventTimeStamp)
                } else {
                    _ = self.amplitude?.setSessionId(sessionId: eventTimeStamp)
                    await self.amplitude?.refreshSessionTime(timestamp: eventTimeStamp)
                }
            } else if event.eventType == Constants.AMP_SESSION_END_EVENT {
                // do nothing
            } else {
                if (!(self.amplitude?._inForeground ?? false)) {
                    sessionEvents = await self.amplitude?.startOrContinueSession(timestamp: eventTimeStamp)
                } else {
                    _ = await self.amplitude?.refreshSessionTime(timestamp: eventTimeStamp)
                }
            }
            
            if (!skipEvent && event.sessionId! < 0) {
                event.sessionId = sessionId
            }
            
            let savedLastEventId = lastEventId
            
            sessionEvents?.forEach({ sessionEvent in
                if sessionEvent.eventId == nil {
                    let newEventId = lastEventId + 1
                    sessionEvent.eventId = newEventId
                    lastEventId = newEventId
                }
            })
            
            if (!skipEvent) {
                let newEventId = lastEventId + 1
                event.eventId = newEventId
                lastEventId = newEventId
            }
            
            if (lastEventId > savedLastEventId) {
                do {
                    _ = try? await self.amplitude?.storage.write(key: .LAST_EVENT_ID, value: lastEventId)
                }
            }
        
            sessionEvents?.forEach({ sessionEvent in
                self.processEvent(event: sessionEvent)
            })
            
            if (!skipEvent) {
                processEvent(event: event)
            }
    }
    
    func processEvent(event: BaseEvent) {
        let beforeResult = self.applyPlugin(pluginType: PluginType.before, event: event)
        let enrichmentResult = self.applyPlugin(pluginType: PluginType.enrichment, event: beforeResult)
        _ = self.applyPlugin(pluginType: PluginType.destination, event: enrichmentResult)
    }

    internal func applyPlugin(pluginType: PluginType, event: BaseEvent?) -> BaseEvent? {
        var result: BaseEvent? = event
        if let mediator = plugins[pluginType] {
            result = mediator.execute(event: event!)
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

    internal func applyClosure(_ closure: (Plugin) -> Void) {
        for plugin in plugins {
            let mediator = plugin.value
            mediator.applyClosure(closure)
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
}
