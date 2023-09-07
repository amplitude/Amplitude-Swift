import XCTest
import AnalyticsConnector

@testable import AmplitudeSwift

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

        storage = FakePersistentStorage(storagePrefix: "storage")
        interceptStorage = FakePersistentStorage(storagePrefix: "intercept")
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

    func testInit_defaultInstanceName() {
        let configuration = Configuration(apiKey: "api-key")
        XCTAssertEqual(
            Amplitude(configuration: configuration).configuration.instanceName,
            Constants.Configuration.DEFAULT_INSTANCE
        )
    }

    func testInit_emptyInstanceName() {
        let configuration = Configuration(apiKey: "api-key", instanceName: "")
        XCTAssertEqual(
            Amplitude(configuration: configuration).configuration.instanceName,
            Constants.Configuration.DEFAULT_INSTANCE
        )
    }

    func testInitContextPlugin_setsDeviceId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        XCTAssertEqual(amplitude.getDeviceId() != nil, true)
        let deviceIdUuid = amplitude.getDeviceId()!
        XCTAssertEqual(storage.haveBeenCalledWith.last, "write(key: \(StorageKey.DEVICE_ID.rawValue), \(deviceIdUuid))")
    }

    func testContext() {
        let amplitude = Amplitude(configuration: configuration)

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
    }

    func testContextWithDisableTrackingOptions() {
        let apiKey = "testApiKeyForDisableTrackingOptions"
        let trackingOptions = TrackingOptions()
        _ = trackingOptions.disableTrackIpAddress()
            .disableCarrier()
            .disableTrackIDFV()
            .disableTrackCountry()
        let configuration = Configuration(apiKey: apiKey, trackingOptions: trackingOptions)

        let amplitude = Amplitude(configuration: configuration)

        let outputReader = OutputReaderPlugin()
        amplitude.add(plugin: outputReader)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))

        let lastEvent = outputReader.lastEvent
        XCTAssertNil(lastEvent?.ip)
        XCTAssertNil(lastEvent?.carrier)
        XCTAssertNil(lastEvent?.idfv)
        XCTAssertNil(lastEvent?.locationLat)
        XCTAssertNil(lastEvent?.locationLng)
        XCTAssertNil(lastEvent?.country)
    }

    func testSetUserId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        XCTAssertEqual(amplitude.getUserId(), nil)

        amplitude.setUserId(userId: "test-user")
        XCTAssertEqual(amplitude.getUserId(), "test-user")
        XCTAssertEqual(storage.haveBeenCalledWith.last, "write(key: \(StorageKey.USER_ID.rawValue), test-user)")
    }

    func testSetDeviceId() {
        let amplitude = Amplitude(configuration: configurationWithFakeStorage)
        // init deviceId is set by ContextPlugin
        XCTAssertEqual(amplitude.getDeviceId() != nil, true)

        amplitude.setDeviceId(deviceId: "test-device")
        XCTAssertEqual(amplitude.getDeviceId(), "test-device")
        XCTAssertEqual(storage.haveBeenCalledWith.last, "write(key: \(StorageKey.DEVICE_ID.rawValue), test-device)")
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
        storageTest = TestPersistentStorage(storagePrefix: "storage")
        interceptStorageTest = TestPersistentStorage(storagePrefix: "identify")
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
        XCTAssertNotNil(e2.userProperties)
        XCTAssertTrue(getDictionary(e2.userProperties!).isEqual(to: ["$set": ["group-type": "group-name"]]))
        XCTAssertNotNil(e2.groups)
        XCTAssertTrue(getDictionary(e2.groups!).isEqual(to: ["group-type": "group-name"]))

        // clear storages
        storageTest.reset()
        interceptStorageTest.reset()
    }

    func testAnalyticsConnector() {
        let apiKey = "test-api-key"
        let instanceName = "test-instance"
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            instanceName: instanceName,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem
        ))

        let userId = "some-user"
        let deviceId = "some-device"
        let expectation = XCTestExpectation()
        var identitySet = false

        let connector = AnalyticsConnector.getInstance(instanceName)
        connector.identityStore.addIdentityListener(key: "test-analytics-connector", { identity in
            if identitySet {
                XCTAssertEqual(identity.userId, userId)
                XCTAssertEqual(identity.deviceId, deviceId)
                XCTAssertEqual(identity.userProperties, ["prop-A": 123])
                expectation.fulfill()
            }
        })

        amplitude.setUserId(userId: userId)
        amplitude.setDeviceId(deviceId: deviceId)
        identitySet = true
        let identify = Identify()
        identify.set(property: "prop-A", value: 123)
        amplitude.identify(identify: identify)

        wait(for: [expectation], timeout: 1.0)
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
