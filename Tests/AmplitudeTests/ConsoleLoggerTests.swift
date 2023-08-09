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
            LogLevelEnum.OFF.rawValue
        )
    }

    func testUpdateLogLevel() {
        let consoleLogger = ConsoleLogger(logLevel: LogLevelEnum.LOG.rawValue)
        XCTAssertEqual(
            consoleLogger.logLevel,
            LogLevelEnum.LOG.rawValue
        )

        consoleLogger.logLevel = LogLevelEnum.ERROR.rawValue
        XCTAssertEqual(
            consoleLogger.logLevel,
            LogLevelEnum.ERROR.rawValue
        )
    }
}
