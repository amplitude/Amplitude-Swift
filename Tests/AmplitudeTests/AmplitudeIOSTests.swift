import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
@testable import AmplitudeSwift

final class AmplitudeIOSTests: XCTestCase {
    private final class VersionStorage: FakeInMemoryStorage {
        override func read<T>(key: StorageKey) -> T? {
            assertVersionAccess(key)
            return super.read(key: key)
        }

        override func write(key: StorageKey, value: Any?) throws {
            assertVersionAccess(key)
            try super.write(key: key, value: value)
        }

        var allowsMainThreadVersionAccess = true

        private func assertVersionAccess(_ key: StorageKey) {
            if Thread.isMainThread && (key == .APP_BUILD || key == .APP_VERSION) {
                XCTAssertTrue(allowsMainThreadVersionAccess, "Lifecycle callback accessed version storage on main")
            }
        }
    }

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

    func testForegroundEventsStayAheadOfCallerEventsAndBackgrounding() throws {
        try assertLifecycleOrdering(notification: UIApplication.willEnterForegroundNotification, instanceName: #function)
    }

    func testActiveFallbackEventsStayAheadOfCallerEventsAndBackgrounding() throws {
        try assertLifecycleOrdering(notification: UIApplication.didBecomeActiveNotification, instanceName: #function)
    }

    func testColdLaunchEventsStayAheadOfCallerEventsAndBackgrounding() throws {
        try assertLifecycleOrdering(notification: UIApplication.didBecomeActiveNotification, instanceName: #function,
                                    initialState: .inactive, receivesLaunch: true)
    }

    private func assertLifecycleOrdering(notification: Notification.Name, instanceName: String,
                                         initialState: UIApplication.State = .background, receivesLaunch: Bool = false) throws {
        IOSVendorSystem.overrideApplicationState(initialState)
        IOSVendorSystem.overrideUsesScenes(false)
        let versionStorage = VersionStorage()
        try versionStorage.write(key: StorageKey.APP_BUILD, value: "old-build")
        try versionStorage.write(key: StorageKey.APP_VERSION, value: "old-version")
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "local-test", instanceName: instanceName,
            storageProvider: versionStorage, identifyStorageProvider: interceptStorageMem,
            autocapture: [.sessions, .appLifecycles],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        ))
        let collector = EventCollectorPlugin()
        amplitude.add(plugin: collector)
        amplitude.waitForTrackingQueue()

        versionStorage.allowsMainThreadVersionAccess = false
        let releaseQueue = DispatchSemaphore(value: 0)
        amplitude.trackingQueue.async { releaseQueue.wait() }
        IOSVendorSystem.overrideApplicationState(.inactive)
        if receivesLaunch {
            NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        }
        NotificationCenter.default.post(name: notification, object: nil)
        amplitude.track(eventType: "caller_event")
        IOSVendorSystem.overrideApplicationState(.background)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        releaseQueue.signal()
        for _ in 0..<4 { amplitude.waitForTrackingQueue() }

        versionStorage.allowsMainThreadVersionAccess = true
        XCTAssertEqual(versionStorage.read(key: .APP_BUILD) as String?, Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        XCTAssertEqual(collector.events.map { $0.eventType }, [
            Constants.AMP_SESSION_START_EVENT, Constants.AMP_APPLICATION_UPDATED_EVENT,
            Constants.AMP_APPLICATION_OPENED_EVENT, "caller_event", Constants.AMP_APPLICATION_BACKGROUNDED_EVENT
        ])
    }

    func testSDK727BackgroundLaunchDefersUntilForeground() throws {
        try assertBackgroundLifecycle(instanceName: #function, receivesLaunch: true, usesScenes: false)
    }

    func testSDK727SceneBackgroundLaunchDefersUntilForeground() throws {
        try assertBackgroundLifecycle(instanceName: #function, receivesLaunch: true, usesScenes: true)
    }

    func testSDK727LateBackgroundInitializationDefersUntilForeground() throws {
        try assertBackgroundLifecycle(instanceName: #function, receivesLaunch: false, usesScenes: true)
    }

    func testLateBackgroundInitializationOpensWhenForegroundNotificationWasMissed() throws {
        try assertBackgroundLifecycle(instanceName: #function, receivesLaunch: false, usesScenes: false)
    }

    func testSDK727BackgroundInstallDefersUntilForeground() throws {
        try assertBackgroundLifecycle(instanceName: #function, receivesLaunch: true, usesScenes: false, installed: true)
    }

    private func assertBackgroundLifecycle(instanceName: String, receivesLaunch: Bool,
                                           usesScenes: Bool, installed: Bool = false) throws {
        let lifecycleEvent = installed ? Constants.AMP_APPLICATION_INSTALLED_EVENT : Constants.AMP_APPLICATION_UPDATED_EVENT
        IOSVendorSystem.overrideApplicationState(.background)
        IOSVendorSystem.overrideUsesScenes(usesScenes)
        if !installed {
            try storageMem.write(key: StorageKey.APP_BUILD, value: "old-build")
            try storageMem.write(key: StorageKey.APP_VERSION, value: "old-version")
        }
        try storageMem.write(key: StorageKey.PREVIOUS_SESSION_ID, value: Int64(1000))
        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: Int64(1100))
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "local-test", instanceName: instanceName,
            storageProvider: storageMem, identifyStorageProvider: interceptStorageMem,
            minTimeBetweenSessionsMillis: 300000,
            autocapture: [.sessions, .appLifecycles],
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer()
        ))
        let eventCollector = EventCollectorPlugin()
        amplitude.add(plugin: eventCollector)
        amplitude.waitForTrackingQueue()
        if receivesLaunch {
            NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        }
        amplitude.track(event: BaseEvent(sessionId: -1, eventType: "background_work"))
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(storageMem.events().map { $0.eventType }, ["background_work"])
        XCTAssertEqual(amplitude.getSessionId(), 1000)
        XCTAssertEqual(storageMem.read(key: StorageKey.APP_BUILD) as String?, installed ? nil : "old-build")
        IOSVendorSystem.overrideApplicationState(.inactive)
        if usesScenes {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        for _ in 0..<4 { amplitude.waitForTrackingQueue() }
        let events = storageMem.events()
        XCTAssertEqual(events.map { $0.eventType }, ["background_work", Constants.AMP_SESSION_END_EVENT,
            Constants.AMP_SESSION_START_EVENT, lifecycleEvent, Constants.AMP_APPLICATION_OPENED_EVENT])
        XCTAssertNotEqual(amplitude.getSessionId(), 1000)
        XCTAssertTrue(events.dropFirst(2).allSatisfy { $0.sessionId == amplitude.getSessionId() })
        XCTAssertEqual(storageMem.read(key: StorageKey.APP_BUILD) as String?, Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        for _ in 0..<4 { amplitude.waitForTrackingQueue() }
        XCTAssertEqual(eventCollector.events.filter { $0.eventType == lifecycleEvent }.count, 1)
    }

    func testDidFinishLaunching_ApplicationInstalled() throws {
        IOSVendorSystem.overrideApplicationState(.inactive)
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
        IOSVendorSystem.overrideApplicationState(.inactive)
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

    func testLaunchUpdateUsesIdentityWhenTrackingRuns() throws {
        let update = try XCTUnwrap(try launchUpdate(instanceName: #function) { amplitude in
            amplitude.setUserId(userId: "after launch")
        })
        XCTAssertEqual(update.userId, "after launch")
    }

    func testLaunchUpdateRespectsOptOutWhenTrackingRuns() throws {
        XCTAssertNil(try launchUpdate(instanceName: #function) { amplitude in
            amplitude.configuration.optOut = true
        })
    }

    func testLaunchUpdateRespectsAutocaptureWhenTrackingRuns() throws {
        XCTAssertNil(try launchUpdate(instanceName: #function) { amplitude in
            amplitude.autocaptureManager.handleRemoteConfig(["appLifecycles": false])
        })
    }

    private func launchUpdate(instanceName: String, configure: (Amplitude) -> Void) throws -> BaseEvent? {
        IOSVendorSystem.overrideApplicationState(.inactive)
        IOSVendorSystem.overrideUsesScenes(false)
        try storageMem.write(key: .APP_BUILD, value: "old-build")
        try storageMem.write(key: .APP_VERSION, value: "old-version")
        let configuration = lifecycleConfiguration()
        configuration.instanceName = instanceName
        let amplitude = Amplitude(configuration: configuration)
        amplitude.setUserId(userId: "before launch")
        amplitude.waitForTrackingQueue()

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        configure(amplitude)
        IOSVendorSystem.overrideApplicationState(.active)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(storageMem.read(key: .APP_BUILD) as String?, Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        return storageMem.events().first { $0.eventType == Constants.AMP_APPLICATION_UPDATED_EVENT }
    }

    func testDidFinishLaunching_ApplicationOpened() throws {
        IOSVendorSystem.overrideApplicationState(.inactive)
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

        IOSVendorSystem.overrideApplicationState(.background)
        try storageMem.write(key: .APP_BUILD, value: currentBuild)
        try storageMem.write(key: .APP_VERSION, value: currentVersion)
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
        IOSVendorSystem.overrideApplicationState(.inactive)

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

    func testDidEnterBackground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            flushEventsOnClose: false,
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

        func applicationDidFinishLaunching(inBackground: Bool) {
            events.append(inBackground ? "background launch" : "launch")
        }

        func applicationDidBecomeActive(launch: Bool) {
            events.append(launch ? "initial activation" : "activation")
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

        XCTAssertEqual(observer.events, ["background launch", "foreground", "background"])
        XCTAssertEqual(observer.fromBackground, true)
    }

    func testColdLaunchWithoutScenesReportsActivationInsteadOfForeground() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        IOSVendorSystem.overrideUsesScenes(false)
        let lifecycle = VendorSystem.current.makeApplicationLifecycle()
        let observer = LifecycleObserver()
        lifecycle.addObserver(observer)
        lifecycle.start()

        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        IOSVendorSystem.overrideApplicationState(.active)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(observer.events, ["launch", "activation"])
    }

    func testLateBackgroundInitializationReportsLaunchOnceWithoutLaunchNotification() {
        IOSVendorSystem.overrideApplicationState(.background)
        let lifecycle = VendorSystem.current.makeApplicationLifecycle()
        let observer = LifecycleObserver()
        lifecycle.addObserver(observer)
        lifecycle.start()

        IOSVendorSystem.overrideApplicationState(.active)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(observer.events, ["initial activation"])
    }

    func testBackgroundLaunchSignalDefersInstallRegardlessOfUIKitState() {
        IOSVendorSystem.overrideApplicationState(.inactive)
        let amplitude = Amplitude(configuration: lifecycleConfiguration())

        amplitude.appLifecycle.didFinishLaunching(inBackground: true)
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()
        XCTAssertTrue(storageMem.events().isEmpty)
        XCTAssertNil(storageMem.read(key: .APP_BUILD) as String?)

        amplitude.appLifecycle.enterForeground()
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(storageMem.events().map(\.eventType), [
            Constants.AMP_SESSION_START_EVENT, Constants.AMP_APPLICATION_INSTALLED_EVENT, Constants.AMP_APPLICATION_OPENED_EVENT
        ])
    }

    func testRepeatedStartWhileActiveDeliversInitialActivationOnce() {
        IOSVendorSystem.overrideApplicationState(.active)
        let lifecycle = VendorSystem.current.makeApplicationLifecycle()
        let observer = LifecycleObserver()
        lifecycle.addObserver(observer)

        XCTAssertTrue(lifecycle.start { state in
            XCTAssertEqual(state, .active)
            XCTAssertTrue(observer.events.isEmpty)
        })
        XCTAssertFalse(lifecycle.start { _ in XCTFail("Startup state was already delivered") })

        XCTAssertEqual(observer.events, ["initial activation"])
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
                                                Constants.AMP_APPLICATION_INSTALLED_EVENT,
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

    func testBackgroundLaunchDefersInstallUntilForegroundAndBeforeOpened() {
        IOSVendorSystem.overrideApplicationState(.background)
        let amplitude = Amplitude(configuration: lifecycleConfiguration())
        amplitude.waitForTrackingQueue()

        amplitude.trackingQueue.suspend()
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        amplitude.trackingQueue.resume()
        amplitude.waitForTrackingQueue()
        amplitude.waitForTrackingQueue()

        XCTAssertEqual(storageMem.events().map(\.eventType), [Constants.AMP_SESSION_START_EVENT,
                                                             Constants.AMP_APPLICATION_INSTALLED_EVENT,
                                                             Constants.AMP_APPLICATION_OPENED_EVENT])
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
                                                             Constants.AMP_APPLICATION_INSTALLED_EVENT,
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
