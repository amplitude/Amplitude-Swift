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
