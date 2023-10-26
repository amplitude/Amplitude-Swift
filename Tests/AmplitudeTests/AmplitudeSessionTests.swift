import XCTest

@testable import AmplitudeSwift

final class AmplitudeSessionTests: XCTestCase {
    private var configuration: Configuration!
    private var storageMem: FakeInMemoryStorage!
    private var interceptStorageMem: FakeInMemoryStorage!

    override func setUp() {
        super.setUp()
        let apiKey = "testApiKey"

        storageMem = FakeInMemoryStorage()
        interceptStorageMem = FakeInMemoryStorage()

        configuration = Configuration(
            apiKey: apiKey,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100
        )
    }

    func testCloseBackgroundEventsShouldNotStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)
        XCTAssertEqual(amplitude.getSessionId(), 1000)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)
    }

    func testDistantBackgroundEventsShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
    }

    func testForegroundEventsShouldNotStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)
    }

    func testCloseBackgroundForegroundEventsShouldNotStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.onEnterForeground(timestamp: 1050)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)
    }

    func testDistantBackgroundForegroundEventsShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.onEnterForeground(timestamp: 2000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 3000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+5)
    }

    func testCloseForegroundBackgroundEventsShouldNotStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1500, eventType: "test event 1"))
        amplitude.onExitForeground(timestamp: 2000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2050, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2050)
        XCTAssertEqual(event.eventId, lastEventId+3)
    }

    func testDistantForegroundBackgroundEventsShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1500, eventType: "test event 1"))
        amplitude.onExitForeground(timestamp: 2000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 3000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+5)
    }

    func testSessionDataShouldBePersisted() throws {
        let amplitude1 = Amplitude(configuration: configuration)
        amplitude1.onEnterForeground(timestamp: 1000)

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventTime, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventId, 1)

        amplitude1.track(event: BaseEvent(userId: "user", timestamp: 1200, eventType: "test event 1"))

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventTime, 1200)
        XCTAssertEqual(amplitude1.sessions.lastEventId, 2)

        let amplitude2 = Amplitude(configuration: configuration)

        XCTAssertEqual(amplitude2.sessionId, 1000)
        XCTAssertEqual(amplitude2.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude2.sessions.lastEventTime, 1200)
        XCTAssertEqual(amplitude2.sessions.lastEventId, 2)
    }

    func testExplicitSessionForEventShouldBePreserved() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, sessionId: 3000, eventType: "test event 2"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1100, eventType: "test event 3"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 4)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)
    }

    func testExplicitNoSessionForEventShouldBePreserved() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, sessionId: -1, eventType: "test event 2"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1100, eventType: "test event 3"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 4)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, -1)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)
    }

    func testSetSessionIdInBackgroundShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 100, eventType: "test event 1"))
        amplitude.setSessionId(timestamp: 150)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 200, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 150)
        XCTAssertEqual(event.timestamp, 150)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 150)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+5)
    }

    func testSetSessionIdInForegroundShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, eventType: "test event 1"))
        amplitude.setSessionId(timestamp: 1100)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1100)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1100)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
    }

    func testSessionEndInBackgroundShouldEndCurrentSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 100, eventType: "test event 1"))
        XCTAssertEqual(amplitude.sessionId, 100)

        amplitude.sessionEnd()
        XCTAssertEqual(amplitude.sessionId, -1)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 200, eventType: "test event 2"))
        XCTAssertEqual(amplitude.sessionId, 200)

        amplitude.sessionEnd(at: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(amplitude.sessionId, -1)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 6)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+5)

        event = collectedEvents[5]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+6)
    }

    func testSessionEndInForegroundShouldEndCurrentSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 100)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 150, eventType: "test event 1"))
        XCTAssertEqual(amplitude.sessionId, 100)

        amplitude.sessionEnd()
        XCTAssertEqual(amplitude.sessionId, -1)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 200, eventType: "test event 2"))
        XCTAssertEqual(amplitude.sessionId, 200)

        amplitude.sessionEnd(at: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(amplitude.sessionId, -1)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 6)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 150)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 150)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+5)

        event = collectedEvents[5]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 200)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+6)
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
