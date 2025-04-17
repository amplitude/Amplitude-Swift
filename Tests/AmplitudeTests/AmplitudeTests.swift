import AnalyticsConnector
import XCTest

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
    private let logger = ConsoleLogger()
    private let diagonostics = Diagnostics()

    override func setUp() {
        super.setUp()
        let apiKey = "testApiKey"

        configuration = Configuration(apiKey: apiKey)

        storage = FakePersistentStorage(storagePrefix: "storage", logger: self.logger, diagonostics: self.diagonostics)
        interceptStorage = FakePersistentStorage(storagePrefix: "intercept", logger: self.logger, diagonostics: self.diagonostics)
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
            autocapture: []
        )
    }

    override func tearDown() {
        super.tearDown()
        storage.reset()
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
        amplitude.waitForTrackingQueue()

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

    func testFilterAndEnrichmentPlugin() {
        let apiKey = "testFilterAndEnrichmentPlugin"
        let enrichedEventType = "Enriched Event"
        let storage = FakeInMemoryStorage()
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            storageProvider: storage
        ))

        class TestFilterAndEnrichmentPlugin: EnrichmentPlugin {
            override func execute(event: BaseEvent) -> BaseEvent? {
                if event.eventType == "Enriched Event" {
                    if event.eventProperties == nil {
                        event.eventProperties = [:]
                    }
                    event.eventProperties!["testPropertyKey"] = "testPropertyValue"
                    return event
                }
                return nil
            }
        }
        let testPlugin = TestFilterAndEnrichmentPlugin()
        amplitude.add(plugin: testPlugin)
        amplitude.track(event: BaseEvent(eventType: enrichedEventType))
        amplitude.track(event: BaseEvent(eventType: "Other Event"))
        amplitude.waitForTrackingQueue()

        let events = storage.events()
        XCTAssertEqual(events[0].eventType, enrichedEventType)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            "testPropertyKey": "testPropertyValue"
        ])

        XCTAssertEqual(events.count, 1)
    }

    func testPluginChangeNotifications() {
        class TestPlugin: Plugin {
            let type: PluginType = .enrichment

            var deviceIdChanged: ((String?) -> Void)?
            var sessionIdChanged: ((Int64?) -> Void)?
            var userIdChanged: ((String?) -> Void)?
            var optOutChanged: ((Bool) -> Void)?

            func onDeviceIdChanged(_ deviceId: String?) {
                deviceIdChanged?(deviceId)
            }

            func onSessionIdChanged(_ sessionId: Int64) {
                sessionIdChanged?(sessionId)
            }

            func onUserIdChanged(_ userId: String?) {
                userIdChanged?(userId)
            }

            func onOptOutChanged(_ optOut: Bool) {
                optOutChanged?(optOut)
            }
        }

        let testPlugin = TestPlugin()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "testPluginChangeNotifications",
                                                               flushIntervalMillis: 1000000,
                                                               optOut: false,
                                                               storageProvider: FakeInMemoryStorage()))
        amplitude.add(plugin: testPlugin)
        amplitude.waitForTrackingQueue()

        let expectedDeviceId = "test_device_id"
        let deviceIdExpectation = expectation(description: "Should receive deviceId changes")
        testPlugin.deviceIdChanged = { deviceId in
            XCTAssertEqual(deviceId, expectedDeviceId)
            XCTAssertEqual(amplitude.getDeviceId(), expectedDeviceId)
            deviceIdExpectation.fulfill()
        }
        amplitude.setDeviceId(deviceId: expectedDeviceId)

        let expectedSessionId = Int64(Date().timeIntervalSince1970 * 1000)
        let sessionIdExpectation = expectation(description: "Should receive sessionId changes")
        testPlugin.sessionIdChanged = { sessionId in
            XCTAssertEqual(sessionId, expectedSessionId)
            XCTAssertEqual(amplitude.getSessionId(), expectedSessionId)
            sessionIdExpectation.fulfill()
        }
        amplitude.setSessionId(timestamp: expectedSessionId)

        let expectedUserId = "test_user_id"
        let userIdExpectation = expectation(description: "Should receive userId changes")
        testPlugin.userIdChanged = { userId in
            XCTAssertEqual(userId, expectedUserId)
            XCTAssertEqual(amplitude.getUserId(), expectedUserId)
            userIdExpectation.fulfill()
        }
        amplitude.setUserId(userId: expectedUserId)

        let optOutExpectation = expectation(description: "Should receive optOut changes")
        testPlugin.optOutChanged = { optOut in
            XCTAssertTrue(optOut)
            XCTAssertTrue(amplitude.configuration.optOut)
            optOutExpectation.fulfill()
        }
        amplitude.configuration.optOut = true

        waitForExpectations(timeout: 10)
    }

    func testContextWithDisableTrackingOptions() {
        let apiKey = "testApiKeyForDisableTrackingOptions"
        let trackingOptions = TrackingOptions()
        _ = trackingOptions.disableTrackIpAddress()
            .disableTrackCarrier()
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

    func testDeviceIdWithDisableIDFV() {
        let configuration = Configuration(
            apiKey: "testApiKeyDeviceIDWithDisableIDFV",
            storageProvider: storage,
            trackingOptions: TrackingOptions().disableTrackIDFV())

        let amplitude = Amplitude(configuration: configuration)

        XCTAssertNotEqual(amplitude.getDeviceId(), VendorSystem.current.identifierForVendor)
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
        amplitude.waitForTrackingQueue()

        var intercepts = interceptStorageMem.events()
        var events = storageMem.events()
        XCTAssertEqual(intercepts.count, 2)
        XCTAssertEqual(events.count, 0)

        amplitude.flush()
        amplitude.waitForTrackingQueue()

        intercepts = interceptStorageMem.events()
        events = storageMem.events()
        XCTAssertEqual(intercepts.count, 0)
        XCTAssertEqual(events.count, 1)
    }

    func testInterceptedIdentifyWithPersistentStorage() {
        let apiKey = "testApiKeyPersist"
        storageTest = TestPersistentStorage(storagePrefix: "storage", logger: self.logger, diagonostics: self.diagonostics)
        interceptStorageTest = TestPersistentStorage(storagePrefix: "identify", logger: self.logger, diagonostics: self.diagonostics)
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            storageProvider: storageTest,
            identifyStorageProvider: interceptStorageTest,
            autocapture: []
        ))

        amplitude.setUserId(userId: "test-user")

        // send 2 $set only Identify's, should be intercepted
        amplitude.identify(identify: Identify().set(property: "key-1", value: "value-1"))
        amplitude.identify(identify: Identify().set(property: "key-2", value: "value-2"))
        amplitude.waitForTrackingQueue()

        var intercepts = interceptStorageTest.events()
        var events = storageTest.events()
        XCTAssertEqual(intercepts.count, 2)
        XCTAssertEqual(events.count, 0)

        // setGroup event should not be intercepted
        amplitude.setGroup(groupType: "group-type", groupName: "group-name")
        amplitude.waitForTrackingQueue()

        intercepts = interceptStorageTest.events()
        XCTAssertEqual(intercepts.count, 0)

        // setGroup event should not be intercepted
        events = storageTest.events()
        XCTAssertEqual(events.count, 2)

        let e1 = events[0]
        XCTAssertEqual(e1.eventType, "$identify")
        XCTAssertNil(e1.groups)
        XCTAssertNotNil(e1.userProperties)
        XCTAssertTrue(
            getDictionary(e1.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))

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
        let amplitude = Amplitude(
            configuration: Configuration(
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
        connector.identityStore.addIdentityListener(
            key: "test-analytics-connector",
            { identity in
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

    func testInit_autocapture() {
        let configuration = Configuration(apiKey: "api-key")
        let amplitude = Amplitude(configuration: configuration)
        let autocapture = amplitude.configuration.autocapture
        XCTAssertFalse(autocapture.contains(.appLifecycles))
        XCTAssertFalse(autocapture.contains(.screenViews))
        XCTAssertFalse(autocapture.contains(.elementInteractions))
        XCTAssertTrue(autocapture.contains(.sessions))
    }

    func testTrackNSUserActivity() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )

        let amplitude = Amplitude(configuration: configuration)

        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://test-app.com")
        userActivity.referrerURL = URL(string: "https://test-referrer.com")

        amplitude.track(event: DeepLinkOpenedEvent(activity: userActivity))
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_DEEP_LINK_OPENED_EVENT)
        XCTAssertEqual(
            getDictionary(events[0].eventProperties!),
            [
                Constants.AMP_APP_LINK_URL_PROPERTY: "https://test-app.com",
                Constants.AMP_APP_LINK_REFERRER_PROPERTY: "https://test-referrer.com",
            ])
    }

    func testTrackURLOpened() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )

        let amplitude = Amplitude(configuration: configuration)

        amplitude.track(event: DeepLinkOpenedEvent(url: URL(string: "https://test-app.com")!))
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_DEEP_LINK_OPENED_EVENT)
        XCTAssertEqual(
            getDictionary(events[0].eventProperties!),
            [
                Constants.AMP_APP_LINK_URL_PROPERTY: "https://test-app.com"
            ])
    }

    func testTrackNSURLOpened() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )

        let amplitude = Amplitude(configuration: configuration)

        amplitude.track(event: DeepLinkOpenedEvent(url: NSURL(string: "https://test-app.com")!))
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_DEEP_LINK_OPENED_EVENT)
        XCTAssertEqual(
            getDictionary(events[0].eventProperties!),
            [
                Constants.AMP_APP_LINK_URL_PROPERTY: "https://test-app.com"
            ])
    }

    func testTrackScreenView() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )

        let amplitude = Amplitude(configuration: configuration)

        amplitude.track(event: ScreenViewedEvent(screenName: "main view"))
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_SCREEN_VIEWED_EVENT)
        XCTAssertEqual(
            getDictionary(events[0].eventProperties!),
            [
                Constants.AMP_APP_SCREEN_NAME_PROPERTY: "main view"
            ])
    }

    func testOutOfSessionEvent() {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )
        let amplitude = Amplitude(configuration: configuration)
        let eventOptions = EventOptions(sessionId: -1)
        let eventType = "out of session event"
        amplitude.track(eventType: eventType, options: eventOptions)
        amplitude.waitForTrackingQueue()
        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, eventType)
        XCTAssertEqual(events[0].sessionId, -1)
    }

    func testEventProcessingBeforeOnEnterForeground() async {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: []
        )
        let amplitude = Amplitude(configuration: configuration)
        amplitude.sessions = SessionsWithDelayedEventStartProcessing(amplitude: amplitude)
        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)

        let oneHourEarlierTimestamp = timestamp - (1 * 60 * 60 * 1000)
        amplitude.setSessionId(timestamp: oneHourEarlierTimestamp)

        // We process the session start event first. The session class will wait for 3 seconds before it processes
        // the event
        let processSessionStartEvent = Task.detached {
            amplitude.onEnterForeground(timestamp: timestamp)
        }

        // Sleep for 1 second and process a regular event. This is to try the case where an event gets processed
        // before the session start event
        let processRegularEvent = Task.detached {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            amplitude.track(eventType: "test_event")
        }

        _ = await processRegularEvent.result
        _ = await processSessionStartEvent.result

        amplitude.waitForTrackingQueue()

        // We want to make sure that a new session was started
        XCTAssertTrue(amplitude.getSessionId() > oneHourEarlierTimestamp)

    }

    func testMigrationToApiKeyAndInstanceNameStorage() throws {
        let legacyUserId = "legacy-user-id"
        let config = Configuration(
            apiKey: "amp-migration-api-key",
            // don't transfer any events
            flushQueueSize: 1000,
            flushIntervalMillis: 99999,
            logLevel: LogLevelEnum.DEBUG,
            autocapture: []
        )

        // Create storages using instance name only
        let legacyEventStorage = PersistentStorage(storagePrefix: "storage-\(config.getNormalizeInstanceName())", logger: self.logger, diagonostics: self.diagonostics)
        let legacyIdentityStorage = PersistentStorage(storagePrefix: "identify-\(config.getNormalizeInstanceName())", logger: self.logger, diagonostics: self.diagonostics)

        // Init Amplitude using legacy storage
        let legacyStorageAmplitude = FakeAmplitudeWithNoInstNameOnlyMigration(
            configuration: Configuration(
                apiKey: config.apiKey,
                flushQueueSize: config.flushQueueSize,
                flushIntervalMillis: config.flushIntervalMillis,
                storageProvider: legacyEventStorage,
                identifyStorageProvider: legacyIdentityStorage,
                logLevel: config.logLevel,
                autocapture: config.autocapture
            ))

        let legacyDeviceId = legacyStorageAmplitude.getDeviceId()

        // set userId
        legacyStorageAmplitude.setUserId(userId: legacyUserId)
        XCTAssertEqual(legacyUserId, legacyStorageAmplitude.getUserId())

        // track events to legacy storage
        legacyStorageAmplitude.identify(identify: Identify().set(property: "user-prop", value: true))
        legacyStorageAmplitude.track(event: BaseEvent(eventType: "Legacy Storage Event"))
        legacyStorageAmplitude.waitForTrackingQueue()

        guard let legacyEventFiles: [URL]? = legacyEventStorage.read(key: StorageKey.EVENTS) else { return }

        var legacyEventsString = ""
        legacyEventFiles?.forEach { file in
            legacyEventsString = legacyEventStorage.getEventsString(eventBlock: file) ?? ""
        }

        XCTAssertEqual(legacyEventFiles?.count ?? 0, 1)

        let amplitude = Amplitude(configuration: config)
        let deviceId = amplitude.getDeviceId()
        let userId = amplitude.getUserId()

        guard let eventFiles: [URL]? = amplitude.storage.read(key: StorageKey.EVENTS) else { return }

        var eventsString = ""
        eventFiles?.forEach { file in
            eventsString = legacyEventStorage.getEventsString(eventBlock: file) ?? ""
        }

        XCTAssertEqual(legacyDeviceId != nil, true)
        XCTAssertEqual(deviceId != nil, true)
        XCTAssertEqual(legacyDeviceId, deviceId)

        XCTAssertEqual(legacyUserId, userId)

        XCTAssertNotNil(legacyEventsString)

        #if os(macOS)
            // We don't want to transfer event data in non-sanboxed apps
            XCTAssertFalse(amplitude.isSandboxEnabled())
            XCTAssertEqual(eventFiles?.count ?? 0, 0)
        #else
            XCTAssertTrue(eventsString != "")
            XCTAssertEqual(legacyEventsString, eventsString)
            XCTAssertEqual(eventFiles?.count ?? 0, 1)
        #endif

        // clear storage
        amplitude.storage.reset()
        amplitude.identifyStorage.reset()
        legacyStorageAmplitude.storage.reset()
        legacyStorageAmplitude.identifyStorage.reset()
    }

    #if os(macOS)
        func testMigrationToApiKeyAndInstanceNameStorageMacSandboxEnabled() throws {
            let legacyUserId = "legacy-user-id"
            let config = Configuration(
                apiKey: "amp-mac-migration-api-key",
                // don't transfer any events
                flushQueueSize: 1000,
                flushIntervalMillis: 99999,
                logLevel: LogLevelEnum.DEBUG,
                autocapture: []
            )

        // Create storages using instance name only
        let legacyEventStorage = FakePersistentStorageAppSandboxEnabled(storagePrefix: "storage-\(config.getNormalizeInstanceName())", logger: self.logger, diagonostics: self.diagonostics)
        let legacyIdentityStorage = FakePersistentStorageAppSandboxEnabled(storagePrefix: "identify-\(config.getNormalizeInstanceName())", logger: self.logger, diagonostics: self.diagonostics)

            // Init Amplitude using legacy storage
            let legacyStorageAmplitude = FakeAmplitudeWithNoInstNameOnlyMigration(
                configuration: Configuration(
                    apiKey: config.apiKey,
                    flushQueueSize: config.flushQueueSize,
                    flushIntervalMillis: config.flushIntervalMillis,
                    storageProvider: legacyEventStorage,
                    identifyStorageProvider: legacyIdentityStorage,
                    logLevel: config.logLevel,
                    autocapture: config.autocapture
                ))

            let legacyDeviceId = legacyStorageAmplitude.getDeviceId()

            // set userId
            legacyStorageAmplitude.setUserId(userId: legacyUserId)
            XCTAssertEqual(legacyUserId, legacyStorageAmplitude.getUserId())

            // track events to legacy storage
            legacyStorageAmplitude.identify(identify: Identify().set(property: "user-prop", value: true))
            legacyStorageAmplitude.track(event: BaseEvent(eventType: "Legacy Storage Event"))
            legacyStorageAmplitude.waitForTrackingQueue()

            guard let legacyEventFiles: [URL]? = legacyEventStorage.read(key: StorageKey.EVENTS) else { return }

            var legacyEventsString = ""
            legacyEventFiles?.forEach { file in
                legacyEventsString = legacyEventStorage.getEventsString(eventBlock: file) ?? ""
            }

            XCTAssertEqual(legacyEventFiles?.count ?? 0, 1)

            let amplitude = FakeAmplitudeWithSandboxEnabled(configuration: config)
            let deviceId = amplitude.getDeviceId()
            let userId = amplitude.getUserId()

            guard let eventFiles: [URL]? = amplitude.storage.read(key: StorageKey.EVENTS) else { return }

            var eventsString = ""
            eventFiles?.forEach { file in
                eventsString = legacyEventStorage.getEventsString(eventBlock: file) ?? ""
            }

            XCTAssertEqual(legacyDeviceId != nil, true)
            XCTAssertEqual(deviceId != nil, true)
            XCTAssertEqual(legacyDeviceId, deviceId)

            XCTAssertEqual(legacyUserId, userId)

            XCTAssertNotNil(legacyEventsString)

            // Transfer event data in sandboxed apps
            XCTAssertTrue(eventsString == "")
            XCTAssertNotEqual(legacyEventsString, eventsString)
            XCTAssertEqual(eventFiles?.count ?? 0, 0)

            // clear storage
            amplitude.storage.reset()
            amplitude.identifyStorage.reset()
            legacyStorageAmplitude.storage.reset()
            legacyStorageAmplitude.identifyStorage.reset()
        }
    #endif

    func testRemnantDataNotMigratedInNonSandboxedApps() throws {
        let instanceName = "legacy_v3_\(UUID().uuidString)".lowercased()
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: type(of: self))
#endif
        let legacyDbUrl = bundle.url(forResource: "legacy_v3", withExtension: "sqlite")
        let dbUrl = LegacyDatabaseStorage.getDatabasePath(instanceName)
        let fileManager = FileManager.default
        let legacyDbExists = legacyDbUrl != nil ? fileManager.fileExists(atPath: legacyDbUrl!.path) : false
        XCTAssertTrue(legacyDbExists)

        try fileManager.copyItem(at: legacyDbUrl!, to: dbUrl)

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: dbUrl.path) {
                try fileManager.removeItem(at: dbUrl)
            }
        }

        let apiKey = "test-api-key"
        let configuration = Configuration(
            apiKey: apiKey,
            instanceName: instanceName,
            migrateLegacyData: true
        )
        let amplitude = Amplitude(configuration: configuration)

        let deviceId = "9B574574-74A7-4EDF-969D-164CB151B6C3"
        let userId = "ios-sample-user-legacy"

        #if os(macOS)
            // We don't want to transfer remnant data in non-sanboxed apps
            XCTAssertFalse(amplitude.isSandboxEnabled())
            XCTAssertNotEqual(amplitude.getDeviceId(), deviceId)
            XCTAssertNotEqual(amplitude.getUserId(), userId)
        #else
            XCTAssertEqual(amplitude.getDeviceId(), deviceId)
            XCTAssertEqual(amplitude.getUserId(), userId)
        #endif
    }

    #if os(macOS)
    func testRemnantDataNotMigratedInSandboxedMacApps() throws {
        let instanceName = "legacy_v3_\(UUID().uuidString)".lowercased()
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: type(of: self))
#endif
        let legacyDbUrl = bundle.url(forResource: "legacy_v3", withExtension: "sqlite")
        let dbUrl = LegacyDatabaseStorage.getDatabasePath(instanceName)
        let fileManager = FileManager.default
        let legacyDbExists = legacyDbUrl != nil ? fileManager.fileExists(atPath: legacyDbUrl!.path) : false
        XCTAssertTrue(legacyDbExists)

        try fileManager.copyItem(at: legacyDbUrl!, to: dbUrl)

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: dbUrl.path) {
                try fileManager.removeItem(at: dbUrl)
            }
        }

        let apiKey = "test-api-key"
        let configuration = Configuration(
            apiKey: apiKey,
            instanceName: instanceName,
            migrateLegacyData: true
        )
        let amplitude = FakeAmplitudeWithSandboxEnabled(configuration: configuration)

        let deviceId = "9B574574-74A7-4EDF-969D-164CB151B6C3"
        let userId = "ios-sample-user-legacy"

        XCTAssertTrue(amplitude.isSandboxEnabled())
        XCTAssertEqual(amplitude.getDeviceId(), deviceId)
        XCTAssertEqual(amplitude.getUserId(), userId)
    }
    #endif

    func testReset() {
        let amplitude = Amplitude(configuration: Configuration(apiKey: "test-api-key"))
        amplitude.setUserId(userId: "originalUserId")
        amplitude.setDeviceId(deviceId: "originalDeviceId")
        amplitude.reset()
        XCTAssertNil(amplitude.getUserId())
        XCTAssertNotEqual(amplitude.getDeviceId(), "originalDeviceId")
    }

    func testInit_Offline() {
        XCTAssertEqual(Amplitude(configuration: configuration).configuration.offline, false)
    }

    func testConcurrentAccess() {
        let amplitude = Amplitude(configuration: Configuration(apiKey: "test-api-key",
                                                               storageProvider: InMemoryStorage(),
                                                               autocapture: [.sessions, .appLifecycles]))
        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)
        let sessionID = Int64(Date().timeIntervalSince1970 * 1000)
        amplitude.setSessionId(timestamp: sessionID)

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            amplitude.onEnterForeground(timestamp: Int64(Date().timeIntervalSince1970 * 1000))
            amplitude.track(eventType: "Test Event \(i)")
            amplitude.onExitForeground(timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        }

        amplitude.waitForTrackingQueue()

        XCTAssertEqual(amplitude.getSessionId(), sessionID)

        var allEventIds = Set((0..<100).map { "Test Event \($0)" })
        allEventIds.insert("session_start")
        XCTAssertEqual(allEventIds, Set(eventCollector.events.map(\.eventType)))
    }

    func testDealloc() {
        class TestAmplitude: Amplitude {

            static let expectedEventType = "Test"

            class TestStorage: InMemoryStorage {

                private let expectation: XCTestExpectation

                init(expectation: XCTestExpectation) {
                    self.expectation = expectation
                }

                override func write(key: StorageKey, value: Any?) {
                    if key == .EVENTS, let event = value as? BaseEvent, event.eventType == TestAmplitude.expectedEventType {
                        expectation.fulfill()
                    }
                }
            }

            private let deallocExpectation: XCTestExpectation

            init(deallocExpectation: XCTestExpectation, trackExpectation: XCTestExpectation) {
                self.deallocExpectation = deallocExpectation
                super.init(configuration: Configuration(apiKey: "test-api-key",
                                                        storageProvider: TestStorage(expectation: trackExpectation)))
            }

            deinit {
                deallocExpectation.fulfill()
            }
        }

        let deallocExpectation = XCTestExpectation(description: "Amplitude object deallocates")
        let trackExpectation = XCTestExpectation(description: "Event persisted to storage")

        autoreleasepool {
            let amplitude = TestAmplitude(deallocExpectation: deallocExpectation,
                                          trackExpectation: trackExpectation)
            amplitude.track(eventType: TestAmplitude.expectedEventType)
            wait(for: [trackExpectation], timeout: 10.0)
        }
        wait(for: [deallocExpectation], timeout: 10.0)
    }

    func testTrimQueuedEvents() {
        class TrimTestStorage: Storage {

            private var events: [URL: Int] = [:]

            func addEventFile(url: URL, eventCount: Int) {
                events[url] = eventCount
            }

            func write(key: StorageKey, value: Any?) throws {}

            func read<T>(key: StorageKey) -> T? {
                switch key {
                case .EVENTS:
                    return events.keys.sorted(by: {$0.absoluteString < $1.absoluteString}) as? T
                default:
                    return nil
                }
            }

            func getEventsString(eventBlock: URL) -> String? {
                guard let eventCount = events[eventBlock] else {
                    return nil
                }

                let events = (0..<eventCount).map { BaseEvent(eventType: "Event \($0)") }

                guard let jsonData = try? JSONEncoder().encode(events) else {
                    return nil
                }

                return String(data: jsonData, encoding: .utf8)
            }

            func remove(eventBlock: URL) {
                events[eventBlock] = nil
            }

            func splitBlock(eventBlock: URL, events: [BaseEvent]) {}

            func rollover() {}

            func reset() {}

            func getResponseHandler(configuration: Configuration,
                                    eventPipeline: EventPipeline,
                                    eventBlock: URL,
                                    eventsString: String) -> ResponseHandler {
                abort()
            }
        }

        let storage = TrimTestStorage()
        storage.addEventFile(url: URL(string: "file://test/0")!, eventCount: 10)
        storage.addEventFile(url: URL(string: "file://test/1")!, eventCount: 10)
        storage.addEventFile(url: URL(string: "file://test/2")!, eventCount: 10)
        storage.addEventFile(url: URL(string: "file://test/3")!, eventCount: 10)

        let amplitude = Amplitude(configuration: Configuration(apiKey: "test-api-key",
                                                               storageProvider: storage,
                                                               maxQueuedEventCount: 15))
        amplitude.waitForTrackingQueue()

        let allEventBlocks: [URL] = storage.read(key: .EVENTS) ?? []

        XCTAssert(!allEventBlocks.contains(URL(string: "file://test/0")!))
        XCTAssert(!allEventBlocks.contains(URL(string: "file://test/1")!))
        XCTAssert(allEventBlocks.contains(URL(string: "file://test/2")!))
        XCTAssert(allEventBlocks.contains(URL(string: "file://test/3")!))
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
