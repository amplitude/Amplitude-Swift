//
//  RageClickTests.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

import XCTest
@testable import AmplitudeSwift

class RageClickTests: XCTestCase {
    
    func testInteractionsOptionsDefaults() {
        let options = InteractionsOptions()
        
        XCTAssertEqual(options.rageClick.threshold, 3)
        XCTAssertEqual(options.rageClick.timeout, 1000)
    }
    
    func testRageClickOptionsCustomValues() {
        let rageClickOptions = RageClickOptions(threshold: 5, timeout: 2000)
        let options = InteractionsOptions(rageClick: rageClickOptions)
        
        XCTAssertEqual(options.rageClick.threshold, 5)
        XCTAssertEqual(options.rageClick.timeout, 2000)
    }
    
    func testRageClickOptionsMinimumValues() {
        // Test that minimum values are enforced
        let rageClickOptions = RageClickOptions(threshold: 1, timeout: 500)
        
        XCTAssertEqual(rageClickOptions.threshold, 3) // Should be enforced to minimum of 3
        XCTAssertEqual(rageClickOptions.timeout, 1000) // Should be enforced to minimum of 1000
    }
    
    func testConfigurationWithInteractionsOptions() {
        let rageClickOptions = RageClickOptions(threshold: 4, timeout: 1500)
        let interactionsOptions = InteractionsOptions(rageClick: rageClickOptions)
        
        let config = Configuration(
            apiKey: "test-api-key",
            interactionsOptions: interactionsOptions
        )
        
        XCTAssertEqual(config.interactionsOptions.rageClick.threshold, 4)
        XCTAssertEqual(config.interactionsOptions.rageClick.timeout, 1500)
    }
    
    func testRageClickEventCreation() {
        let clicks = [
            Click(x: 100, y: 200, time: "2025-05-23T10:00:00.123Z"),
            Click(x: 105, y: 205, time: "2025-05-23T10:00:01.456Z"),
            Click(x: 102, y: 198, time: "2025-05-23T10:00:02.789Z")
        ]
        
        let beginTime = Date()
        let endTime = Date(timeInterval: 2, since: beginTime)
        
        let rageClickEvent = RageClickEvent(
            beginTime: beginTime,
            endTime: endTime,
            clicks: clicks,
            action: "tap",
            targetViewClass: "UIButton",
            hierarchy: "UIWindow → UIViewController → UIButton"
        )
        
        XCTAssertEqual(rageClickEvent.eventType, "[Amplitude] Rage Click")
        XCTAssertNotNil(rageClickEvent.eventProperties)
        
        let properties = rageClickEvent.eventProperties!
        XCTAssertEqual(properties["[Amplitude] Action"] as? String, "tap")
        XCTAssertEqual(properties["[Amplitude] Target View Class"] as? String, "UIButton")
        XCTAssertEqual(properties["[Amplitude] Hierarchy"] as? String, "UIWindow → UIViewController → UIButton")
        XCTAssertNotNil(properties["[Amplitude] Begin Time"])
        XCTAssertNotNil(properties["[Amplitude] End Time"])
        XCTAssertNotNil(properties["[Amplitude] Duration"])
        XCTAssertNotNil(properties["[Amplitude] Clicks"])
        
        // Verify that timestamps include milliseconds (should contain a dot followed by digits)
        let beginTimeString = properties["[Amplitude] Begin Time"] as? String
        let endTimeString = properties["[Amplitude] End Time"] as? String
        XCTAssertTrue(beginTimeString?.contains(".") == true, "Begin time should include milliseconds")
        XCTAssertTrue(endTimeString?.contains(".") == true, "End time should include milliseconds")
        
        // Verify clicks array structure
        let clicksArray = properties["[Amplitude] Clicks"] as? [[String: Any]]
        XCTAssertEqual(clicksArray?.count, 3)
        
        let firstClick = clicksArray?.first
        XCTAssertEqual(firstClick?["X"] as? Double, 100)
        XCTAssertEqual(firstClick?["Y"] as? Double, 200)
        XCTAssertEqual(firstClick?["Time"] as? String, "2025-05-23T10:00:00.123Z")
        
        // Verify that click time includes milliseconds
        let clickTime = firstClick?["Time"] as? String
        XCTAssertTrue(clickTime?.contains(".123") == true, "Click time should include milliseconds")
    }
    
