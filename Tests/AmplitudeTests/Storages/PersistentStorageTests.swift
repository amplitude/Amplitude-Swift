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
    
    func testIsBasicType() {
        let persistentStorage = PersistentStorage(storagePrefix: "storage", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage1 = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
        try? persistentStorage1.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        let persistentStorage2 = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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

    func testRemove() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let apiKey = "testApiKeyPersist"
       let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
        let storeDirectory = persistentStorage.getEventsStorageDirectory(createDirectory: false)
        let currentFile = storeDirectory.appendingPathComponent("\(0)")
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
        XCTAssertTrue(self.diagonostics.hasDiagnostics() == true)
        XCTAssertEqual(self.diagonostics.extractDiagonostics(), "{\"malformed_events\":\(expectedPartial)}")
        persistentStorage.reset()
   }

    func testConcurrentWriteFromMultipleThreads() {
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-concurrent-instance", logger: self.logger, diagonostics: self.diagonostics)
        persistentStorage.reset()
        let dispatchGroup = DispatchGroup()
        for i in 0..<100 {
            Thread.detachNewThread {
                dispatchGroup.enter()
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
            Thread.detachNewThread {
                dispatchGroup.enter()
                let persistentStorage = PersistentStorage(storagePrefix: "xxx-multiple-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-multiple-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorageToGetDirectory = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
        let storeDirectory = persistentStorageToGetDirectory.getEventsStorageDirectory(createDirectory: false)
        createEarilierVersionFiles(storageDirectory: storeDirectory)
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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
        let persistentStorageToGetDirectory = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
        let storeDirectory = persistentStorageToGetDirectory.getEventsStorageDirectory(createDirectory: false)
        createEarilierVersionFiles(storageDirectory: storeDirectory)
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance", logger: self.logger, diagonostics: self.diagonostics)
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

    #if os(macOS)
    func testMacOsStorageDirectorySandboxedWhenAppSandboxDisabled() {
        let persistentStorage = PersistentStorage(storagePrefix: "mac-instance", logger: self.logger, diagonostics: self.diagonostics)

        let bundleId = Bundle.main.bundleIdentifier!
        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        XCTAssertEqual(persistentStorage.isStorageSandboxed(), false)
        XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), true)
        persistentStorage.reset()
    }

    func testMacOsStorageDirectorySandboxedWhenAppSandboxEnabled() {
        let persistentStorage = FakePersistentStorageAppSandboxEnabled(storagePrefix: "mac-app-sandbox-instance", logger: self.logger, diagonostics: self.diagonostics)

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
