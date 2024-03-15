//
//  UIKitScreenViewsTests.swift
//  Amplitude-SwiftTests
//
//  Created by Chris Leonavicius on 3/12/24.
//

import XCTest

@testable import AmplitudeSwift

#if os(iOS)

final class UIKitScreenViewsPluginTests: XCTestCase {

    func testScreenNameWithTitle() {
        let viewController = UIKitScreenViewsPluginTestViewController()
        viewController.title = "My test screen"

        XCTAssertEqual(viewController.title, UIKitScreenViews.screenName(for: viewController))
    }

    func testScreenNameFromClass() {
        let viewController = UIKitScreenViewsPluginTestViewController()

        XCTAssertEqual("UIKitScreenViewsPluginTest", UIKitScreenViews.screenName(for: viewController))
    }

    func testScreenNameFallback() {
        let viewController = ViewControllerViewController()

        XCTAssertEqual("Unknown", UIKitScreenViews.screenName(for: viewController))
    }

    private class UIKitScreenViewsPluginTestViewController: UIViewController {

    }

    private class ViewControllerViewController: UIViewController {

    }
}

#endif
