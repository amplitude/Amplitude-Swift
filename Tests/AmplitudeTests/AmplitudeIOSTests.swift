import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
@testable import AmplitudeSwift

final class AmplitudeIOSTests: XCTestCase {
    private var storageMem: FakeInMemoryStorage!
    private var interceptStorageMem: FakeInMemoryStorage!
    private var window: UIWindow!
    private var rootViewController: UIViewController!

    override func setUp() {
        super.setUp()
        storageMem = FakeInMemoryStorage()
        interceptStorageMem = FakeInMemoryStorage()

        window = UIWindow()
        rootViewController = UIViewController()
        window.addSubview(rootViewController.view)
    }

    override func tearDown() {
        IOSVendorSystem.overrideApplicationState(nil)
        IOSVendorSystem.overrideUsesScenes(nil)
        super.tearDown()
    }

    func testDidFinishLaunching_ApplicationInstalled() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: #function,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )
        let amplitude = Amplitude(configuration: configuration)
        try storageMem.write(key: StorageKey.APP_BUILD, value: nil)
        try storageMem.write(key: StorageKey.APP_VERSION, value: nil)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_INSTALLED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion
        ])
    }

    func testDidFinishLaunching_ApplicationUpdated() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: #function,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )
        try storageMem.write(key: StorageKey.APP_BUILD, value: "abc")
        try storageMem.write(key: StorageKey.APP_VERSION, value: "xyz")
        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_UPDATED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_PREVIOUS_BUILD_PROPERTY: "abc",
            Constants.AMP_APP_PREVIOUS_VERSION_PROPERTY: "xyz"
        ])
    }

    func testDidFinishLaunching_ApplicationOpened() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: 123 as Int64)
        try storageMem.write(key: StorageKey.APP_BUILD, value: currentBuild)
        try storageMem.write(key: StorageKey.APP_VERSION, value: currentVersion)
        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 0)
    }

    func testWillEnterForegroundFromBackground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let amplitude = Amplitude(configuration: configuration)

        IOSVendorSystem.overrideApplicationState(.inactive)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        IOSVendorSystem.overrideApplicationState(.background)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])

        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: true
        ])
    }

    func testDidBecomeActivePreSceneDelegate() {

        IOSVendorSystem.overrideUsesScenes(false)

        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: #function,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let amplitude = Amplitude(configuration: configuration)

        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])
    }

    func testFlushTimerStopsOnBackgroundOrExpirationAndResumesOnForeground() throws {
        class ExpiringVendor: IOSVendorSystem {
            var shouldExpire = true
            var onExpire: (() -> Void)?
            override func beginBackgroundTask(label: String? = nil, expirationHandler: @escaping () -> Void) -> BackgroundTaskCompletionCallback? {
                if shouldExpire {
                    expirationHandler()
                    onExpire?()
                }
                return {}
            }
        }
        IOSVendorSystem.overrideApplicationState(.background)
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer())
        config.flushEventsOnClose = false
        let amplitude = Amplitude(configuration: config)
        let vendor = ExpiringVendor()
        let pipeline = EventPipeline(amplitude: amplitude, vendorSystem: vendor)
        let uploadQueue = pipeline.httpClient.callbackQueue
        amplitude.waitForTrackingQueue()
        amplitude.trackingQueue.suspend()
        defer { amplitude.trackingQueue.resume() }
        XCTAssertEqual(pipeline.flushTimer?.state, .resumed, "Preserve timer startup for a background launch")

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.state, .suspended, "Backgrounding stops periodic flushing")

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.state, .resumed)
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "expiring-upload"))
        let expired = expectation(description: "response processed after expiration")
        pipeline.flush { expired.fulfill() }
        wait(for: [expired], timeout: 10)
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.state, .suspended)

        vendor.shouldExpire = false
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "explicit-background-flush"))
        let flushed = expectation(description: "explicit flush is blocked after expiration")
        pipeline.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 10)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(pipeline.flushTimer?.state, .suspended)

        for _ in 0..<2 {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.state, .resumed)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        let foregroundFlush = expectation(description: "flushes remain allowed after backgrounding without expiry")
        pipeline.flush { foregroundFlush.fulfill() }
        wait(for: [foregroundFlush], timeout: 10)
        let remaining: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(remaining.isEmpty)

        // Backgrounding must preserve a suspension; only foregrounding resumes it.
        for notification in [UIApplication.willEnterForegroundNotification, UIApplication.didEnterBackgroundNotification] {
            let expectedState: QueueTimer.State = notification == UIApplication.willEnterForegroundNotification ? .resumed : .suspended
            pipeline.stop()
            NotificationCenter.default.post(name: notification, object: nil)
            uploadQueue.sync {}
            XCTAssertEqual(pipeline.flushTimer?.state, expectedState)

            vendor.shouldExpire = true
            vendor.onExpire = {
                NotificationCenter.default.post(name: notification, object: nil)
            }
            try storage.write(key: .EVENTS, value: BaseEvent(eventType: "lifecycle-transition-during-expiry"))
            let transitioned = expectation(description: "expiry and lifecycle transitions preserve timer policy")
            pipeline.flush { transitioned.fulfill() }
            wait(for: [transitioned], timeout: 10)
            uploadQueue.sync {}
            XCTAssertEqual(pipeline.flushTimer?.state, expectedState)
            vendor.onExpire = nil
        }
    }

    func testInitialActivationResumesTimerWithoutWaitingForTracking() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        let configuration = Configuration(
            apiKey: "test", flushIntervalMillis: 3_600_000, instanceName: UUID().uuidString,
            storageProvider: storageMem, identifyStorageProvider: interceptStorageMem,
            autocapture: [.appLifecycles, .sessions],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer()
        )
        let amplitude = Amplitude(configuration: configuration)
        let pipeline = EventPipeline(amplitude: amplitude)
        let uploadQueue = pipeline.httpClient.callbackQueue
        amplitude.waitForTrackingQueue()
        pipeline.stop()
        uploadQueue.sync {}

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.state, .resumed)
        XCTAssertTrue(storageMem.events().isEmpty)
        amplitude.trackingQueue.resume()

        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()
        let eventTypes = storageMem.events().map(\.eventType)
        XCTAssertEqual(eventTypes, [Constants.AMP_SESSION_START_EVENT,
                                    Constants.AMP_APPLICATION_INSTALLED_EVENT,
                                    Constants.AMP_APPLICATION_OPENED_EVENT])
    }

    func testDidEnterBackground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )

        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        amplitude.waitForTrackingQueue()
        // Lifecycle consumers enqueue event processing on the same queue.
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.eventType, Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
        XCTAssertNil(event.eventProperties)
    }

    func testSetupWhileAppInactive() {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: #function,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .appLifecycles,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        IOSVendorSystem.overrideApplicationState(.inactive)
        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])
    }

    private final class LifecycleObserver: ApplicationLifecycleObserver {
        var events: [String] = []
        var fromBackground: Bool?

        func applicationDidFinishLaunching() {
            events.append("launch")
        }

        func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
            events.append("foreground")
            self.fromBackground = fromBackground
        }

        func applicationDidEnterBackground(timestamp: Int64) {
            events.append("background")
        }
    }

    func testLifecycleSourceWorksWithoutAmplitude() {
        IOSVendorSystem.overrideApplicationState(.background)
        let lifecycle = VendorSystem.current.makeApplicationLifecycle()
        let observer = LifecycleObserver()
        lifecycle.addObserver(observer)
        lifecycle.addObserver(observer)
        lifecycle.start()
        lifecycle.start() // Repeated plugin setup must not duplicate platform notification delivery.
        XCTAssertTrue(observer.events.isEmpty, "A background launch should not synthesize a transition")

        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(observer.events, ["launch", "foreground", "background"])
        XCTAssertEqual(observer.fromBackground, true)
    }

    func testLifecycleDoesNotRetainObservers() {
        let lifecycle = ApplicationLifecycle()
        weak var observer: LifecycleObserver?
        autoreleasepool {
            let temporaryObserver = LifecycleObserver()
            observer = temporaryObserver
            lifecycle.addObserver(temporaryObserver)
        }
        XCTAssertNil(observer)
        lifecycle.enterForeground()
    }

    func testForegroundPrecedesTrackingWhileQueueIsBlocked() throws {
        IOSVendorSystem.overrideApplicationState(.background)
        let configuration = Configuration(
            apiKey: "test", instanceName: UUID().uuidString,
            storageProvider: storageMem, identifyStorageProvider: interceptStorageMem,
            autocapture: [.appLifecycles, .sessions],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer()
        )
        let amplitude = Amplitude(configuration: configuration)
        amplitude.waitForTrackingQueue()
        let laterTimestamp = Int64(Date().timeIntervalSince1970 * 1000) + Int64(configuration.minTimeBetweenSessionsMillis * 2)

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        amplitude.track(event: BaseEvent(timestamp: laterTimestamp, eventType: "after foreground"))
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                Constants.AMP_APPLICATION_OPENED_EVENT,
                                                "after foreground"])
        let sessionId = try XCTUnwrap(events.first?.sessionId)
        XCTAssertLessThan(sessionId, laterTimestamp, "Foregrounding establishes the session before the subsequent event")
        XCTAssertEqual(events.last?.sessionId, sessionId, "Foreground events keep the session despite a long gap")
    }

    func testBackgroundPrecedesTrackingWhileQueueIsBlocked() {
        IOSVendorSystem.overrideApplicationState(.active)
        let configuration = Configuration(
            apiKey: "test", instanceName: UUID().uuidString,
            storageProvider: storageMem, identifyStorageProvider: interceptStorageMem,
            autocapture: [.appLifecycles, .sessions],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer()
        )
        configuration.flushEventsOnClose = false
        let amplitude = Amplitude(configuration: configuration)
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()
        let initialEventCount = storageMem.events().count
        let laterTimestamp = Int64(Date().timeIntervalSince1970 * 1000) + Int64(configuration.minTimeBetweenSessionsMillis * 2)

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        amplitude.track(event: BaseEvent(timestamp: laterTimestamp, eventType: "after background"))
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = Array(storageMem.events().dropFirst(initialEventCount))
        XCTAssertEqual(events.map(\.eventType), [Constants.AMP_APPLICATION_BACKGROUNDED_EVENT,
                                                Constants.AMP_SESSION_END_EVENT,
                                                Constants.AMP_SESSION_START_EVENT,
                                                "after background"])
        XCTAssertEqual(events.last?.sessionId, laterTimestamp, "Background events respect the session timeout")
    }

    func testLaunchAndForegroundPreserveDeferredInstallOrdering() {
        IOSVendorSystem.overrideApplicationState(.background)
        let amplitude = Amplitude(configuration: lifecycleConfiguration())
        amplitude.waitForTrackingQueue()

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        // The original launch handler generated its event on tracking, after foreground work was queued.
        XCTAssertEqual(storageMem.events().map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                             Constants.AMP_APPLICATION_OPENED_EVENT,
                                                             Constants.AMP_APPLICATION_INSTALLED_EVENT])
    }

    func testInitialActivationDefersIdentityCaptureAndEventGeneration() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        let amplitude = Amplitude(configuration: lifecycleConfiguration())
        amplitude.waitForTrackingQueue()
        amplitude.setUserId(userId: "before activation")

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        amplitude.setUserId(userId: "after activation")
        amplitude.track(eventType: "queued during activation")
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                "queued during activation",
                                                Constants.AMP_APPLICATION_INSTALLED_EVENT,
                                                Constants.AMP_APPLICATION_OPENED_EVENT])
        XCTAssertTrue(events.allSatisfy { $0.userId == "after activation" })
    }

    func testInitialActivationReadsOptOutWhenTrackingRuns() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        let config = lifecycleConfiguration()
        let amplitude = Amplitude(configuration: config)
        amplitude.waitForTrackingQueue()

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        config.optOut = true
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        XCTAssertTrue(storageMem.events().isEmpty)
    }

    func testInitialActivationReadsAutocaptureWhenTrackingRuns() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        let amplitude = Amplitude(configuration: lifecycleConfiguration())
        amplitude.waitForTrackingQueue()

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        amplitude.autocaptureManager.handleRemoteConfig(["appLifecycles": false])
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(storageMem.events().map(\.eventType), [Constants.AMP_SESSION_START_EVENT])
    }

    func testActiveInitializationDefersVersionStorageAccess() {
        class ObservingStorage: FakeInMemoryStorage {
            var onBuildRead: (() -> Void)?
            override func read<T>(key: StorageKey) -> T? {
                if key == .APP_BUILD { onBuildRead?() }
                return super.read(key: key)
            }
        }
        IOSVendorSystem.overrideApplicationState(.active)
        let storage = ObservingStorage()
        let callerQueue = DispatchQueue(label: "lifecycle-initialization-caller")
        let callerKey = DispatchSpecificKey<Bool>()
        callerQueue.setSpecific(key: callerKey, value: true)
        let readBuild = expectation(description: "version storage accessed off the initialization thread")
        storage.onBuildRead = {
            XCTAssertNil(DispatchQueue.getSpecific(key: callerKey))
            readBuild.fulfill()
        }
        let config = lifecycleConfiguration(storage: storage)
        let amplitude = callerQueue.sync { Amplitude(configuration: config) }
        wait(for: [readBuild], timeout: 10)
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()
    }

    func testNotificationsAreObservedDuringContextPluginSetup() {
        IOSVendorSystem.overrideApplicationState(.background)
        var postedDuringSetup = false
        let logger = ObjCLoggerProviderWrapper(logLevel: .warn) { _, message in
            guard message.hasPrefix("Configured deviceId") else { return }
            postedDuringSetup = true
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        let config = lifecycleConfiguration()
        config.loggerProvider = logger
        // ContextPlugin warns about this configured ID during setup, after lifecycle setup.
        config.deviceId = "00000000-0000-0000-0000-000000000000"
        let amplitude = Amplitude(configuration: config)
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        XCTAssertTrue(postedDuringSetup)
        XCTAssertEqual(storageMem.events().map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                             Constants.AMP_APPLICATION_OPENED_EVENT,
                                                             Constants.AMP_APPLICATION_BACKGROUNDED_EVENT])
    }

    private func lifecycleConfiguration(storage: FakeInMemoryStorage? = nil) -> Configuration {
        Configuration(apiKey: "test", instanceName: UUID().uuidString,
                      storageProvider: storage ?? storageMem, identifyStorageProvider: interceptStorageMem,
                      flushEventsOnClose: false, autocapture: [.appLifecycles, .sessions],
                      offline: NetworkConnectivityCheckerPlugin.Disabled,
                      enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer())
    }

    func testInitialActivationPreservesLifecycleEventOrder() {
        for appState in [UIApplication.State.active, .inactive] {
            IOSVendorSystem.overrideApplicationState(appState)
            let storage = FakeInMemoryStorage()
            let configuration = Configuration(
                apiKey: "test", instanceName: UUID().uuidString,
                storageProvider: storage, identifyStorageProvider: FakeInMemoryStorage(),
                autocapture: [.appLifecycles, .sessions],
                offline: NetworkConnectivityCheckerPlugin.Disabled,
                enableAutoCaptureRemoteConfig: false, userId: "test-user", deviceId: "test-device",
                httpClient: RemoteConfigMockServer()
            )
            let amplitude = Amplitude(configuration: configuration)
            if appState == .inactive {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            amplitude.waitForTrackingQueue()
            amplitude.waitForTrackingQueue()

            let events = storage.events()
            XCTAssertEqual(events.map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                    Constants.AMP_APPLICATION_INSTALLED_EVENT,
                                                    Constants.AMP_APPLICATION_OPENED_EVENT])
            for event in events {
                XCTAssertEqual(event.userId, "test-user")
                XCTAssertEqual(event.deviceId, "test-device")
            }
        }
    }

    func testSetIdentityForAutoCapturedEvents() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: .sessions,
            enableAutoCaptureRemoteConfig: false,
            userId: "test-user",
            deviceId: "test-device",
            httpClient: RemoteConfigMockServer()
        )

        // force new session event to fire immediately
        IOSVendorSystem.overrideApplicationState(.active)

        let amplitude = Amplitude(configuration: configuration)
        amplitude.waitForTrackingQueue()
        // wait twice for async event generate
        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        for event in events {
            XCTAssertEqual(event.userId, "test-user")
            XCTAssertEqual(event.deviceId, "test-device")
        }
    }

    func testTopViewController_rootController() {
        let controller = UIViewController.amp_topViewController(rootViewController)
        XCTAssertEqual(rootViewController, controller)
    }

    func testTopViewController_presentedController() {
        let presentController = UIViewController()
        rootViewController.present(presentController, animated: false)

        let controller = UIViewController.amp_topViewController(rootViewController)
        XCTAssertEqual(presentController, controller)
    }

    func testTopViewController_navigationPushedController() {
        let navigationController = UINavigationController()
        rootViewController.present(navigationController, animated: false)

        let controller = UIViewController()
        navigationController.pushViewController(controller, animated: false)

        XCTAssertEqual(controller, UIViewController.amp_topViewController(rootViewController))
    }

    func testTopViewController_selectedTabBarController() {
        let tabBarController = UITabBarController()
        rootViewController.present(tabBarController, animated: false)

        let controller = UIViewController()
        tabBarController.setViewControllers([UIViewController(), controller, UIViewController()], animated: false)
        tabBarController.selectedIndex = 1

        XCTAssertEqual(controller, UIViewController.amp_topViewController(rootViewController))
    }

    func testTopViewController_firstChildViewController() {
        let containerController = UIViewController()
        rootViewController.present(containerController, animated: false)

        let controller = UIViewController()
        containerController.addChild(controller)
        containerController.addChild(UIViewController())

        XCTAssertEqual(controller, UIViewController.amp_topViewController(rootViewController))
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        NSDictionary(dictionary: props as [AnyHashable: Any])
    }
}
#endif
