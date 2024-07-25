import XCTest

@testable import AmplitudeSwift

#if os(iOS)

class UIKitUserInteractionsTests: XCTestCase {
    func testExtractDataForUIButton() {
        let mockVC = UIViewController()
        mockVC.title = "Mock VC Title"

        let button = UIButton(type: .system)
        button.setTitle("Test Button", for: .normal)
        button.accessibilityLabel = "Accessibility Button"
        mockVC.view.addSubview(button)

        let buttonData = button.eventData

        XCTAssertEqual(buttonData.viewController, "UIViewController")
        XCTAssertEqual(buttonData.title, "Mock VC Title")
        XCTAssertEqual(buttonData.accessibilityLabel, "Accessibility Button")
        XCTAssertEqual(buttonData.targetViewClass, "UIButton")
        XCTAssertEqual(buttonData.targetText, "Test Button")
        XCTAssertTrue(buttonData.hierarchy.hasSuffix("UIButton → UIView"))
    }

    func testExtractDataForCustomView() {
        let mockVC = UIViewController()
        mockVC.title = "Mock VC Title"

        class CustomView: UIView {}
        let customView = CustomView()
        mockVC.view.addSubview(customView)

        let customViewData = customView.eventData

        XCTAssertEqual(customViewData.viewController, "UIViewController")
        XCTAssertEqual(customViewData.title, "Mock VC Title")
        XCTAssertNil(customViewData.accessibilityLabel)
        XCTAssertEqual(customViewData.targetViewClass, "CustomView")
        XCTAssertTrue(customViewData.hierarchy.hasSuffix("CustomView → UIView"))
    }

    func testExtractDataForOrphanView() {
        let orphanView = UIView()
        let orphanData = orphanView.eventData

        XCTAssertNil(orphanData.viewController)
        XCTAssertNil(orphanData.title)
        XCTAssertNil(orphanData.accessibilityLabel)
        XCTAssertEqual(orphanData.targetViewClass, "UIView")
        XCTAssertNil(orphanData.targetText)
        XCTAssertEqual(orphanData.hierarchy, "UIView")
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

#endif
