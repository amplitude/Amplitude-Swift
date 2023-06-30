import XCTest

@testable import Amplitude_Swift

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
        let deviceId = storage!.getValue(key: "device_id")
        let userId = storage!.getValue(key: "user_id")
        let missing = storage!.getValue(key: "missing")

        XCTAssertEqual(deviceId, "22833898-c487-4536-b213-40f207abdce0R")
        XCTAssertEqual(userId, "ios-sample-user-legacy")
        XCTAssertNil(missing)
    }

    func testGetLongValues() throws {
        let previousSessionId = storage!.getLongValue(key: "previous_session_id")
        let lastEventId = storage!.getLongValue(key: "last_event_id")
        let lastIdentifyId = storage!.getLongValue(key: "last_identify_id")
        let lastEventTime = storage!.getLongValue(key: "last_event_time")
        let missing = storage!.getLongValue(key: "missing")

        XCTAssertEqual(previousSessionId, 1684219150343)
        XCTAssertEqual(lastEventId, 2)
        XCTAssertEqual(lastIdentifyId, 2)
        XCTAssertEqual(lastEventTime, 1684219150344)
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
        var deviceId = storage!.getValue(key: "device_id")
        XCTAssertEqual(deviceId, "22833898-c487-4536-b213-40f207abdce0R")

        storage!.removeValue(key: "device_id")
        deviceId = storage!.getValue(key: "device_id")
        XCTAssertNil(deviceId)
    }

    func testRemoveLongValue() throws {
        var previousSessionId = storage!.getLongValue(key: "previous_session_id")
        XCTAssertEqual(previousSessionId, 1684219150343)

        storage!.removeLongValue(key: "previous_session_id")
        previousSessionId = storage!.getLongValue(key: "previous_session_id")
        XCTAssertNil(previousSessionId)
    }

    func testRemoveEvents() throws {
        var events = storage!.readEvents()
        XCTAssertEqual(events.count, 2)

        storage!.removeEvent(rowId: 2)

        events = storage!.readEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
    }

    func testRemoveIdentifies() throws {
        var events = storage!.readIdentifies()
        XCTAssertEqual(events.count, 2)

        storage!.removeIdentify(rowId: 1)

        events = storage!.readIdentifies()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["$rowId"] as? Int64, 2)
    }

    func testRemoveInterceptedIdentifies() throws {
        var events = storage!.readInterceptedIdentifies()
        XCTAssertEqual(events.count, 2)

        storage!.removeInterceptedIdentify(rowId: 2)

        events = storage!.readInterceptedIdentifies()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["$rowId"] as? Int64, 1)
    }
}
