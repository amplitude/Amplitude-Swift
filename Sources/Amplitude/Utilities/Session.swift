//
//  Session.swift
//
//
//  Created by Alyssa.Yu on 12/2/22.
//

import Foundation

extension Amplitude {
    private func isWithinMinTimeBetweenSessions(timestamp: Int64) -> Bool {
        guard let lastEventTime: Int64 = self.storage.read(key: .LAST_EVENT_TIME) else { return false }
        let timeDelta = timestamp - lastEventTime
        return timeDelta < self.configuration.minTimeBetweenSessionsMillis

    }

    public func refreshSessionTime(timestamp: Int64) {
        do {
            try self.storage.write(key: .LAST_EVENT_TIME, value: timestamp)
        } catch {
            print("User creation failed with error: \(error)")
        }
    }

    private func getPreviouSession() -> Int64? {
        guard let previousSession: Int64 = self.storage.read(key: StorageKey.PREVIOUS_SESSION_ID) else { return nil }

        return previousSession
    }

    private func getLastEventTime() -> Int64? {
        guard let lastEventTime: Int64 = self.storage.read(key: StorageKey.LAST_EVENT_TIME) else { return nil }

        return lastEventTime
    }

    private func sendSessionEvent(sessionEventType: String) {
        let timestamp = self.getLastEventTime()
        let sessionEvent = BaseEvent(timestamp: timestamp, eventType: sessionEventType)
        self.track(event: sessionEvent)
    }

    public func startOrContinueSession(timestamp: Int64) -> [BaseEvent]? {
        if _sessionId >= 0 {
            // if with in the same session extend the session and update the session time
            if self.isWithinMinTimeBetweenSessions(timestamp: timestamp) == true {
                self.refreshSessionTime(timestamp: timestamp)
                return nil
            }
        }

        return startNewSession(timestamp: timestamp)
    }

    public func startNewSession(timestamp: Int64) -> [BaseEvent]? {

        var sessionEvents: [BaseEvent] = Array()

        if self.configuration.trackingSessionEvents == true && _sessionId >= 0 {
            let lastEventTime: Int64? = self.storage.read(key: .LAST_EVENT_TIME) ?? nil
            let sessionEndEvent = BaseEvent(
                timestamp: lastEventTime,
                sessionId: _sessionId,
                eventType: Constants.AMP_SESSION_END_EVENT
            )
            sessionEvents.append(sessionEndEvent)

        }

        // start new session
        _ = self.setSessionId(sessionId: timestamp)
        self.refreshSessionTime(timestamp: timestamp)

        if self.configuration.trackingSessionEvents == true {
            let lastEventTime: Int64? = self.storage.read(key: .LAST_EVENT_TIME) ?? nil
            let sessionStartEvent = BaseEvent(
                timestamp: lastEventTime,
                sessionId: _sessionId,
                eventType: Constants.AMP_SESSION_START_EVENT
            )
            sessionEvents.append(sessionStartEvent)
        }

        return sessionEvents
    }
}
