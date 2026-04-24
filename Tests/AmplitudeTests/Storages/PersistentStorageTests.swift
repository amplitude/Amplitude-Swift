//
//  PersistentStorageTests.swift
//
//
//  Created by Marvin Liu on 11/21/22.
//

import XCTest

@testable import AmplitudeSwift

final class PersistentStorageTests: XCTestCase {
    let logger = ConsoleLogger()
    let diagonostics = Diagnostics()
    let diagnosticsClient = FakeDiagnosticsClient()

    func testIsBasicType() {
        let persistentStorage = PersistentStorage(storagePrefix: "storage", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        var isValueBasicType = persistentStorage.isBasicType(value: 111)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: 11.11)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: true)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: "test")
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: NSString("test"))
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: nil)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = persistentStorage.isBasicType(value: Date())
        XCTAssertEqual(isValueBasicType, false)
    }

    func testWrite() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test2")
        )
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?[0].absoluteString.contains("xxx-instance.events.index"), true)
        XCTAssertNotEqual(eventFiles?[0].pathExtension, PersistentStorage.TEMP_FILE_EXTENSION)
        persistentStorage.reset()
    }

    func testWriteWithTwoInstances() {
        let persistentStorage1 = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        try? persistentStorage1.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        let persistentStorage2 = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        try? persistentStorage2.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test2")
        )
        // Only read from second instance, reading from first instance insert the "]" at the wrong cursor.
        let eventFiles2: [URL]? = persistentStorage2.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles2?[0].absoluteString.contains("xxx-instance.events.index"), true)
        XCTAssertNotEqual(eventFiles2?[0].pathExtension, PersistentStorage.TEMP_FILE_EXTENSION)

        XCTAssertEqual(eventFiles2?.count, 1)

        let eventString2 = persistentStorage2.getEventsString(eventBlock: (eventFiles2?[0])!)
        let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString2!)
        XCTAssertEqual(decodedEvents!.count, 2)
        XCTAssertEqual(decodedEvents![0].eventType, "test1")
        XCTAssertEqual(decodedEvents![1].eventType, "test2")
        persistentStorage1.reset()
        persistentStorage2.reset()
    }

    func testRollover() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        let filesInStoreageDirectory = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(filesInStoreageDirectory?.count, 1)
        XCTAssertEqual(filesInStoreageDirectory?[0].pathExtension, PersistentStorage.TEMP_FILE_EXTENSION)
        let rawContentInFile = try? String(contentsOf: filesInStoreageDirectory![0], encoding: .utf8)
        XCTAssertEqual(rawContentInFile, "\(BaseEvent(eventType: "test1").toString())\(PersistentStorage.DELMITER)")
        persistentStorage.rollover()
        let filesInStoreageDirectoryAfterRollover = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(filesInStoreageDirectoryAfterRollover?.count, 1)
        XCTAssertEqual(filesInStoreageDirectoryAfterRollover?[0].pathExtension, "")
        persistentStorage.reset()
    }

    func testQuarantineUnreadableEventFile() throws {
        let persistentStorage = PersistentStorage(storagePrefix: "quarantine-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        persistentStorage.rollover()
        let eventFiles = try XCTUnwrap(persistentStorage.read(key: StorageKey.EVENTS) as [URL]?)
        XCTAssertEqual(eventFiles.count, 1)
        let corruptFile = eventFiles[0]

        // Overwrite finalized file with bytes that are invalid UTF-8, mimicking the
        // iOS 26 corruption report where String(contentsOf:encoding:) throws.
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: corruptFile)

        let result = persistentStorage.getEventsString(eventBlock: corruptFile)
        XCTAssertNil(result, "Unreadable file should return nil")

        // Original file must be gone (quarantined) so the next flush advances past it.
        XCTAssertFalse(FileManager.default.fileExists(atPath: corruptFile.path), "Corrupt file should be renamed away")

        // read(key: .EVENTS) must no longer return the corrupt file — otherwise the
        // EventPipeline stays stuck on it.
        let remaining: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertTrue(remaining?.isEmpty ?? true, "Upload queue should no longer surface the corrupt file")

        // Quarantined file lives inside the hidden .quarantine subfolder for diagnostics.
        let quarantineDir = storeDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        let quarantined = (try? FileManager.default.contentsOfDirectory(atPath: quarantineDir.path)) ?? []
        XCTAssertEqual(quarantined.count, 1, "Quarantine file should exist in quarantine subfolder for diagnostics")
        XCTAssertTrue(quarantined[0].hasPrefix("\(corruptFile.lastPathComponent)."))

        // reset() should now sweep the quarantine directory too.
        persistentStorage.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineDir.path), "reset() should remove the quarantine directory")
    }

    func testWriteRecoversFromUnopenableFile() throws {
        let persistentStorage = PersistentStorage(storagePrefix: "unopenable-write", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: true)

        // Pre-create the first .tmp path as a *directory* so FileHandle(forWritingTo:)
        // will throw. This mimics the production scenario where the existing .tmp
        // cannot be opened for append (e.g., Data Protection locked, permissions).
        let blockedTmp = storeDirectory.appendingPathComponent("v2-0.tmp")
        try FileManager.default.createDirectory(at: blockedTmp, withIntermediateDirectories: false)

        // Write an event. Without the recovery path, outputStream would stay nil and
        // the event would be silently dropped via optional chaining at outputStream?.write.
        try persistentStorage.write(key: StorageKey.EVENTS, value: BaseEvent(eventType: "after-recovery"))
        persistentStorage.rollover()

        // Blocked tmp should be renamed out of the .tmp namespace (same rename()
        // used by rollover — moves "v2-0.tmp" -> "v2-0").
        XCTAssertFalse(FileManager.default.fileExists(atPath: blockedTmp.path))

        // read(key:.EVENTS) must surface both the new file (with the event we
        // just wrote) and the blocked one as an unreadable candidate.
        let eventFiles = try XCTUnwrap(persistentStorage.read(key: StorageKey.EVENTS) as [URL]?)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(eventFiles.count, 2)
        XCTAssertEqual(eventFiles[0].lastPathComponent, "v2-0")
        XCTAssertTrue(eventFiles[1].lastPathComponent.hasPrefix("v2-1"))

        // Reading the blocked entry triggers quarantine; reading the new file
        // returns the event that otherwise would have been lost.
        _ = persistentStorage.getEventsString(eventBlock: eventFiles[0])
        let recoveredString = persistentStorage.getEventsString(eventBlock: eventFiles[1])
        let recoveredEvents = BaseEvent.fromArrayString(jsonString: recoveredString ?? "")
        XCTAssertEqual(recoveredEvents?.count, 1)
        XCTAssertEqual(recoveredEvents?[0].eventType, "after-recovery")

        persistentStorage.reset()
    }

    func testRemove() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        persistentStorage.rollover()
        let filesInStoreageDirectory = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(filesInStoreageDirectory?.count, 1)
        persistentStorage.remove(eventBlock: filesInStoreageDirectory![0])
        let filesInStoreageDirectoryAfterRemove = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(filesInStoreageDirectoryAfterRemove?.count, 0)
        persistentStorage.reset()
    }

    func testSplit() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let event1 = BaseEvent(eventType: "test1")
        let event2 = BaseEvent(eventType: "test2")
        let events = [event1, event2]
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: event1
        )
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: event2
        )
        persistentStorage.rollover()
        let filesInStoreageDirectory = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(filesInStoreageDirectory?.count, 1)
        let rawContentInFile = try? String(contentsOf: filesInStoreageDirectory![0], encoding: .utf8)
        XCTAssertEqual(rawContentInFile, "\(event1.toString())\(PersistentStorage.DELMITER)\(event2.toString())\(PersistentStorage.DELMITER)")
        persistentStorage.splitBlock(eventBlock: filesInStoreageDirectory![0], events: events)
        let filesInStoreageDirectoryAfterSplit: [URL]? =  persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(filesInStoreageDirectoryAfterSplit?.count, 2)
        let rawContentInFile1 = try? String(contentsOf: filesInStoreageDirectoryAfterSplit![0], encoding: .utf8)
        let rawContentInFile2 = try? String(contentsOf: filesInStoreageDirectoryAfterSplit![1], encoding: .utf8)
        XCTAssertEqual(rawContentInFile1, "\(event1.toString())\(PersistentStorage.DELMITER)")
        XCTAssertEqual(rawContentInFile2, "\(event2.toString())\(PersistentStorage.DELMITER)")
        persistentStorage.reset()
    }

    func testDelimiterHandledGracefully() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1\(PersistentStorage.DELMITER)")
        )
        try? persistentStorage.write(
           key: StorageKey.EVENTS,
           value: BaseEvent(eventType: "test2\(PersistentStorage.DELMITER)")
        )
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?.count, 1)

        let eventString = persistentStorage.getEventsString(eventBlock: (eventFiles?[0])!)
        let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
        XCTAssertEqual(decodedEvents!.count, 2)
        XCTAssertEqual(decodedEvents![0].eventType, "test1\(PersistentStorage.DELMITER)")
        XCTAssertEqual(decodedEvents![1].eventType, "test2\(PersistentStorage.DELMITER)")
        persistentStorage.reset()
    }

   func testMalformedEventInDiagnostics() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let currentFile = storeDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)\(0)")
        let event1 = BaseEvent(eventType: "test1")
        let partial = "{\"event_type\":\"test1\",\"user_id\":\"159995596214061\",\"device_id\":\"9b935bb3cd75\","
        let malformedContent = "\(event1.toString())\(PersistentStorage.DELMITER)\(partial)\(PersistentStorage.DELMITER)"
        writeContent(file: currentFile, content: malformedContent)
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?.count, 1)

        let eventString = persistentStorage.getEventsString(eventBlock: (eventFiles?[0])!)
        let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
        var malformedArr: [String] = [String]()
        malformedArr.append(partial)
        let data = try? JSONSerialization.data(withJSONObject: malformedArr, options: [])
        let expectedPartial = String(data: data!, encoding: .utf8) ?? ""
        XCTAssertEqual(decodedEvents!.count, 1)
        XCTAssertEqual(self.diagonostics.extractDiagnosticsToString(), "{\"malformed_events\":\(expectedPartial)}")
        persistentStorage.reset()
   }

    func testConcurrentWriteFromMultipleThreads() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-concurrent-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()
        let dispatchGroup = DispatchGroup()
        for i in 0..<100 {
            dispatchGroup.enter()
            Thread.detachNewThread {
                for d in 0..<10 {
                    try? persistentStorage.write(
                        key: StorageKey.EVENTS,
                        value: BaseEvent(eventType: "test\(i)-\(d)")
                    )
                }
                persistentStorage.rollover()
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()

        var eventsCount = 0
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertNotNil(eventFiles)
        for file in eventFiles! {
            let eventString = persistentStorage.getEventsString(eventBlock: file)
            let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
            eventsCount += decodedEvents!.count
        }
        XCTAssertEqual(eventsCount, 1000)
        persistentStorage.reset()
    }

    func testConcurrentWriteOnMultipleInsances() {
        let dispatchGroup = DispatchGroup()
        for i in 0..<100 {
            dispatchGroup.enter()
            Thread.detachNewThread {
                let persistentStorage = PersistentStorage(storagePrefix: "xxx-multiple-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
                for d in 0..<10 {
                    try? persistentStorage.write(
                        key: StorageKey.EVENTS,
                        value: BaseEvent(eventType: "test\(i)-\(d)")
                    )
                }
                persistentStorage.rollover()
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-multiple-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        var eventsCount = 0
        XCTAssertNotNil(eventFiles)
        for file in eventFiles! {
            let eventString = persistentStorage.getEventsString(eventBlock: file)
            let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
            eventsCount += decodedEvents!.count
        }
        XCTAssertEqual(eventsCount, 1000)
        persistentStorage.reset()
    }

    func testHandleEarlierVersionFiles() {
        let persistentStorageToGetDirectory = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorageToGetDirectory.getEventsStorageDirectory(createDirectory: false)
        persistentStorageToGetDirectory.reset()
        createEarilierVersionFiles(storageDirectory: storeDirectory)
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?.count, 6)
        var eventsCount = 0
        eventFiles?.forEach({
            let eventString = persistentStorage.getEventsString(eventBlock: $0)
            let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
            eventsCount += decodedEvents?.count ?? 0
        })
        XCTAssertEqual(eventsCount, 10)
        persistentStorage.reset()
    }

    func testHandleEarlierVersionAndWriteEvents() {
        let persistentStorageToGetDirectory = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let storeDirectory = persistentStorageToGetDirectory.getEventsStorageDirectory(createDirectory: false)
        persistentStorageToGetDirectory.reset()
        createEarilierVersionFiles(storageDirectory: storeDirectory)
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test13")
        )
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test14")
        )
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?.count, 7)
        var eventsCount = 0
        eventFiles?.forEach({
            let eventString = persistentStorage.getEventsString(eventBlock: $0)
            let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString!)
            eventsCount += decodedEvents?.count ?? 0
        })
        XCTAssertEqual(eventsCount, 12)
        persistentStorage.reset()
    }

    func testDefaultStorageDirectoryUsesApplicationSupport() {
        let persistentStorage = PersistentStorage(storagePrefix: "application-support-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let applicationSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        XCTAssertTrue(storageUrl.path.hasPrefix(applicationSupportUrl.path))
        persistentStorage.reset()
    }

    func testStorageDirectoryIsExcludedFromBackupWhenCreated() throws {
        let persistentStorage = PersistentStorage(storagePrefix: "excluded-from-backup-instance-\(UUID().uuidString)", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: true)
        let resourceValues = try storageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])

        XCTAssertEqual(resourceValues.isExcludedFromBackup, true)
        persistentStorage.reset()
    }

    func testStorageDirectoryBackupExclusionIsOnlySetOncePerInstance() throws {
        let persistentStorage = PersistentStorage(storagePrefix: "excluded-from-backup-once-instance-\(UUID().uuidString)", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: true)
        var resourceValues = try storageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resourceValues.isExcludedFromBackup, true)

        var mutableStorageUrl = storageUrl
        resourceValues.isExcludedFromBackup = false
        try mutableStorageUrl.setResourceValues(resourceValues)

        _ = persistentStorage.getEventsStorageDirectory(createDirectory: true)
        let updatedResourceValues = try storageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])

        XCTAssertEqual(updatedResourceValues.isExcludedFromBackup, false)
        persistentStorage.reset()
    }

    func testMigratesLegacyEventFilesToCurrentStorageDirectory() {
        let storagePrefix = "legacy-directory-instance"
        let persistentStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let legacyStorageDirectory = persistentStorage.getLegacyEventsStorageDirectory(createDirectory: true)
        let legacyFile = legacyStorageDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)0")
        writeContent(file: legacyFile, content: "\(BaseEvent(eventType: "legacy-event").toString())\(PersistentStorage.DELMITER)")

        let migratedStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = migratedStorage.read(key: StorageKey.EVENTS)
        let migratedFile = storageDirectory.appendingPathComponent(legacyFile.lastPathComponent)
        XCTAssertEqual(eventFiles?.count, 1)
        XCTAssertEqual(eventFiles?.first, migratedFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyStorageDirectory.path))

        let eventString = migratedStorage.getEventsString(eventBlock: migratedFile)
        let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString ?? "")
        XCTAssertEqual(decodedEvents?.count, 1)
        XCTAssertEqual(decodedEvents?.first?.eventType, "legacy-event")

        migratedStorage.reset()
    }

    func testQuarantinesLegacyUnreadableEventFilesInCurrentStorageDirectory() throws {
        let storagePrefix = "legacy-quarantine-directory-instance"
        let persistentStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let legacyStorageDirectory = persistentStorage.getLegacyEventsStorageDirectory(createDirectory: true)
        let legacyFile = legacyStorageDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)0")
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: legacyFile)

        let migratedStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles = try XCTUnwrap(migratedStorage.read(key: StorageKey.EVENTS) as [URL]?)
        XCTAssertEqual(eventFiles.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))

        let result = migratedStorage.getEventsString(eventBlock: eventFiles[0])
        XCTAssertNil(result)

        let currentQuarantineDir = storageDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        let legacyQuarantineDir = legacyStorageDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        let quarantined = (try? FileManager.default.contentsOfDirectory(atPath: currentQuarantineDir.path)) ?? []
        XCTAssertEqual(quarantined.count, 1)
        XCTAssertTrue(quarantined[0].hasPrefix("\(eventFiles[0].lastPathComponent)."))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyQuarantineDir.path))

        migratedStorage.reset()
    }

    func testRemovesLegacyQuarantineDirectoryDuringMigration() throws {
        let storagePrefix = "legacy-remove-quarantine-directory-instance-\(UUID().uuidString)"
        let persistentStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let legacyStorageDirectory = persistentStorage.getLegacyEventsStorageDirectory(createDirectory: true)
        let legacyFile = legacyStorageDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)0")
        let legacyQuarantineDirectory = legacyStorageDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        try FileManager.default.createDirectory(at: legacyQuarantineDirectory, withIntermediateDirectories: true)
        writeContent(file: legacyFile, content: "\(BaseEvent(eventType: "legacy-event").toString())\(PersistentStorage.DELMITER)")
        writeContent(file: legacyQuarantineDirectory.appendingPathComponent("quarantined-event"), content: "unreadable")

        let migratedStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = migratedStorage.read(key: StorageKey.EVENTS)

        XCTAssertEqual(eventFiles?.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyQuarantineDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyStorageDirectory.path))

        migratedStorage.reset()
    }

    func testRemovesLegacyQuarantineDirectoryWithoutLegacyEventFiles() throws {
        let storagePrefix = "legacy-remove-only-quarantine-directory-instance-\(UUID().uuidString)"
        let persistentStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let legacyStorageDirectory = persistentStorage.getLegacyEventsStorageDirectory(createDirectory: true)
        let legacyQuarantineDirectory = legacyStorageDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        try FileManager.default.createDirectory(at: legacyQuarantineDirectory, withIntermediateDirectories: true)
        writeContent(file: legacyQuarantineDirectory.appendingPathComponent("quarantined-event"), content: "unreadable")

        let migratedStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = migratedStorage.read(key: StorageKey.EVENTS)

        XCTAssertTrue(eventFiles?.isEmpty ?? false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyQuarantineDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyStorageDirectory.path))

        migratedStorage.reset()
    }

    func testMigratesLegacyUnfinishedEventFilesToCurrentStorageDirectory() {
        let storagePrefix = "legacy-unfinished-directory-instance"
        let persistentStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let legacyStorageDirectory = persistentStorage.getLegacyEventsStorageDirectory(createDirectory: true)
        let legacyTempFile = legacyStorageDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)0").appendingPathExtension(PersistentStorage.TEMP_FILE_EXTENSION)
        writeContent(file: legacyTempFile, content: "\(BaseEvent(eventType: "legacy-unfinished-event").toString())\(PersistentStorage.DELMITER)")

        let migratedStorage = PersistentStorage(storagePrefix: storagePrefix, logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        let eventFiles: [URL]? = migratedStorage.read(key: StorageKey.EVENTS)
        let migratedFile = storageDirectory.appendingPathComponent(legacyTempFile.deletingPathExtension().lastPathComponent)
        XCTAssertEqual(eventFiles?.count, 1)
        XCTAssertEqual(eventFiles?.first, migratedFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyTempFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyStorageDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedFile.path))

        let eventString = migratedStorage.getEventsString(eventBlock: migratedFile)
        let decodedEvents = BaseEvent.fromArrayString(jsonString: eventString ?? "")
        XCTAssertEqual(decodedEvents?.count, 1)
        XCTAssertEqual(decodedEvents?.first?.eventType, "legacy-unfinished-event")

        migratedStorage.reset()
    }

    func testDoesNotFinalizeStaleUnfinishedEventFilesFromCurrentStorageDirectory() {
        let persistentStorage = PersistentStorage(storagePrefix: "current-unfinished-directory-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)
        persistentStorage.reset()

        let storageDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: true)
        let tempFile = storageDirectory.appendingPathComponent("\(PersistentStorage.STORAGE_V2_PREFIX)0").appendingPathExtension(PersistentStorage.TEMP_FILE_EXTENSION)
        writeContent(file: tempFile, content: "\(BaseEvent(eventType: "current-unfinished-event").toString())\(PersistentStorage.DELMITER)")

        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertTrue(eventFiles?.isEmpty ?? false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))

        persistentStorage.reset()
    }

    #if os(macOS)
    func testMacOsStorageDirectorySandboxedWhenAppSandboxDisabled() {
        let persistentStorage = PersistentStorage(storagePrefix: "mac-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)

        let bundleId = Bundle.main.bundleIdentifier!
        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        XCTAssertEqual(persistentStorage.isStorageSandboxed(), false)
        XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), true)
        persistentStorage.reset()
    }

    func testMacOsStorageDirectorySandboxedWhenAppSandboxEnabled() {
        let persistentStorage = FakePersistentStorageAppSandboxEnabled(storagePrefix: "mac-app-sandbox-instance", logger: self.logger, diagonostics: self.diagonostics, diagnosticsClient: self.diagnosticsClient)

        let bundleId = Bundle.main.bundleIdentifier!
        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        XCTAssertEqual(persistentStorage.isStorageSandboxed(), true)
        XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), false)
        persistentStorage.reset()
    }
    #endif

    private func writeContent(file: URL, content: String) {
        let outputStream = try? OutputFileStream(fileURL: file)
        try? outputStream?.create()
        try? outputStream?.write(content)
    }

    private func createEarilierVersionFiles(storageDirectory: URL) {
        let file0 = storageDirectory.appendingPathComponent("0")
        let content0 = "[\(BaseEvent(eventType: "test1").toString()),\(BaseEvent(eventType: "test2").toString())]"
        writeContent(file: file0, content: content0)

        let file1 = storageDirectory.appendingPathComponent("1")
        let content1 = ",\(BaseEvent(eventType: "test3").toString()),\(BaseEvent(eventType: "test4").toString())]"
        writeContent(file: file1, content: content1)

        let file2 = storageDirectory.appendingPathComponent("2")
        let content2 = "[[\(BaseEvent(eventType: "test5").toString()),\(BaseEvent(eventType: "test6").toString())]]"
        writeContent(file: file2, content: content2)

        let file3 = storageDirectory.appendingPathComponent("3")
        let content3 = "\(BaseEvent(eventType: "test7").toString()),\(BaseEvent(eventType: "test8").toString())]"
        writeContent(file: file3, content: content3)

        let file4 = storageDirectory.appendingPathComponent("4")
        let content4 = "[\(BaseEvent(eventType: "test9").toString())],\(BaseEvent(eventType: "test10").toString())]"
        writeContent(file: file4, content: content4)

        let file5 = storageDirectory.appendingPathComponent("5")
        let content5 = "[\(BaseEvent(eventType: "test11").toString()),\(BaseEvent(eventType: "test12").toString())"
        writeContent(file: file5, content: content5)
    }
}
