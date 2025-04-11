//
//  MethodSwizzlerTest.swift
//  Amplitude-SwiftTests
//
//  Created by Jin Xu on 3/13/25.
//

import XCTest

@testable import AmplitudeSwift

private class TestClass {
    var results: [String] = []

    @discardableResult
    @objc dynamic func testMethod() -> String {
        let result = "Original_IMP"
        results.append(result)
        return result
    }
}

extension TestClass {
    @objc fileprivate dynamic func swizzledMethodA() -> String {
        let result = "Swizzled_IMP_A"
        results.append(result)

        _ = swizzledMethodA()
        return result
    }

    @objc fileprivate dynamic func swizzledMethodB() -> String {
        let result = "Swizzled_IMP_B"
        results.append(result)

        _ = swizzledMethodB()
        return result
    }
}

final class MethodSwizzlerTest: XCTestCase {

    override func tearDown() {
        super.tearDown()

        MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self, originalSelector: #selector(TestClass.testMethod), swizzledSelector: #selector(TestClass.swizzledMethodA))
        MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self, originalSelector: #selector(TestClass.testMethod), swizzledSelector: #selector(TestClass.swizzledMethodB))
    }

    func testSwizzleMethod() {
        let success = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                           originalSelector: #selector(TestClass.testMethod),
                                                           swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(success, "Swizzling should be successful")
        let testInstance = TestClass()
        XCTAssertEqual(testInstance.testMethod(), "Swizzled_IMP_A", "Swizzling should work")
    }

    func testSwizzleMethodWithSameSelector() {
        MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                             originalSelector: #selector(TestClass.testMethod),
                                             swizzledSelector: #selector(TestClass.swizzledMethodA))

        let success = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                           originalSelector: #selector(TestClass.testMethod),
                                                           swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertFalse(success, "Swizzling same method should not be successful")
    }

    func testUnswizzleMethod() {
        MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                             originalSelector: #selector(TestClass.testMethod),
                                             swizzledSelector: #selector(TestClass.swizzledMethodA))
        let unswizzledSuccess = MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self,
                                                                       originalSelector: #selector(TestClass.testMethod),
                                                                       swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(unswizzledSuccess, "Unswizzling should be successful")

        let testInstance = TestClass()
        XCTAssertEqual(testInstance.testMethod(), "Original_IMP", "Unswizzling should work")
        XCTAssertEqual(testInstance.results, ["Original_IMP"], "Swizzled method should not be called")
    }

    func testBothMethodCalled() {
        MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                             originalSelector: #selector(TestClass.testMethod),
                                             swizzledSelector: #selector(TestClass.swizzledMethodA))
        let testInstance = TestClass()
        XCTAssertEqual(testInstance.testMethod(), "Swizzled_IMP_A", "Swizzling should work")
        XCTAssertEqual(testInstance.results, ["Swizzled_IMP_A", "Original_IMP"], "Both methods should be called")
    }

    func testSwizzleMethodTwice() {
        let successA = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                            originalSelector: #selector(TestClass.testMethod),
                                                            swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(successA, "Swizzling should be successful")
        let successB = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                            originalSelector: #selector(TestClass.testMethod),
                                                            swizzledSelector: #selector(TestClass.swizzledMethodB))
        XCTAssertTrue(successB, "Swizzling should be successful")

        let testInstance = TestClass()
        XCTAssertEqual(testInstance.testMethod(), "Swizzled_IMP_B", "Swizzling should work")
        XCTAssertEqual(testInstance.results, ["Swizzled_IMP_B", "Swizzled_IMP_A", "Original_IMP"], "All methods should be called")
    }

    func testSwizzleMethodTwiceAndUnswizzleWithReverseOrder() {
        MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                             originalSelector: #selector(TestClass.testMethod),
                                             swizzledSelector: #selector(TestClass.swizzledMethodA))
        MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                             originalSelector: #selector(TestClass.testMethod),
                                             swizzledSelector: #selector(TestClass.swizzledMethodB))
        // unswizzle B
        let unswizzleB = MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self,
                                                                originalSelector: #selector(TestClass.testMethod),
                                                                swizzledSelector: #selector(TestClass.swizzledMethodB))
        XCTAssertTrue(unswizzleB, "Unswizzling should be successful")

        let testInstanceUnswizzledB = TestClass()
        XCTAssertEqual(testInstanceUnswizzledB.testMethod(), "Swizzled_IMP_A", "Unswizzling should work")
        XCTAssertEqual(testInstanceUnswizzledB.results, ["Swizzled_IMP_A", "Original_IMP"], "Swizzled B should be unswizzled")

        // unswizzle A
        let unswizzleA = MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self,
                                                                originalSelector: #selector(TestClass.testMethod),
                                                                swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(unswizzleA, "Unswizzling should be successful")

        let testInstanceUnswizzledA = TestClass()
        XCTAssertEqual(testInstanceUnswizzledA.testMethod(), "Original_IMP", "Unswizzling should work")
        XCTAssertEqual(testInstanceUnswizzledA.results, ["Original_IMP"], "Swizzled A should be unswizzled")
    }

    func testSwizzleMethodTwiceAndUnswizzleWithSameOrder() {
        let successA = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                            originalSelector: #selector(TestClass.testMethod),
                                                            swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(successA, "Swizzling should be successful")
        let successB = MethodSwizzler.swizzleInstanceMethod(for: TestClass.self,
                                                            originalSelector: #selector(TestClass.testMethod),
                                                            swizzledSelector: #selector(TestClass.swizzledMethodB))
        XCTAssertTrue(successB, "Swizzling should be successful")

        let testInstance = TestClass()
        XCTAssertEqual(testInstance.testMethod(), "Swizzled_IMP_B", "Swizzling should work")
        XCTAssertEqual(testInstance.results, ["Swizzled_IMP_B", "Swizzled_IMP_A", "Original_IMP"], "All methods should be called")

        // unswizzle A
        let unswizzleA = MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self,
                                                                originalSelector: #selector(TestClass.testMethod),
                                                                swizzledSelector: #selector(TestClass.swizzledMethodA))
        XCTAssertTrue(unswizzleA, "Unswizzling should be successful")

        let testInstanceUnswizzledA = TestClass()
        XCTAssertEqual(testInstanceUnswizzledA.testMethod(), "Swizzled_IMP_B", "Unswizzling should work")
        XCTAssertEqual(testInstanceUnswizzledA.results, ["Swizzled_IMP_B", "Original_IMP"], "Swizzled A should be unswizzled")

        // unswizzle B
        let unswizzleB = MethodSwizzler.unswizzleInstanceMethod(for: TestClass.self,
                                                                originalSelector: #selector(TestClass.testMethod),
                                                                swizzledSelector: #selector(TestClass.swizzledMethodB))
        XCTAssertTrue(unswizzleB, "Unswizzling should be successful")

        let testInstanceUnswizzledB = TestClass()
        XCTAssertEqual(testInstanceUnswizzledB.testMethod(), "Original_IMP", "Unswizzling should work")
        XCTAssertEqual(testInstanceUnswizzledB.results, ["Original_IMP"], "Swizzled B should be unswizzled")
    }
}
