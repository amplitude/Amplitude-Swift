import XCTest

@testable import Amplitude_Swift

final class AmplitudeTests: XCTestCase {
    private var configuration: Configuration!

    private var configurationWithFakeStorage: Configuration!
    private var storage: FakePersistentStorage!
    private var interceptStorage: FakePersistentStorage!

    private var configurationWithFakeMemoryStorage: Configuration!
    private var storageMem: FakeInMemoryStorage!
    private var interceptStorageMem: FakeInMemoryStorage!

    private var storageTest: TestPersistentStorage!
    private var interceptStorageTest: TestPersistentStorage!

    override func setUp() {
        super.setUp()
        let apiKey = "testApiKey"

        configuration = Configuration(apiKey: apiKey)

        storage = FakePersistentStorage(apiKey: apiKey)
        interceptStorage = FakePersistentStorage(apiKey: apiKey)
        configurationWithFakeStorage = Configuration(
            apiKey: apiKey,
            storageProvider: storage,
            identifyStorageProvider: interceptStorage
        )

        storageMem = FakeInMemoryStorage()
        interceptStorageMem = FakeInMemoryStorage()
        configurationWithFakeMemoryStorage = Configuration(
            apiKey: apiKey,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            trackingSessionEvents: false
        )
    }

    func testInit() {
        XCTAssertEqual(
            Amplitude(configuration: configuration).instanceName,
            Constants.Configuration.DEFAULT_INSTANCE
        )
    }

