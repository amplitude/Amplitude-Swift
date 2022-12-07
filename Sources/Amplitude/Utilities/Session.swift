//
//  Session.swift
//  
//
//  Created by Alyssa.Yu on 12/2/22.
//

import Foundation

extension Amplitude {
    private func isWithinMinTimeBetweenSessions(timestamp: Int64) async -> Bool {
        guard let lastEventTime: Int64 = await self.storage.read(key: .LAST_EVENT_TIME) else { return false }
        let timeDelta = timestamp - lastEventTime
        return timeDelta < self.configuration.minTimeBetweenSessionsMillis

    }
    
    public func refreshSessionTime(timestamp: Int64) async  {
        do {
            try await self.storage.write(key: .LAST_EVENT_TIME, value: timestamp)
        } catch {
            print("User creation failed with error: \(error)")
        }
    }
    
    private func getPreviouSession() async -> Int64? {
        guard let previousSession: Int64 = await self.storage.read(key: StorageKey.PREVIOUS_SESSION_ID) else { return nil }

        return previousSession
    }
    
    /*private func startNewSession(timestamp: Int64) async {
        if self.configuration.trackingSessionEvents == true {
            await self.sendSessionEvent(sessionEventType: Constants.AMP_SESSION_END_EVENT)
        }
        _ = self.setSessionId(sessionId: timestamp)
        await self.refreshSessionTime(timestamp: timestamp)
        
        if self.configuration.trackingSessionEvents == true {
            await self.sendSessionEvent(sessionEventType: Constants.AMP_SESSION_START_EVENT)
        }
    }*/
    
    private func getLastEventTime() async -> Int64? {
        guard let lastEventTime: Int64 = await self.storage.read(key: StorageKey.LAST_EVENT_TIME) else { return nil }

        return lastEventTime
    }
    
    private func sendSessionEvent(sessionEventType: String) async {
        let timestamp = await self.getLastEventTime()
        let sessionEvent = BaseEvent(timestamp: timestamp, eventType: sessionEventType)
        self.track(event: sessionEvent)
    }
    
    /**
     
     public func startOrContinueSession(timestamp: Int64) async -> Bool {
         // go into background
         if (!_inForeground) {
             // has current session
             if (_sessionId >= 0) {
                 // if with in the same session extend the session and update the session time
                 if await (self.isWithinMinTimeBetweenSessions(timestamp: timestamp)) {
                     await self.refreshSessionTime(timestamp: timestamp)
                     return false
                 }
                 // start a new session if the session expire
                 _ = await self.startNewSession(timestamp: timestamp)
                 return true
             }
             // no current session, but the session not expire, check for previous session
             if await (self.isWithinMinTimeBetweenSessions(timestamp: timestamp)) {
                 // extract previous session id
                 let previousSessionId = await self.getPreviouSession()
                 if previousSessionId == -1 {
                     await self.startNewSession(timestamp: timestamp)
                     return true
                 }
                 // extend previous session
                 _ = self.setSessionId(sessionId: previousSessionId!)
                 await self.refreshSessionTime(timestamp: timestamp)
                 return false
             } else {
                 await self.startNewSession(timestamp:timestamp)
                 return true
             }
         }
         
         await self.refreshSessionTime(timestamp: timestamp)
         return false
     }
     
     */
    public func startOrContinueSession(timestamp: Int64) async ->  Array<BaseEvent>? {
            if (_sessionId >= 0) {
                // if with in the same session extend the session and update the session time
                if await (self.isWithinMinTimeBetweenSessions(timestamp: timestamp)) {
                    await self.refreshSessionTime(timestamp: timestamp)
                    return nil
                }
            }
        
        return await startNewSession(timestamp: timestamp)
    }
    
    public func startNewSession(timestamp: Int64) async -> Array<BaseEvent>? {

        var sessionEvents : Array<BaseEvent> = Array()
        
        if (self.configuration.trackingSessionEvents == true  && _sessionId >= 0) {
            let lastEventTime: Int64? = await self.storage.read(key: .LAST_EVENT_TIME) ?? nil
            let sessionEndEvent = BaseEvent(timestamp: lastEventTime, sessionId: _sessionId, eventType: Constants.AMP_SESSION_END_EVENT)
            sessionEvents.append(sessionEndEvent)

        }

        // start new session
        _ = self.setSessionId(sessionId: timestamp)
        await self.refreshSessionTime(timestamp: timestamp)
        
        if (self.configuration.trackingSessionEvents == true) {
            let lastEventTime: Int64? = await self.storage.read(key: .LAST_EVENT_TIME) ?? nil
            let sessionStartEnd = BaseEvent(timestamp: lastEventTime, sessionId: _sessionId, eventType: Constants.AMP_SESSION_START_EVENT)
            sessionEvents.append(sessionStartEnd)
        }

        return sessionEvents
    }
}
