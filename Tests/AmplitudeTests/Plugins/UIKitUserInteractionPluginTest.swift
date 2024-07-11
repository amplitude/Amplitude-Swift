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

        let buttonData = button.extractData(with: #selector(UIButton.touchesEnded))

        XCTAssertEqual(buttonData.viewController, "UIViewController")
        XCTAssertEqual(buttonData.title, "Mock VC Title")
        XCTAssertEqual(buttonData.accessibilityLabel, "Accessibility Button")
        XCTAssertEqual(buttonData.actionMethod, "touchesEnded:withEvent:")
        XCTAssertEqual(buttonData.targetViewClass, "UIButton")
        XCTAssertEqual(buttonData.targetText, "Test Button")
        XCTAssertTrue(buttonData.hierarchy.hasSuffix("UIButton -> UIView"))
    }

    func testExtractDataForCustomView() {
        let mockVC = UIViewController()
        mockVC.title = "Mock VC Title"

        class CustomView: UIView {}
        let customView = CustomView()
        mockVC.view.addSubview(customView)

        let customViewData = customView.extractData(with: #selector(UIView.layoutSubviews))

        XCTAssertEqual(customViewData.viewController, "UIViewController")
        XCTAssertEqual(customViewData.title, "Mock VC Title")
        XCTAssertNil(customViewData.accessibilityLabel)
        XCTAssertEqual(customViewData.actionMethod, "layoutSubviews")
        XCTAssertEqual(customViewData.targetViewClass, "CustomView")
        XCTAssertTrue(customViewData.hierarchy.hasSuffix("CustomView -> UIView"))
    }

    func testExtractDataForOrphanView() {
        let orphanView = UIView()
        let orphanData = orphanView.extractData(with: #selector(UIView.removeFromSuperview))

        XCTAssertNil(orphanData.viewController)
        XCTAssertNil(orphanData.title)
        XCTAssertNil(orphanData.accessibilityLabel)
        XCTAssertEqual(orphanData.actionMethod, "removeFromSuperview")
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