    func testInitContextPlugin_setsDeviceId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        XCTAssertEqual(amplitude.state.deviceId != nil, true)
        let deviceIdUuid = amplitude.state.deviceId!
        XCTAssertEqual(storage.haveBeenCalledWith, ["write(key: \(StorageKey.DEVICE_ID.rawValue), \(deviceIdUuid))"])
    }

    func testContext() {
        let amplitude = Amplitude(configuration: configuration)

        let locationInfo = LocationInfo(lat: 123, lng: 123)
        amplitude.locationInfoBlock = {
            return locationInfo
        }

        let outputReader = OutputReaderPlugin()
        amplitude.add(plugin: outputReader)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))

        let lastEvent = outputReader.lastEvent
        XCTAssertEqual(lastEvent?.library, "\(Constants.SDK_LIBRARY)/\(Constants.SDK_VERSION)")
        XCTAssertEqual(lastEvent?.deviceManufacturer, "Apple")
        XCTAssertEqual(lastEvent?.deviceModel!.isEmpty, false)
        XCTAssertEqual(lastEvent?.ip, "$remote")
        XCTAssertEqual(lastEvent?.idfv!.isEmpty, false)
        XCTAssertNil(lastEvent?.country)
        XCTAssertEqual(lastEvent?.platform!.isEmpty, false)
        XCTAssertEqual(lastEvent?.language!.isEmpty, false)
        XCTAssertNotNil(lastEvent?.locationLat)
        XCTAssertNotNil(lastEvent?.locationLng)
    }

    func testNewSessionStartEvent() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "testApiKey",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: true
        ))
        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)
        let currentTimestamp: Int64 = 50
        amplitude.onEnterForeground(timestamp: currentTimestamp)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 1)
        let event = collectedEvents[0]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, currentTimestamp)
        XCTAssertEqual(event.sessionId, currentTimestamp)
        XCTAssertEqual(event.eventId, lastEventId + 1)
    }

    func testSessionEventNotInTheSameSession() throws {
        let previousSessionTimestamp: Int64 = 1000
        let lastEventTimestamp: Int64 = previousSessionTimestamp + 200
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.PREVIOUS_SESSION_ID, value: previousSessionTimestamp)
        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: lastEventTimestamp)
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "testApiKey",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: true
        ))

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)
        let currentTimestamp = lastEventTimestamp + 150
        amplitude.onEnterForeground(timestamp: currentTimestamp)

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 2)
        let sessionEndEvent = collectedEvents[0]
        let sessionStartEvent = collectedEvents[1]

        XCTAssertNotNil(sessionEndEvent)
        XCTAssertEqual(sessionEndEvent.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(sessionEndEvent.sessionId, previousSessionTimestamp)
        XCTAssertEqual(sessionEndEvent.timestamp, lastEventTimestamp)
        XCTAssertEqual(sessionEndEvent.eventId, lastEventId+1)

        XCTAssertNotNil(sessionStartEvent)
        XCTAssertEqual(sessionStartEvent.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(sessionStartEvent.timestamp, currentTimestamp)
        XCTAssertEqual(sessionStartEvent.sessionId, currentTimestamp)
        XCTAssertEqual(sessionStartEvent.eventId, lastEventId+2)
    }

    func testEventSessionsWithTrackingSessionEvents() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "testApiKey",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: true
        ))

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        var currentTimestamp: Int64 = 1000
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 1"))
        currentTimestamp = 1050
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 2"))
        currentTimestamp = 1200
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 3"))
        currentTimestamp = 1350
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 4"))

        amplitude.onEnterForeground(timestamp: 1500)

        currentTimestamp = 1700
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 5"))

        amplitude.onExitForeground(timestamp: 1720)

        currentTimestamp = 1750
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 6"))
        currentTimestamp = 2000
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 7"))

        amplitude.onEnterForeground(timestamp: 2050)

        currentTimestamp = 2200
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 8"))

        amplitude.onExitForeground(timestamp: 2250)

        currentTimestamp = 2400
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 9"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 20)

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
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, 1200)
        XCTAssertEqual(event.sessionId, 1200)
        XCTAssertEqual(event.eventId, lastEventId+5)

        event = collectedEvents[5]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.timestamp, 1200)
        XCTAssertEqual(event.sessionId, 1200)
        XCTAssertEqual(event.eventId, lastEventId+6)

        event = collectedEvents[6]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.timestamp, 1200)
        XCTAssertEqual(event.sessionId, 1200)
        XCTAssertEqual(event.eventId, lastEventId+7)

        event = collectedEvents[7]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, 1350)
        XCTAssertEqual(event.sessionId, 1350)
        XCTAssertEqual(event.eventId, lastEventId+8)

        event = collectedEvents[8]
        XCTAssertEqual(event.eventType, "test event 4")
        XCTAssertEqual(event.timestamp, 1350)
        XCTAssertEqual(event.sessionId, 1350)
        XCTAssertEqual(event.eventId, lastEventId+9)

        event = collectedEvents[9]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.timestamp, 1350)
        XCTAssertEqual(event.sessionId, 1350)
        XCTAssertEqual(event.eventId, lastEventId+10)

        event = collectedEvents[10]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, 1500)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+11)

        event = collectedEvents[11]
        XCTAssertEqual(event.eventType, "test event 5")
        XCTAssertEqual(event.timestamp, 1700)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+12)

        event = collectedEvents[12]
        XCTAssertEqual(event.eventType, "test event 6")
        XCTAssertEqual(event.timestamp, 1750)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+13)

        event = collectedEvents[13]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.timestamp, 1750)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+14)

        event = collectedEvents[14]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+15)

        event = collectedEvents[15]
        XCTAssertEqual(event.eventType, "test event 7")
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+16)

        event = collectedEvents[16]
        XCTAssertEqual(event.eventType, "test event 8")
        XCTAssertEqual(event.timestamp, 2200)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+17)

        event = collectedEvents[17]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(event.timestamp, 2250)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+18)

        event = collectedEvents[18]
        XCTAssertEqual(event.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(event.timestamp, 2400)
        XCTAssertEqual(event.sessionId, 2400)
        XCTAssertEqual(event.eventId, lastEventId+19)

        event = collectedEvents[19]
        XCTAssertEqual(event.eventType, "test event 9")
        XCTAssertEqual(event.timestamp, 2400)
        XCTAssertEqual(event.sessionId, 2400)
        XCTAssertEqual(event.eventId, lastEventId+20)
    }

    func testEventSessionsWithoutTrackingSessionEvents() throws {
        let lastEventId: Int64 = 123
        try storageMem.write(key: StorageKey.LAST_EVENT_ID, value: lastEventId)

        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "testApiKey",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: false
        ))

        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)

        var currentTimestamp: Int64 = 1000
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 1"))
        currentTimestamp = 1050
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 2"))
        currentTimestamp = 1200
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 3"))
        currentTimestamp = 1350
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 4"))

        amplitude.onEnterForeground(timestamp: 1500)

        currentTimestamp = 1700
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 5"))

        amplitude.onExitForeground(timestamp: 1720)

        currentTimestamp = 1750
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 6"))
        currentTimestamp = 2000
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 7"))

        amplitude.onEnterForeground(timestamp: 2050)

        currentTimestamp = 2200
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 8"))

        amplitude.onExitForeground(timestamp: 2250)

        currentTimestamp = 2400
        amplitude.track(event: BaseEvent(userId: "user", timestamp: currentTimestamp, eventType: "test event 9"))

        let collectedEvents = eventCollector.events

        XCTAssertEqual(collectedEvents.count, 9)

        var event = collectedEvents[0]
        XCTAssertEqual(event.eventType, "test event 1")
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.timestamp, 1000)
        XCTAssertEqual(event.eventId, lastEventId+1)

        event = collectedEvents[1]
        XCTAssertEqual(event.eventType, "test event 2")
        XCTAssertEqual(event.timestamp, 1050)
        XCTAssertEqual(event.sessionId, 1000)
        XCTAssertEqual(event.eventId, lastEventId+2)

        event = collectedEvents[2]
        XCTAssertEqual(event.eventType, "test event 3")
        XCTAssertEqual(event.timestamp, 1200)
        XCTAssertEqual(event.sessionId, 1200)
        XCTAssertEqual(event.eventId, lastEventId+3)

        event = collectedEvents[3]
        XCTAssertEqual(event.eventType, "test event 4")
        XCTAssertEqual(event.timestamp, 1350)
        XCTAssertEqual(event.sessionId, 1350)
        XCTAssertEqual(event.eventId, lastEventId+4)

        event = collectedEvents[4]
        XCTAssertEqual(event.eventType, "test event 5")
        XCTAssertEqual(event.timestamp, 1700)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+5)

        event = collectedEvents[5]
        XCTAssertEqual(event.eventType, "test event 6")
        XCTAssertEqual(event.timestamp, 1750)
        XCTAssertEqual(event.sessionId, 1500)
        XCTAssertEqual(event.eventId, lastEventId+6)

        event = collectedEvents[6]
        XCTAssertEqual(event.eventType, "test event 7")
        XCTAssertEqual(event.timestamp, 2000)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+7)

        event = collectedEvents[7]
        XCTAssertEqual(event.eventType, "test event 8")
        XCTAssertEqual(event.timestamp, 2200)
        XCTAssertEqual(event.sessionId, 2000)
        XCTAssertEqual(event.eventId, lastEventId+8)

        event = collectedEvents[8]
        XCTAssertEqual(event.eventType, "test event 9")
        XCTAssertEqual(event.timestamp, 2400)
        XCTAssertEqual(event.sessionId, 2400)
        XCTAssertEqual(event.eventId, lastEventId+9)
    }


    func testEventSessionsRestore() throws {
        let configuration = Configuration(
            apiKey: "testApiKey",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 100,
            trackingSessionEvents: true
        )

        let amplitude1 = Amplitude(configuration: configuration)
        amplitude1.onEnterForeground(timestamp: 1000)

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.timeline.sessionId, 1000)
        XCTAssertEqual(amplitude1.timeline.lastEventTime, 1000)
        XCTAssertEqual(amplitude1.timeline.lastEventId, 1)

        amplitude1.track(event: BaseEvent(userId: "user", timestamp: 1200, eventType: "test event 1"))

        XCTAssertEqual(amplitude1.sessionId, 1000)
        XCTAssertEqual(amplitude1.timeline.sessionId, 1000)
        XCTAssertEqual(amplitude1.timeline.lastEventTime, 1200)
        XCTAssertEqual(amplitude1.timeline.lastEventId, 2)

        let amplitude2 = Amplitude(configuration: configuration)

        XCTAssertEqual(amplitude2.sessionId, 1000)
        XCTAssertEqual(amplitude2.timeline.sessionId, 1000)
        XCTAssertEqual(amplitude2.timeline.lastEventTime, 1200)
        XCTAssertEqual(amplitude2.timeline.lastEventId, 2)

        let amplitude3 = Amplitude(configuration: configuration)

        XCTAssertEqual(amplitude3.sessionId, 1000)
        XCTAssertEqual(amplitude3.timeline.sessionId, 1000)
        XCTAssertEqual(amplitude3.timeline.lastEventTime, 1200)
        XCTAssertEqual(amplitude3.timeline.lastEventId, 2)

        amplitude3.onEnterForeground(timestamp: 1400)

        XCTAssertEqual(amplitude3.sessionId, 1400)
        XCTAssertEqual(amplitude3.timeline.sessionId, 1400)
        XCTAssertEqual(amplitude3.timeline.lastEventTime, 1400)
        XCTAssertEqual(amplitude3.timeline.lastEventId, 4)
    }

    func testSetUserId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        XCTAssertEqual(amplitude.state.userId, nil)

        amplitude.setUserId(userId: "test-user")
        XCTAssertEqual(amplitude.state.userId, "test-user")
        XCTAssertEqual(storage.haveBeenCalledWith[1], "write(key: \(StorageKey.USER_ID.rawValue), test-user)")
    }

    func testSetDeviceId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        // init deviceId is set by ContextPlugin
        XCTAssertEqual(amplitude.state.deviceId != nil, true)

        amplitude.setDeviceId(deviceId: "test-device")
        XCTAssertEqual(amplitude.state.deviceId, "test-device")
        XCTAssertEqual(storage.haveBeenCalledWith[1], "write(key: \(StorageKey.DEVICE_ID.rawValue), test-device)")
    }

    func testInterceptedIdentifyIsSentOnFlush() {
        let amplitude = Amplitude(configuration: configurationWithFakeMemoryStorage)

        amplitude.setUserId(userId: "test-user")
        amplitude.identify(identify: Identify().set(property: "key-1", value: "value-1"))
        amplitude.identify(identify: Identify().set(property: "key-2", value: "value-2"))

        var intercepts = interceptStorageMem.events()
        var events = storageMem.events()
        XCTAssertEqual(intercepts.count, 2)
        XCTAssertEqual(events.count, 0)

        amplitude.flush()

        intercepts = interceptStorageMem.events()
        events = storageMem.events()
        XCTAssertEqual(intercepts.count, 0)
        XCTAssertEqual(events.count, 1)
    }

    func testInterceptedIdentifyWithPersistentStorage() {
        let apiKey = "testApiKeyPersist"
        storageTest = TestPersistentStorage(apiKey: apiKey)
        interceptStorageTest = TestPersistentStorage(apiKey: apiKey, storagePrefix: "identify")
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            storageProvider: storageTest,
            identifyStorageProvider: interceptStorageTest,
            trackingSessionEvents: false
        ))

        amplitude.setUserId(userId: "test-user")

        // send 2 $set only Identify's, should be intercepted
        amplitude.identify(identify: Identify().set(property: "key-1", value: "value-1"))
        amplitude.identify(identify: Identify().set(property: "key-2", value: "value-2"))

        var intercepts = interceptStorageTest.events()
        var events = storageTest.events()
        XCTAssertEqual(intercepts.count, 2)
        XCTAssertEqual(events.count, 0)

        // setGroup event should not be intercepted
        amplitude.setGroup(groupType: "group-type", groupName: "group-name")

        intercepts = interceptStorageTest.events()
        XCTAssertEqual(intercepts.count, 0)

        // setGroup event should not be intercepted
        events = storageTest.events()
        XCTAssertEqual(events.count, 2)

        let e1 = events[0]
        XCTAssertEqual(e1.eventType, "$identify")
        XCTAssertNil(e1.groups)
        XCTAssertNotNil(e1.userProperties)
        XCTAssertTrue(getDictionary(e1.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))

        let e2 = events[1]
        XCTAssertEqual(e2.eventType, "$identify")
        XCTAssertNil(e2.userProperties)
        XCTAssertNotNil(e2.groups)
        XCTAssertTrue(getDictionary(e2.groups!).isEqual(to: ["group-type": "group-name"]))

        // clear storages
        storageTest.reset()
        interceptStorageTest.reset()
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
