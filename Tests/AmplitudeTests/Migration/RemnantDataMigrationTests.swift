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

        let configuration = Configuration(
            apiKey: "test-api-key",
            instanceName: instanceName,
            migrateLegacyData: migrateLegacyData
        )
        let amplitude = Amplitude(configuration: configuration, instanceName: instanceName)

        let deviceId = "22833898-c487-4536-b213-40f207abdce0R"
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
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.PREVIOUS_SESSION_ID), 1684219150343)
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_TIME), 1684219150344)
            XCTAssertEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_ID), 2)
        } else {
            XCTAssertNotEqual(amplitude.storage.read(key: StorageKey.PREVIOUS_SESSION_ID), 1684219150343)
            XCTAssertNotEqual(amplitude.storage.read(key: StorageKey.LAST_EVENT_TIME), 1684219150344)
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
            XCTAssertEqual(events[0].insertId, "be09ecba-83f7-444a-aba0-fe1f529a3716")
            XCTAssertEqual(events[0].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[0].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
            XCTAssertEqual(events[0].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[1].eventType, "$identify")
            XCTAssertEqual(events[1].timestamp, 1684219150344)
            XCTAssertEqual(events[1].insertId, "0894387e-e923-423b-9feb-086ba8cb2cfa")
            XCTAssertEqual(events[1].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[1].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
            XCTAssertEqual(events[1].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[2].eventType, "legacy event 1")
            XCTAssertEqual(events[2].timestamp, 1684219150354)
            XCTAssertEqual(events[2].insertId, "d6eff10b-9cd4-45d7-85cb-c81cb6cb8b2e")
            XCTAssertEqual(events[2].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[2].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
            XCTAssertEqual(events[2].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[3].eventType, "legacy event 2")
            XCTAssertEqual(events[3].timestamp, 1684219150355)
            XCTAssertEqual(events[3].insertId, "7b4c5c13-6fdc-4931-9ba1-e4efdf346ee0")
            XCTAssertEqual(events[3].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[3].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
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
            XCTAssertEqual(events[0].insertId, "1a14d057-8a12-40bb-8217-2d62dd08a525")
            XCTAssertEqual(events[0].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[0].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
            XCTAssertEqual(events[0].userId, "ios-sample-user-legacy")

            XCTAssertEqual(events[1].eventType, "$identify")
            XCTAssertEqual(events[1].timestamp, 1684219150359)
            XCTAssertEqual(events[1].insertId, "b115a299-4cc6-495b-8e4e-c2ce6f244be9")
            XCTAssertEqual(events[1].library, "amplitude-android/2.39.3-SNAPSHOT")
            XCTAssertEqual(events[1].deviceId, "22833898-c487-4536-b213-40f207abdce0R")
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
