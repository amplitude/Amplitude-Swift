import XCTest

@testable import Amplitude_Swift

final class RemnantDataMigrationTests: XCTestCase {
    var storage: LegacyDatabaseStorage?

    func testLegacyV4() throws {
        try checkLegacyDataMigration("legacy_v4", 4)
    }

    func testLegacyV3() throws {
        try checkLegacyDataMigration("legacy_v3", 3)
    }

    func testMissingLegacy() throws {
        try checkLegacyDataMigration("dummy", 4)
    }

    func testLegacyV4NoMigration() throws {
        try checkLegacyDataMigration("legacy_v4", 4, false)
    }

    private func checkLegacyDataMigration(_ legacyDbName: String, _ dbVersion: Int, _ migrateLegacyData: Bool = true) throws {
        let instanceName = "legacy_v\(dbVersion)_\(migrateLegacyData)_\(UUID().uuidString)".lowercased()

        let bundle = Bundle(for: type(of: self))
        let legacyDbUrl = bundle.url(forResource: legacyDbName, withExtension: "sqlite")
        let dbUrl = LegacyDatabaseStorage.getDatabasePath(instanceName)
        let fileManager = FileManager.default
        let legacyDbExists = legacyDbUrl != nil ? fileManager.fileExists(atPath: legacyDbUrl!.path) : false
        if legacyDbExists {
            try fileManager.copyItem(at: legacyDbUrl!, to: dbUrl)
        }

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: dbUrl.path) {
                try fileManager.removeItem(at: dbUrl)
            }
        }

        let apiKey = "test-api-key"
        let configuration = Configuration(
            apiKey: apiKey,
            instanceName: instanceName,
            migrateLegacyData: migrateLegacyData
        )
        let amplitude = Amplitude(configuration: configuration)

        let deviceId = "9B574574-74A7-4EDF-969D-164CB151B6C3"
        let userId = "ios-sample-user-legacy"

        // Check migrated data.
        if legacyDbExists && migrateLegacyData {
            XCTAssertEqual(amplitude.getDeviceId(), deviceId)
            XCTAssertEqual(amplitude.getUserId(), userId)
        } else {
            XCTAssertNotEqual(amplitude.getDeviceId(), deviceId)
            XCTAssertNotEqual(amplitude.getUserId(), userId)
        }

        amplitude.storage.rollover()
        amplitude.identifyStorage.rollover()

        if legacyDbExists && migrateLegacyData {
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.PREVIOUS_SESSION_ID), 1688622822100)
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_TIME), 1688622822150)
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_ID), 2)
        } else {
            XCTAssertNotEqual(amplitude.storage.read(key: StorageKey.PREVIOUS_SESSION_ID), 1688622822100)
            XCTAssertNotEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_TIME), 1688622822150)
            XCTAssertNotEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_ID), 2)
        }

        let eventFiles: [URL] = amplitude.storage.read(key: StorageKey.EVENTS) ?? []
        if legacyDbExists && migrateLegacyData {
            var events: [BaseEvent] = []
            for eventFile in eventFiles {
                if let eventString = amplitude.storage.getEventsString(eventBlock: eventFile) {
                    events.append(contentsOf: BaseEvent.fromArrayString(jsonString: eventString) ?? [])
                }
            }
            XCTAssertEqual(events.count, 4)

            XCTAssertEqual(events[0].eventType, "$identify")
            XCTAssertEqual(events[0].timestamp, 1684219150343)
            XCTAssertEqual(events[0].insertId, "CE8CA7E9-EAE6-480F-9B3C-85A8F5D99D65")
            XCTAssertEqual(events[0].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[0].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[0].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[1].eventType, "$identify")
            XCTAssertEqual(events[1].timestamp, 1684219150344)
            XCTAssertEqual(events[1].insertId, "C17DC7C9-FAE5-401A-A8F5-6AD559FAA8B6")
            XCTAssertEqual(events[1].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[1].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[1].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[2].eventType, "legacy event 1")
            XCTAssertEqual(events[2].timestamp, 1684219150354)
            XCTAssertEqual(events[2].insertId, "B6535173-3ACB-43AA-A01A-32E1CA2D09BF")
            XCTAssertEqual(events[2].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[2].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[2].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[3].eventType, "legacy event 2")
            XCTAssertEqual(events[3].timestamp, 1684219150355)
            XCTAssertEqual(events[3].insertId, "3B191114-D390-4FD1-858D-78227E8370AB")
            XCTAssertEqual(events[3].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[3].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[3].userId, "ios-sample-user-legacy")
        } else {
            XCTAssertEqual(eventFiles.count, 0)
        }

        let interceptedIdentifyFiles: [URL] = amplitude.identifyStorage.read(key: StorageKey.EVENTS) ?? []
        if legacyDbExists && migrateLegacyData && dbVersion >= 4 {
            var events: [BaseEvent] = []
            for eventFile in interceptedIdentifyFiles {
                if let eventString = amplitude.storage.getEventsString(eventBlock: eventFile) {
                    events.append(contentsOf: BaseEvent.fromArrayString(jsonString: eventString) ?? [])
                }
            }
            XCTAssertEqual(events.count, 2)

            XCTAssertEqual(events[0].eventType, "$identify")
            XCTAssertEqual(events[0].timestamp, 1684219150358)
            XCTAssertEqual(events[0].insertId, "A8B260D8-E640-4B52-9CC0-B8D4569DE79C")
            XCTAssertEqual(events[0].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[0].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[0].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[1].eventType, "$identify")
            XCTAssertEqual(events[1].timestamp, 1684219150359)
            XCTAssertEqual(events[1].insertId, "4884AD38-8A75-4961-870F-AD83C8271B1C")
            XCTAssertEqual(events[1].library, "amplitude-ios/8.16.4")
            XCTAssertEqual(events[1].deviceId, "9B574574-74A7-4EDF-969D-164CB151B6C3")
            XCTAssertEqual(events[1].userId, "ios-sample-user-legacy")
        } else {
            XCTAssertEqual(interceptedIdentifyFiles.count, 0)
        }

        // Check legacy sqlite data are cleaned.
        let legacyStorage = LegacyDatabaseStorage.getStorage(instanceName, nil)
        if migrateLegacyData {
            XCTAssertEqual(legacyStorage.readEvents().count, 0)
            XCTAssertEqual(legacyStorage.readIdentifies().count, 0)
            XCTAssertEqual(legacyStorage.readInterceptedIdentifies().count, 0)
        } else {
            XCTAssertEqual(legacyStorage.readEvents().count, 2)
            XCTAssertEqual(legacyStorage.readIdentifies().count, 2)
            XCTAssertEqual(legacyStorage.readInterceptedIdentifies().count, 2)
        }

        // User/device id should not be cleaned.
        if legacyDbExists {
            XCTAssertEqual(legacyStorage.getValue("user_id"), userId)
            XCTAssertEqual(legacyStorage.getValue("device_id"), deviceId)
        } else {
            XCTAssertNil(legacyStorage.getValue("user_id"))
            XCTAssertNil(legacyStorage.getValue("device_id"))
        }
    }
}
