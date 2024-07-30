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
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
        )
        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

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
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
        )
        try storageMem.write(key: StorageKey.LAST_EVENT_TIME, value: 123 as Int64)
        try storageMem.write(key: StorageKey.APP_BUILD, value: "abc")
        try storageMem.write(key: StorageKey.APP_VERSION, value: "xyz")
        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
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
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
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

        let events = storageMem.events()
        XCTAssertEqual(events.count, 0)
    }

    func testWillEnterForegroundFromBackground() throws {
        class TestApplication {

            static let sharedTest = TestApplication()

            @objc class var shared: AnyObject {
                return sharedTest
            }

            @objc var applicationState: UIApplication.State = .active
        }

        guard let originalMethod = class_getClassMethod(UIApplication.self, #selector(getter: UIApplication.shared)),
              let testMethod = class_getClassMethod(TestApplication.self, #selector(getter: TestApplication.shared)) else {
            XCTFail("Unable to find methods to swizzle")
            return
        }
        let originalImplementation = method_getImplementation(originalMethod)
        let testImplementation = method_getImplementation(testMethod)
        method_setImplementation(originalMethod, testImplementation)

        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let amplitude = Amplitude(configuration: configuration)

        TestApplication.sharedTest.applicationState = .inactive
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        TestApplication.sharedTest.applicationState = .background
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

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
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])

        // re-replace UIApplication.shared
        method_setImplementation(originalMethod, originalImplementation)
    }

    func testDidBecomeActivePreSceneDelegate() {

        class TestApplication: NSObject, UIApplicationDelegate {

            // Override UIApplicationDelegate to self, which does not implement application(_:configurationForConnecting:connectingSceneSession:)
            weak var delegate: UIApplicationDelegate? {
                return self
            }

            static let sharedTest = TestApplication()

            @objc class var shared: AnyObject {
                return sharedTest
            }
        }

        guard let originalMethod = class_getClassMethod(UIApplication.self, #selector(getter: UIApplication.shared)),
              let testMethod = class_getClassMethod(TestApplication.self, #selector(getter: TestApplication.shared)) else {
            XCTFail("Unable to find methods to swizzle")
            return
        }
        let originalImplementation = method_getImplementation(originalMethod)
        let testImplementation = method_getImplementation(testMethod)
        method_setImplementation(originalMethod, testImplementation)

        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
        )

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] ?? ""
        let currentVersion = info?["CFBundleShortVersionString"] ?? ""

        let amplitude = Amplitude(configuration: configuration)

        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        amplitude.waitForTrackingQueue()

        let events = storageMem.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].eventType, Constants.AMP_APPLICATION_OPENED_EVENT)
        XCTAssertEqual(getDictionary(events[1].eventProperties!), [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild,
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion,
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: false
        ])

        // re-replace UIApplication.shared
        method_setImplementation(originalMethod, originalImplementation)
    }

    func testDidEnterBackground() throws {
        let configuration = Configuration(
            apiKey: "api-key",
            storageProvider: storageMem,
            identifyStorageProvider: interceptStorageMem,
            autocapture: AutocaptureOptions(sessions: false, appLifecycles: true)
        )

        let amplitude = Amplitude(configuration: configuration)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        amplitude.waitForTrackingQueue()

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