    func testAutocaptureOptionsRageClick() {
        // Test that rage click option exists
        let rageClickOption = AutocaptureOptions.rageClick
        XCTAssertEqual(rageClickOption.rawValue, 1 << 5)
        
        // Test that rage click is included in .all
        XCTAssertTrue(AutocaptureOptions.all.contains(.rageClick))
        
        // Test configuration with rage click enabled
        let config = Configuration(
            apiKey: "test-api-key",
            autocapture: [.sessions, .rageClick]
        )
        
        XCTAssertTrue(config.autocapture.contains(.rageClick))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertFalse(config.autocapture.contains(.elementInteractions))
    }
    
    func testAutocaptureOptionsWithoutRageClick() {
        // Test configuration without rage click
        let config = Configuration(
            apiKey: "test-api-key",
            autocapture: [.sessions, .elementInteractions]
        )
        
        XCTAssertFalse(config.autocapture.contains(.rageClick))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertTrue(config.autocapture.contains(.elementInteractions))
    }
    
    func testRageClickOnlyConfiguration() {
        // Test configuration with only rage click enabled (no element interactions)
        let config = Configuration(
            apiKey: "test-api-key",
            autocapture: [.sessions, .rageClick]
        )
        
        XCTAssertTrue(config.autocapture.contains(.rageClick))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertFalse(config.autocapture.contains(.elementInteractions))
    }
    
    func testBothRageClickAndElementInteractions() {
        // Test configuration with both rage click and element interactions enabled
        let config = Configuration(
            apiKey: "test-api-key",
            autocapture: [.sessions, .rageClick, .elementInteractions]
        )
        
        XCTAssertTrue(config.autocapture.contains(.rageClick))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertTrue(config.autocapture.contains(.elementInteractions))
    }
    
    func testTimestampFormatWithMilliseconds() {
        // Test that the date extension produces timestamps with milliseconds
        let testDate = Date()
        let formattedString = testDate.amp_iso8601String()
        
        // Verify the format includes milliseconds (should contain a dot followed by digits and Z)
        XCTAssertTrue(formattedString.contains("."), "Timestamp should include a decimal point for milliseconds")
        XCTAssertTrue(formattedString.hasSuffix("Z"), "Timestamp should end with Z for UTC")
        
        // Verify it matches the expected pattern (e.g., "2025-05-23T10:00:00.123Z")
        let pattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: formattedString.utf16.count)
        let matches = regex.numberOfMatches(in: formattedString, range: range)
        
        XCTAssertEqual(matches, 1, "Timestamp should match the expected format with milliseconds")
    }
    
    func testRageClickEventWithNonZeroCoordinates() {
        // Test that coordinates are properly captured and not zero
        let clicks = [
            Click(x: 150.5, y: 300.25, time: "2025-05-23T10:00:00.123Z"),
            Click(x: 155.0, y: 305.75, time: "2025-05-23T10:00:01.456Z"),
            Click(x: 152.25, y: 298.5, time: "2025-05-23T10:00:02.789Z")
        ]
        
        let beginTime = Date()
        let endTime = Date(timeInterval: 2, since: beginTime)
        
        let rageClickEvent = RageClickEvent(
            beginTime: beginTime,
            endTime: endTime,
            clicks: clicks,
            action: "tap",
            targetViewClass: "UIButton",
            hierarchy: "UIWindow → UIViewController → UIButton"
        )
        
        let properties = rageClickEvent.eventProperties!
        let clicksArray = properties["[Amplitude] Clicks"] as? [[String: Any]]
        XCTAssertEqual(clicksArray?.count, 3)
        
        // Verify that coordinates are not zero and have decimal precision
        let firstClick = clicksArray?[0]
        let secondClick = clicksArray?[1]
        let thirdClick = clicksArray?[2]
        
        XCTAssertEqual(firstClick?["X"] as? Double, 150.5)
        XCTAssertEqual(firstClick?["Y"] as? Double, 300.25)
        
        XCTAssertEqual(secondClick?["X"] as? Double, 155.0)
        XCTAssertEqual(secondClick?["Y"] as? Double, 305.75)
        
        XCTAssertEqual(thirdClick?["X"] as? Double, 152.25)
        XCTAssertEqual(thirdClick?["Y"] as? Double, 298.5)
        
        // Verify all coordinates are non-zero
        for (index, clickDict) in clicksArray!.enumerated() {
            let x = clickDict["X"] as? Double ?? 0
            let y = clickDict["Y"] as? Double ?? 0
            XCTAssertNotEqual(x, 0, "Click \(index) X coordinate should not be zero")
            XCTAssertNotEqual(y, 0, "Click \(index) Y coordinate should not be zero")
        }
    }
} 
