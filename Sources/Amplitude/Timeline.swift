//
//  Timeline.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Timeline {
    private let amplitude: Amplitude
    internal let plugins: [PluginType: Mediator]

    private var _sessionId: Int64 = -1
    private(set) var sessionId: Int64 {
        get { _sessionId }
        set {
            _sessionId = newValue;
            do {
                try amplitude.storage.write(key: StorageKey.PREVIOUS_SESSION_ID, value: _sessionId)
            } catch {
                print("Can't write PREVIOUS_SESSION_ID to storage: \(error)")
            }
        }
    }

    private var _lastEventId: Int64 = 0
    private(set) var lastEventId: Int64 {
        get { _lastEventId }
        set {
            _lastEventId = newValue;
            do {
                try amplitude.storage.write(key: StorageKey.LAST_EVENT_ID, value: _lastEventId)
            } catch {
                print("Can't write LAST_EVENT_ID to storage: \(error)")
            }
        }
    }

    private var _lastEventTime: Int64 = -1
    var lastEventTime: Int64 {
        get { _lastEventTime }
        set {
            _lastEventTime = newValue;
            do {
                try amplitude.storage.write(key: StorageKey.LAST_EVENT_TIME, value: _lastEventTime)
            } catch {
                print("Can't write LAST_EVENT_TIME to storage: \(error)")
            }
        }
    }

    init(amplitude: Amplitude) {
        self.amplitude = amplitude
        self.plugins = [
            PluginType.before: Mediator(),
            PluginType.enrichment: Mediator(),
            PluginType.destination: Mediator(),
            PluginType.utility: Mediator(),
        ]
    }

    func start() {
        self._sessionId = amplitude.storage.read(key: .PREVIOUS_SESSION_ID) ?? -1
        self._lastEventId = amplitude.storage.read(key: .LAST_EVENT_ID) ?? 0
        self._lastEventTime = amplitude.storage.read(key: .LAST_EVENT_TIME) ?? -1
    }

    func process(event: BaseEvent, inForeground: Bool) {
        event.timestamp = event.timestamp ?? Int64(NSDate().timeIntervalSince1970 * 1000)
        let eventTimeStamp = event.timestamp!
        var skipEvent: Bool = false
        var sessionEvents: [BaseEvent]?

        if event.eventType == Constants.AMP_SESSION_START_EVENT {
            if event.sessionId < 0 { // dummy start_session event
                skipEvent = true
                sessionEvents = self.startNewSessionIfNeeded(timestamp: eventTimeStamp, inForeground: inForeground)
            } else {
                self.sessionId = event.sessionId
                self.lastEventTime = eventTimeStamp
            }
        } else if event.eventType == Constants.AMP_SESSION_END_EVENT {
            // do nothing
        } else {
            sessionEvents = self.startNewSessionIfNeeded(timestamp: eventTimeStamp, inForeground: inForeground)
        }

        if !skipEvent && event.sessionId < 0 {
            event.sessionId = self.sessionId
        }

        let currentLastEventId = self.lastEventId
        var newLastEventId = currentLastEventId

        sessionEvents?.forEach({ sessionEvent in
            if sessionEvent.eventId == nil {
                newLastEventId = newLastEventId + 1
                sessionEvent.eventId = newLastEventId
            }
        })

        if !skipEvent {
            if event.eventId == nil {
                newLastEventId = newLastEventId + 1
                event.eventId = newLastEventId
            }
        }

        if newLastEventId > currentLastEventId {
            self.lastEventId = newLastEventId
        }

        sessionEvents?.forEach({ sessionEvent in
            processEvent(event: sessionEvent)
        })

        if !skipEvent {
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
                }
            }
        }
    }

    private func isWithinMinTimeBetweenSessions(timestamp: Int64) -> Bool {
        let timeDelta = timestamp - self.lastEventTime
        return timeDelta < amplitude.configuration.minTimeBetweenSessionsMillis
    }

    public func startNewSessionIfNeeded(timestamp: Int64, inForeground: Bool) -> [BaseEvent]? {
        if self.sessionId >= 0 && (inForeground || isWithinMinTimeBetweenSessions(timestamp: timestamp)) {
            // if with in the same session extend the session and update the session time
            self.lastEventTime = timestamp
            return nil
        }

        return startNewSession(timestamp: timestamp)
    }

    public func startNewSession(timestamp: Int64) -> [BaseEvent] {
        var sessionEvents: [BaseEvent] = Array()
        let trackingSessionEvents = amplitude.configuration.trackingSessionEvents

        // end previous session
        if trackingSessionEvents == true && self.sessionId >= 0 {
            let sessionEndEvent = BaseEvent(
                timestamp: self.lastEventTime > 0 ? self.lastEventTime : nil,
                sessionId: self.sessionId,
                eventType: Constants.AMP_SESSION_END_EVENT
            )
            sessionEvents.append(sessionEndEvent)

        }

        // start new session
        self.sessionId = timestamp
        self.lastEventTime = timestamp
        if trackingSessionEvents == true {
            let sessionStartEvent = BaseEvent(
                timestamp: timestamp,
                sessionId: timestamp,
                eventType: Constants.AMP_SESSION_START_EVENT
            )
            sessionEvents.append(sessionStartEvent)
        }

        return sessionEvents
    }
}
