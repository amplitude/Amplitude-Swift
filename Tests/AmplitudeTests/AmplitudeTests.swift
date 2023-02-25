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

    func testNewSessionStartEvent() {
        let amplitude = Amplitude(configuration: configuration)
        let sessionReader = SessionReaderPlugin()
        amplitude.add(plugin: sessionReader)
        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        amplitude.onEnterForeground(timestamp: timestamp)

        let sessionEvents = sessionReader.sessionEvents
        let sessionEvent = sessionEvents?[0]

        XCTAssertEqual(sessionEvents?.count, 1)
        XCTAssertEqual(sessionEvent?.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(sessionEvent?.timestamp, timestamp)
        XCTAssertNotNil(sessionEvent?.eventId)
    }

    func testSessionEventNotInTheSameSession() {
        let previousSessionTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        let amplitude = Amplitude(configuration: Configuration(apiKey: "testApiKey", minTimeBetweenSessionsMillis: 1))
        amplitude._sessionId = previousSessionTimestamp
        let sessionReader = SessionReaderPlugin()
        amplitude.add(plugin: sessionReader)
        let currentSessionTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        amplitude.onEnterForeground(timestamp: currentSessionTimestamp)

        let sessionEvents = sessionReader.sessionEvents
        let sessionEndEvent = sessionEvents?[0]
        let sessionStartEvent = sessionEvents?[1]

        XCTAssertNotNil(sessionStartEvent)
        XCTAssertNotNil(sessionEndEvent)
        XCTAssertEqual(sessionStartEvent?.eventType, Constants.AMP_SESSION_START_EVENT)
        XCTAssertEqual(sessionStartEvent?.sessionId, currentSessionTimestamp)
        XCTAssertNotNil(sessionStartEvent?.eventId)
        XCTAssertEqual(sessionEndEvent?.eventType, Constants.AMP_SESSION_END_EVENT)
        XCTAssertEqual(sessionEndEvent?.sessionId, previousSessionTimestamp)
        XCTAssertNotNil(sessionEndEvent?.eventId)
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
        events = storageTest.events()
        XCTAssertEqual(intercepts.count, 0)
        XCTAssertEqual(events.count, 1)

        // clear storages
        storageTest.reset()
        interceptStorageTest.reset()
    }
}
