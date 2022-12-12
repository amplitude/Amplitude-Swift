import XCTest

@testable import Amplitude_Swift

final class AmplitudeTests: XCTestCase {
    private var storage: FakePersistentStorage!
    private var configuration: Configuration!
    private var configurationWithFakeStorage: Configuration!

    override func setUp() {
        super.setUp()
        let apiKey = "testApiKey"
        storage = FakePersistentStorage(apiKey: apiKey)
        configuration = Configuration(apiKey: apiKey)
        configurationWithFakeStorage = Configuration(
            apiKey: apiKey,
            storageProvider: storage
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
}
