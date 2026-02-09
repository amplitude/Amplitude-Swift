//
//  ConsoleLoggerTests.swift
//
//
//  Created by Marvin Liu on 12/2/22.
//

import XCTest

@testable import AmplitudeSwift

final class ConsoleLoggerTests: XCTestCase {
    func testConsoleLoggerInit() {
        let consoleLogger = ConsoleLogger()
        XCTAssertEqual(
            consoleLogger.logLevel,
            LogLevelEnum.off.rawValue
        )
    }

    func testUpdateLogLevel() {
        let consoleLogger = ConsoleLogger(logLevel: LogLevelEnum.log.rawValue)
        XCTAssertEqual(
            consoleLogger.logLevel,
            LogLevelEnum.log.rawValue
        )

        consoleLogger.logLevel = LogLevelEnum.error.rawValue
        XCTAssertEqual(
            consoleLogger.logLevel,
            LogLevelEnum.error.rawValue
        )
    }
}
