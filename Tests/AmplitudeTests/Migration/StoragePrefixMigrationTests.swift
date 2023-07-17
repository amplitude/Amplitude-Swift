import XCTest

@testable import Amplitude_Swift

final class StoragePrefixMigrationTests: XCTestCase {
    func testUserDefaults() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString)

        try source.write(key: StorageKey.DEVICE_ID, value: "source-device")
        try source.write(key: StorageKey.LAST_EVENT_ID, value: 12345)
        source.userDefaults?.set(789, forKey: source.eventsFileKey)

        var destinationDeviceId: String? = destination.read(key: StorageKey.DEVICE_ID)
        var destinationLastEventId: Int64? = destination.read(key: StorageKey.LAST_EVENT_ID)
        var destinationEventsFileKey = destination.userDefaults?.object(forKey: destination.eventsFileKey)
        XCTAssertNil(destinationDeviceId)
        XCTAssertNil(destinationLastEventId)
        XCTAssertNil(destinationEventsFileKey)

        let migration = StoragePrefixMigration(source: source, destination: destination)
        migration.execute()

        let sourceDeviceId: String? = source.read(key: StorageKey.DEVICE_ID)
        let sourceLastEventId: Int64? = source.read(key: StorageKey.LAST_EVENT_ID)
        let sourceEventsFileKey = source.userDefaults?.object(forKey: source.eventsFileKey)
        XCTAssertNil(sourceDeviceId)
        XCTAssertNil(sourceLastEventId)
        XCTAssertNil(sourceEventsFileKey)

        destinationDeviceId = destination.read(key: StorageKey.DEVICE_ID)
        destinationLastEventId = destination.read(key: StorageKey.LAST_EVENT_ID)
        destinationEventsFileKey = destination.userDefaults?.object(forKey: destination.eventsFileKey)
        XCTAssertEqual(destinationDeviceId, "source-device")
        XCTAssertEqual(destinationLastEventId, 12345)
        XCTAssertEqual(destinationEventsFileKey as? Int, 789)
    }

    func testEventFiles() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString)

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

        let migration = StoragePrefixMigration(source: source, destination: destination)
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
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString)

        var destinationDeviceId: String? = destination.read(key: StorageKey.DEVICE_ID)
        var destinationLastEventId: Int64? = destination.read(key: StorageKey.LAST_EVENT_ID)
        XCTAssertNil(destinationDeviceId)
        XCTAssertNil(destinationLastEventId)

        let migration = StoragePrefixMigration(source: source, destination: destination)
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

    func testDoNotMoveEventFilesToDestinationWithWrittenEvents() throws {
        let source = PersistentStorage(storagePrefix: NSUUID().uuidString)
        let destination = PersistentStorage(storagePrefix: NSUUID().uuidString)

        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-1"))
        source.rollover()
        try source.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-3"))

        var sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 2)

        try destination.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "event-A"))
        destination.rollover()

        var destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 1)

        destination.remove(eventBlock: destinationEventFiles[0])
        destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 0)

        let migration = StoragePrefixMigration(source: source, destination: destination)
        migration.execute()

        sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(sourceEventFiles.count, 0)

        destinationEventFiles = destination.getEventFiles(includeUnfinished: true)
        XCTAssertEqual(destinationEventFiles.count, 0)
    }

    private func getFileSize(_ url: URL) throws -> Int {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return resources.fileSize!
    }
}
