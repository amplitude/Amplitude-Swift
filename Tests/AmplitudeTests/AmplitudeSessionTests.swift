import XCTest

@testable import Amplitude_Swift

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
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: true
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

        let amplitude3 = Amplitude(configuration: configuration)

        XCTAssertEqual(amplitude3.sessionId, 1000)
        XCTAssertEqual(amplitude3.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude3.sessions.lastEventTime, 1200)
        XCTAssertEqual(amplitude3.sessions.lastEventId, 2)

        amplitude3.onEnterForeground(timestamp: 1400)

        XCTAssertEqual(amplitude3.sessionId, 1400)
        XCTAssertEqual(amplitude3.sessions.sessionId, 1400)
        XCTAssertEqual(amplitude3.sessions.lastEventTime, 1400)
        XCTAssertEqual(amplitude3.sessions.lastEventId, 4)
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
