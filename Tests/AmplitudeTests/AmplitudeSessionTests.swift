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
            minTimeBetweenSessionsMillis: 100,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)
        XCTAssertEqual(amplitude.getSessionId(), 1000)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func testDistantBackgroundEventsShouldStartNewSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func testBackgroundOutOfSessionEvent() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)
        let customCongiguration = Configuration(
            apiKey: "test-out-of-session",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false
        )
        let amplitude = Amplitude(configuration: customCongiguration)
        amplitude.setSessionId(timestamp: 800)
        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)
        let eventOptions = EventOptions(timestamp: 1000, sessionId: -1)
        let eventType = "out of session event"
        amplitude.track(eventType: eventType, options: eventOptions)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, eventType: "test event"))
        amplitude.waitForTrackingQueue()
        let collectedEvents = eventCollector.events
        XCTAssertEqual(collectedEvents.count, 2)
        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, eventType)
        XCTAssertEqual(event.sessionId, -1)
        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(amplitude.getSessionId(), 1000)
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

        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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

        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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

        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 3)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2050)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 3000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func testSessionDataShouldBePersisted() throws {
        let amplitude1 = Amplitude(configuration: configuration)
        amplitude1.onEnterForeground(timestamp: 1000)
        amplitude1.waitForTrackingQueue()

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventTime, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventId, 1)

        amplitude1.track(event: BaseEvent(userId: "user", timestamp: 1200, eventType: "test event 1"))
        amplitude1.waitForTrackingQueue()

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.sessionId, 1000)
        XCTAssertEqual(amplitude1.sessions.lastEventTime, 1200)
        XCTAssertEqual(amplitude1.sessions.lastEventId, 2)

        let amplitude2 = Amplitude(configuration: configuration)
        amplitude2.waitForTrackingQueue()

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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 4)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 3000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 4)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, -1)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 100)
        XCTAssertEqual(event.timestamp, 100)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 150)
        XCTAssertEqual(event.timestamp, 150)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 150)
        XCTAssertEqual(event.timestamp, 200)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
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
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1100)
        XCTAssertEqual(event.timestamp, 1100)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 1100)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func testSessionEndInBackgroundShouldEndCurrentSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, 1000)

        amplitude.setSessionId(timestamp: -1)
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, -1)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, 2000)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func testSessionEndInForegroundShouldEndCurrentSession() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1500, eventType: "test event 1"))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, 1000)

        amplitude.setSessionId(timestamp: -1)
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, -1)

        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(amplitude.sessionId, 2000)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 5)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+2)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.eventId, lastEventId+3)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+4)
        XCTAssertEqual(event.userId, amplitude.getUserId())
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.eventId, lastEventId+5)
        XCTAssertEqual(event.userId, "user")
        XCTAssertEqual(event.deviceId, amplitude.getDeviceId())
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }

    // MARK: - OptOut Session Event Tests

    func testOptOutShouldNotSendSessionEventsWhenTracking() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let optOutConfiguration = Configuration(
            apiKey: "testOptOutSessionEvents",
            optOut: true,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false
        )
        let amplitude = Amplitude(configuration: optOutConfiguration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        // Track events that would normally trigger session_start
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1050, eventType: "test event 2"))
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        // With optOut=true, no events should be collected (no session_start, no regular events)
        XCTAssertEqual(collectedEvents.count, 0)
    }

    func testOptOutShouldNotSendSessionEventsOnEnterForeground() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let optOutConfiguration = Configuration(
            apiKey: "testOptOutForegroundSessionEvents",
            optOut: true,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false
        )
        let amplitude = Amplitude(configuration: optOutConfiguration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        // Enter foreground which would normally trigger session_start
        amplitude.onEnterForeground(timestamp: 1000)
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        // With optOut=true, no session_start event should be sent
        XCTAssertEqual(collectedEvents.count, 0)
    }

    func testOptOutShouldNotSendSessionEndEventsOnSetSessionId() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        // Start with optOut=false to establish a session
        let amplitude = Amplitude(configuration: configuration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        // Track an event to start a session
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.waitForTrackingQueue()

        // Should have session_start and test event
        XCTAssertEqual(eventCollector.events.count, 2)
        XCTAssertEqual(eventCollector.events[0].eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(eventCollector.events[1].eventType, "test event 1")

        // Now enable optOut
        amplitude.configuration.optOut = true

        // Set a new session ID which would normally trigger session_end and session_start
        amplitude.setSessionId(timestamp: 2000)
        amplitude.waitForTrackingQueue()

        // No new events should be added because optOut is true
        XCTAssertEqual(eventCollector.events.count, 2)
    }

    func testOptOutDisabledAfterEnableShouldSendSessionEvents() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let optOutConfiguration = Configuration(
            apiKey: "testOptOutToggle",
            optOut: true,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false
        )
        let amplitude = Amplitude(configuration: optOutConfiguration)

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        // Try to track with optOut=true
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 1000, eventType: "test event 1"))
        amplitude.waitForTrackingQueue()

        // No events should be collected
        XCTAssertEqual(eventCollector.events.count, 0)

        // Disable optOut
        amplitude.configuration.optOut = false

        // Now track an event - should trigger session_start and the event
        amplitude.track(event: BaseEvent(userId: "user", timestamp: 2000, eventType: "test event 2"))
        amplitude.waitForTrackingQueue()

        let collectedEvents = eventCollector.events

        // Should have session_start and test event 2
        XCTAssertEqual(collectedEvents.count, 2)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.timestamp, 2000)
    }
}
