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

    func testDidFinishLaunching_ApplicationInstalled() {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: NSUUID().uuidString,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            defaultTracking: DefaultTrackingOptions(sessions: false, appLifecycles: true)
        )
        _ = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_INSTALLED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion
        ])
        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])
    }

    func testDidFinishLaunching_ApplicationUpdated() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: NSUUID().uuidString,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            defaultTracking: DefaultTrackingOptions(sessions: false, appLifecycles: true)
        )
        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: 123 as Int64)
        try storageMem.write(key: StorageKey.APP_BUILD, value: "abc")
        try storageMem.write(key: StorageKey.APP_VERSION, value: "xyz")
        _ = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_UPDATED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_PREVIOUS_BUILD_PROPERTY: "abc",
            Constants.AMP_APP_PREVIOUS_VERSION_PROPERTY: "xyz"
        ])
        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])
    }

    func testDidFinishLaunching_ApplicationOpened() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: NSUUID().uuidString,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            defaultTracking: DefaultTrackingOptions(sessions: false, appLifecycles: true)
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: 123 as Int64)
        try storageMem.write(key: StorageKey.APP_BUILD, value: currentBuild)
        try storageMem.write(key: StorageKey.APP_VERSION, value: currentVersion)
        _ = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])
    }

    func testWillEnterForeground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: NSUUID().uuidString,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            defaultTracking: DefaultTrackingOptions(sessions: false, appLifecycles: true)
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        _ = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[0].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: true
        ])
    }

    func testDidEnterBackground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            instanceName: NSUUID().uuidString,
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            defaultTracking: DefaultTrackingOptions(sessions: false, appLifecycles: true)
        )

        _ = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        let events = storageMem.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
        XCTAssertNil(events[0].eventProperties)
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
