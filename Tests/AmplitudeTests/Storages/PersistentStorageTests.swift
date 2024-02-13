//
//  PersistentStorageTests.swift
//
//
//  Created by Marvin Liu on 11/21/22.
//

import XCTest

@testable import AmplitudeSwift

final class PersistentStorageTests: XCTestCase {
    func testIsBasicType() {
        let persistentStorage = PersistentStorage(storagePrefix: "storage")
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
        let persistentStorage = PersistentStorage(storagePrefix: "xxx-instance")
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
        let persistentStorage1 = PersistentStorage(storagePrefix: "xxx-instance")
        try? persistentStorage1.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        let persistentStorage2 = PersistentStorage(storagePrefix: "xxx-instance")
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
}
