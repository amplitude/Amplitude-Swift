import XCTest

@testable import AmplitudeSwift

#if os(iOS)

class UIKitUserInteractionsTests: XCTestCase {
    func testExtractData() {
        let fakeWindow = FakeUIWindow()
        let fakeVC = FakeUIViewController()
        let fakeButton = FakeUIButton()
        fakeButton.fakeTitleLabel?.text = "Button Text"
        fakeWindow.fakeRootViewController = fakeVC

        let data = fakeButton.extractData(with: #selector(FakeUIButton.someAction), in: fakeWindow)

        XCTAssertEqual(data.viewController, "FakeUIViewController")
        XCTAssertEqual(data.title, "TestVC")
        XCTAssertEqual(data.actionMethod, "someAction")
        XCTAssertEqual(data.targetViewClass, "FakeUIButton")
        XCTAssertEqual(data.targetText, "Button Text")
    }

    func testDescriptiveTypeName() {
        let button = UIButton()
        XCTAssertEqual(button.descriptiveTypeName, "UIButton")

        let vc = UIViewController()
        XCTAssertEqual(vc.descriptiveTypeName, "UIViewController")

        class ConstrainedGenericView<T: UIView>: UIView {}
        XCTAssertEqual(ConstrainedGenericView<UIButton>().descriptiveTypeName, "ConstrainedGenericView<UIButton>")
    }
}

class FakeUIWindow: UIWindow {
    var fakeRootViewController: UIViewController?

    override var rootViewController: UIViewController? {
        get { return fakeRootViewController }
        set {}
    }
}

class FakeUIViewController: UIViewController {
    var fakeTitle: String? = "TestVC"

    override var title: String? {
        get { return fakeTitle }
        set {}
    }
}

class FakeUIButton: UIButton {
    var fakeTitleLabel: UILabel? = UILabel()

    override var titleLabel: UILabel? {
        return fakeTitleLabel
    }

    @objc func someAction() {
        // no-op
    }
}

#endif
