import XCTest

@testable import AmplitudeSwift

final class LegacyDatabaseStorageTests: XCTestCase {
    var storage: LegacyDatabaseStorage?

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let legacyDbUrl = bundle.url(forResource: "legacy_v4", withExtension: "sqlite")
        let tempDirectory = NSTemporaryDirectory()
        let tempDbName = UUID().uuidString
        let tempDbUrl = URL(fileURLWithPath: tempDirectory).appendingPathComponent(tempDbName)
        try FileManager.default.copyItem(at: legacyDbUrl!, to: tempDbUrl)

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: tempDbUrl.path) {
                try fileManager.removeItem(at: tempDbUrl)
            }
        }

        storage = LegacyDatabaseStorage(tempDbUrl.path, ConsoleLogger(logLevel: LogLevelEnum.WARN.rawValue))
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetValues() throws {
        let deviceId = storage!.getValue("device_id")
        let userId = storage!.getValue("user_id")
        let missing = storage!.getValue("missing")

        XCTAssertEqual(deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
        XCTAssertEqual(userId, "ios-sample-user-legacy")
        XCTAssertNil(missing)
    }

    func testGetLongValues() throws {
        let previousSessionId = storage!.getLongValue("previous_session_id")
        let lastEventTime = storage!.getLongValue("previous_session_time")
        let missing = storage!.getLongValue("missing")

        XCTAssertEqual(previousSessionId, 1688622822100)
        XCTAssertEqual(lastEventTime, 1688622822150)
        XCTAssertNil(missing)
    }

    func testReadEvents() throws {
        let events = storage!.readEvents()

        XCTAssertEqual(events.count, 2)

        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
        XCTAssertEqual(events[0]["event_type"] as? String, "legacy event 1")
        XCTAssertEqual(events[0]["timestamp"] as? Int64, 1684219150354)

        XCTAssertEqual(events[1]["$rowId"] as? Int64, 2)
        XCTAssertEqual(events[1]["event_type"] as? String, "legacy event 2")
        XCTAssertEqual(events[1]["timestamp"] as? Int64, 1684219150355)
    }

    func testReadIdentifies() throws {
        let events = storage!.readIdentifies()

        XCTAssertEqual(events.count, 2)

        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
        XCTAssertEqual(events[0]["event_type"] as? String, "$identify")
        XCTAssertEqual(events[0]["timestamp"] as? Int64, 1684219150343)

        XCTAssertEqual(events[1]["$rowId"] as? Int64, 2)
        XCTAssertEqual(events[1]["event_type"] as? String, "$identify")
        XCTAssertEqual(events[1]["timestamp"] as? Int64, 1684219150344)
    }

    func testReadInterceptedIdentifies() throws {
        let events = storage!.readInterceptedIdentifies()

        XCTAssertEqual(events.count, 2)

        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
        XCTAssertEqual(events[0]["event_type"] as? String, "$identify")
        XCTAssertEqual(events[0]["timestamp"] as? Int64, 1684219150358)

        XCTAssertEqual(events[1]["$rowId"] as? Int64, 2)
        XCTAssertEqual(events[1]["event_type"] as? String, "$identify")
        XCTAssertEqual(events[1]["timestamp"] as? Int64, 1684219150359)
    }

    func testRemoveValue() throws {
        var deviceId = storage!.getValue("device_id")
        XCTAssertEqual(deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")

        storage!.removeValue("device_id")
        deviceId = storage!.getValue("device_id")
        XCTAssertNil(deviceId)
    }

    func testRemoveLongValue() throws {
        var previousSessionId = storage!.getLongValue("previous_session_id")
        XCTAssertEqual(previousSessionId, 1688622822100)

        storage!.removeLongValue("previous_session_id")
        previousSessionId = storage!.getLongValue("previous_session_id")
        XCTAssertNil(previousSessionId)
    }

    func testRemoveEvents() throws {
        var events = storage!.readEvents()
        XCTAssertEqual(events.count, 2)

        storage!.removeEvent(2)

        events = storage!.readEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
    }

    func testRemoveIdentifies() throws {
        var events = storage!.readIdentifies()
        XCTAssertEqual(events.count, 2)

        storage!.removeIdentify(1)

        events = storage!.readIdentifies()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["$rowId"] as? Int64, 2)
    }

    func testRemoveInterceptedIdentifies() throws {
        var events = storage!.readInterceptedIdentifies()
        XCTAssertEqual(events.count, 2)

        storage!.removeInterceptedIdentify(2)
        storage!.removeInterceptedIdentify(1)

        events = storage!.readInterceptedIdentifies()
        XCTAssertEqual(events.count, 0)
    }
}
