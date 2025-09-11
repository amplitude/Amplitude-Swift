//
//  NetworkTrackingPlugin+Extensions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 9/11/25.
//

@testable import AmplitudeSwift
import XCTest

extension NetworkTrackingPlugin {

    func waitforNetworkTrackingQueue() {
        let waitForQueueExpectation = XCTestExpectation(description: "Wait for networkTrackingQueue")
        networkTrackingQueue.async(flags: .barrier) {
            waitForQueueExpectation.fulfill()
        }
        XCTWaiter().wait(for: [waitForQueueExpectation], timeout: 10)
    }
}
