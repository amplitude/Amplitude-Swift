import Foundation

public class Sessions {
    private let configuration: Configuration
    private let storage: Storage
    private let logger: (any Logger)?
    private let timeline: Timeline
    private var _sessionId: Int64 = -1
    private(set) var sessionId: Int64 {
        get {
            sessionIdLock.withLock {
                _sessionId
            }
        }
        set {
            sessionIdLock.withLock {
                _sessionId = newValue
            }
            do {
                try storage.write(key: StorageKey.PREVIOUS_SESSION_ID, value: _sessionId)
            } catch {
                logger?.warn(message: "Can't write PREVIOUS_SESSION_ID to storage: \(error)")
            }
            timeline.apply {
                $0.onSessionIdChanged(_sessionId)
            }
        }
    }
    private let sessionIdLock = NSLock()

    private var _lastEventId: Int64 = 0
    private(set) var lastEventId: Int64 {
        get { _lastEventId }
        set {
            _lastEventId = newValue
            do {
                try storage.write(key: StorageKey.LAST_EVENT_ID, value: _lastEventId)
            } catch {
                logger?.warn(message: "Can't write LAST_EVENT_ID to storage: \(error)")
            }
        }
    }

    private var _lastEventTime: Int64 = -1
    var lastEventTime: Int64 {
        get { _lastEventTime }
        set {
            _lastEventTime = newValue
            do {
                try storage.write(key: StorageKey.LAST_EVENT_TIME, value: _lastEventTime)
            } catch {
                logger?.warn(message: "Can't write LAST_EVENT_TIME to storage: \(error)")
            }
        }
    }

    init(amplitude: Amplitude) {
        configuration = amplitude.configuration
        storage = amplitude.storage
        logger = amplitude.logger
        timeline = amplitude.timeline
        self._sessionId = amplitude.storage.read(key: .PREVIOUS_SESSION_ID) ?? -1
        self._lastEventId = amplitude.storage.read(key: .LAST_EVENT_ID) ?? 0
        self._lastEventTime = amplitude.storage.read(key: .LAST_EVENT_TIME) ?? -1
    }

    func processEvent(event: BaseEvent, inForeground: Bool) -> [BaseEvent] {
        event.timestamp = event.timestamp ?? Int64(NSDate().timeIntervalSince1970 * 1000)
        let eventTimeStamp = event.timestamp!
        var skipEvent: Bool = false
        var sessionEvents: [BaseEvent]?

        if event.eventType == Constants.AMP_SESSION_START_EVENT {
            if event.sessionId == nil { // dummy start_session event
                skipEvent = true
                sessionEvents = self.startNewSessionIfNeeded(timestamp: eventTimeStamp, inForeground: inForeground)
            } else {
                self.sessionId = event.sessionId!
                self.lastEventTime = eventTimeStamp
            }
        } else if event.eventType == Constants.AMP_SESSION_END_EVENT {
            // do nothing
        } else {
            sessionEvents = self.startNewSessionIfNeeded(timestamp: eventTimeStamp, inForeground: inForeground)
        }

        if !skipEvent && event.sessionId == nil {
            event.sessionId = self.sessionId
        }

        var result: [BaseEvent] = []
        if let sessionEvents {
            result.append(contentsOf: sessionEvents)
        }
        if !skipEvent {
            result.append(event)
        }

        return assignEventId(events: result)
    }

    func assignEventId(events: [BaseEvent]) -> [BaseEvent] {
        var newLastEventId = self.lastEventId

        events.forEach({ event in
            if event.eventId == nil {
                newLastEventId += 1
                event.eventId = newLastEventId
            }
        })

        self.lastEventId = newLastEventId

        return events
    }

    private func isWithinMinTimeBetweenSessions(timestamp: Int64) -> Bool {
        let timeDelta = timestamp - self.lastEventTime
        return timeDelta < configuration.minTimeBetweenSessionsMillis
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
        let trackingSessionEvents = configuration.autocapture.contains(.sessions)

        // end previous session
        if trackingSessionEvents && self.sessionId >= 0 {
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
        if trackingSessionEvents {
            let sessionStartEvent = BaseEvent(
                timestamp: timestamp,
                sessionId: timestamp,
                eventType: Constants.AMP_SESSION_START_EVENT
            )
            sessionEvents.append(sessionStartEvent)
        }

        return sessionEvents
    }

    public func endCurrentSession() -> [BaseEvent] {
        var sessionEvents: [BaseEvent] = Array()
        let trackingSessionEvents = configuration.autocapture.contains(.sessions)

        if trackingSessionEvents && self.sessionId >= 0 {
            let sessionEndEvent = BaseEvent(
                timestamp: self.lastEventTime > 0 ? self.lastEventTime : nil,
                sessionId: self.sessionId,
                eventType: Constants.AMP_SESSION_END_EVENT
            )
            sessionEvents.append(sessionEndEvent)
        }

        self.sessionId = -1
        return sessionEvents
    }
}
