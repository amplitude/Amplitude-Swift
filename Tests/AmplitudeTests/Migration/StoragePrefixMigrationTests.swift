import XCTest

@testable import AmplitudeSwift

final class StoragePrefixMigrationTests: XCTestCase {
    let logger = ConsoleLogger()
    let diagonostics = Diagnostics()
    
    func testUserDefaults() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)

        try source.write(key: StorageKey.DEVICE_ID, value: "source-device")
        try source.write(key: StorageKey.USER_ID, value: "source-user")
        try source.write(key: StorageKey.PREVIOUS_SESSION_ID, value: 123)
        try source.write(key: StorageKey.LAST_EVENT_TIME, value: 456)
        try source.write(key: StorageKey.LAST_EVENT_ID, value: 789)
        source.userDefaults?.set(12345, forKey: source.eventsFileKey)

        var destinationDeviceId: String? = destination.read(key: StorageKey.DEVICE_ID)
        var destinationUserId: String? = destination.read(key: StorageKey.DEVICE_ID)
        var destinationPreviousSessionId: Int? = destination.read(key: StorageKey.PREVIOUS_SESSION_ID)
        var destinationLastEventTime: Int? = destination.read(key: StorageKey.LAST_EVENT_TIME)
        var destinationLastEventId: Int? = destination.read(key: StorageKey.LAST_EVENT_ID)
        var destinationEventsFileKey = destination.userDefaults?.object(forKey: destination.eventsFileKey)
        XCTAssertNil(destinationDeviceId)
        XCTAssertNil(destinationUserId)
        XCTAssertNil(destinationPreviousSessionId)
        XCTAssertNil(destinationLastEventTime)
        XCTAssertNil(destinationLastEventId)
        XCTAssertNil(destinationEventsFileKey)

        let migration = StoragePrefixMigration(source: source, destination: destination, logger: ConsoleLogger())
        migration.execute()

        let sourceDeviceId: String? = source.read(key: StorageKey.DEVICE_ID)
        let sourceUserId: String? = source.read(key: StorageKey.USER_ID)
        let sourcePreviousSessionId: Int? = source.read(key: StorageKey.PREVIOUS_SESSION_ID)
        let sourceLastEventTime: Int? = source.read(key: StorageKey.LAST_EVENT_TIME)
        let sourceLastEventId: Int? = source.read(key: StorageKey.LAST_EVENT_ID)
        let sourceEventsFileKey = source.userDefaults?.object(forKey: source.eventsFileKey)
        XCTAssertNil(sourceDeviceId)
        XCTAssertNil(sourceUserId)
        XCTAssertNil(sourcePreviousSessionId)
        XCTAssertNil(sourceLastEventTime)
        XCTAssertNil(sourceLastEventId)
        XCTAssertNil(sourceEventsFileKey)

        destinationDeviceId = destination.read(key: StorageKey.DEVICE_ID)
        destinationUserId = destination.read(key: StorageKey.USER_ID)
        destinationPreviousSessionId = destination.read(key: StorageKey.PREVIOUS_SESSION_ID)
        destinationLastEventTime = destination.read(key: StorageKey.LAST_EVENT_TIME)
        destinationLastEventId = destination.read(key: StorageKey.LAST_EVENT_ID)
        destinationEventsFileKey = destination.userDefaults?.object(forKey: destination.eventsFileKey)
        XCTAssertEqual(destinationDeviceId, "source-device")
        XCTAssertEqual(destinationUserId, "source-user")
        XCTAssertEqual(destinationPreviousSessionId, 123)
        XCTAssertEqual(destinationLastEventTime, 456)
        XCTAssertEqual(destinationLastEventId, 789)
        XCTAssertEqual(destinationEventsFileKey as? Int, 12345)
    }

    func testEventFiles() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)

        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-1"))
        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-2"))
        source.rollover()
        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-3"))
        source.rollover()
        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-4"))

        var sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 3)

        let sourceFileSizes = try sourceEventFiles.map{ try getFileSize($0) }

        var destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 0)

        let migration = StoragePrefixMigration(source: source, destination: destination, logger: ConsoleLogger())
        migration.execute()

        sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 0)

        destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 3)

        for (index, destinationEventFile) in destinationEventFiles.enumerated() {
            let fileSize = try getFileSize(destinationEventFile)
            XCTAssertEqual(fileSize, sourceFileSizes[index])
        }
    }

    func testMissingSource() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)

        var destinationDeviceId: String? = destination.read(key: StorageKey.DEVICE_ID)
        var destinationLastEventId: Int? = destination.read(key: StorageKey.LAST_EVENT_ID)
        XCTAssertNil(destinationDeviceId)
        XCTAssertNil(destinationLastEventId)

        let migration = StoragePrefixMigration(source: source, destination: destination, logger: ConsoleLogger())
        migration.execute()

        destinationDeviceId = destination.read(key: StorageKey.DEVICE_ID)
        destinationLastEventId = destination.read(key: StorageKey.LAST_EVENT_ID)
        XCTAssertNil(destinationDeviceId)
        XCTAssertNil(destinationLastEventId)

        let destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 0)

        let sourceEventsStorageDirectory = source.getEventsStorageDirectory(createDirectory: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceEventsStorageDirectory.path))
    }

    func testMoveEventFilesWithDuplicatedName() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString, logger: self.logger, diagonostics: self.diagonostics)

        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-1"))
        source.rollover()
        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-11"))

        var sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 2)

        let sourceFileSizes = try sourceEventFiles.map{ try getFileSize($0) }

        try destination.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-ABC"))
        destination.rollover()

        var destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 1)

        let destinationFileSizes = try destinationEventFiles.map{ try getFileSize($0) }

        let migration = StoragePrefixMigration(source: source, destination: destination, logger: ConsoleLogger())
        migration.execute()

        sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 0)

        destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles[0].lastPathComponent, "0")
        XCTAssertEqual(destinationEventFiles[1].lastPathComponent.prefix(2), "0-")
        XCTAssertEqual(destinationEventFiles[2].lastPathComponent, "1")
        XCTAssertEqual(try getFileSize(destinationEventFiles[1]), sourceFileSizes[0])
        XCTAssertEqual(try getFileSize(destinationEventFiles[2]), sourceFileSizes[1])
        XCTAssertEqual(try getFileSize(destinationEventFiles[0]), destinationFileSizes[0])
    }

    private func getFileSize(_ url: URL) throws -> Int {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return resources.fileSize!
    }
}
