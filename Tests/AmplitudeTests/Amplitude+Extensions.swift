//
//  Amplitude+Extensions.swift
//  Amplitude-SwiftTests
//
//  Created by Chris Leonavicius on 5/2/24.
//

@testable import AmplitudeSwift
import XCTest

extension Amplitude {

    func waitForTrackingQueue() {
        let waitForQueueExpectation = XCTestExpectation(description: "Wait for trackingQueue")
        // Because trackingQueue is serial, this acts as a barrier in which any previous operations will
        // have guaranteed to complete after this has run. 
        trackingQueue.async {
            waitForQueueExpectation.fulfill()
        }

        XCTWaiter().wait(for: [waitForQueueExpectation])
    }
}
