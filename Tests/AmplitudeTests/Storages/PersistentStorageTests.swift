//
//  PersistentStorageTests.swift
//
//
//  Created by Marvin Liu on 11/21/22.
//

import XCTest

@testable import Amplitude_Swift

final class PersistentStorageTests: XCTestCase {
    func testIsBasicType() {
        let persistentStorage = PersistentStorage()
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
        let persistentStorage = PersistentStorage(apiKey: "xxx-api-key")
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        try? persistentStorage.write(
            key: StorageKey.EVENTS,
            value: BaseEvent(eventType: "test2")
        )
        let eventFiles: [URL]? = persistentStorage.read(key: StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?[0].absoluteString.contains("xxx-api-key.events.index"), true)
        XCTAssertNotEqual(eventFiles?[0].pathExtension, PersistentStorage.TEMP_FILE_EXTENSION)
        persistentStorage.reset()
    }

    func testWriteReadInterceptedIdentifyEvent() {
        let persistentStorage = PersistentStorage(apiKey: "xxx-api-key")

        var event: BaseEvent? = persistentStorage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        XCTAssertNil(event)

        try? persistentStorage.write(
            key: StorageKey.INTERCEPTED_IDENTIFY,
            value: IdentifyEvent(userId: "user-1", eventType: "$identify")
        )
        event = persistentStorage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        XCTAssertEqual(event?.eventType, "$identify")
        XCTAssertEqual(event?.userId, "user-1")

        try? persistentStorage.write(
                key: StorageKey.INTERCEPTED_IDENTIFY,
                value: nil
        )
        event = persistentStorage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        XCTAssertNil(event)

        persistentStorage.reset()

        event = persistentStorage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        XCTAssertNil(event)

        try? persistentStorage.write(
                key: StorageKey.INTERCEPTED_IDENTIFY,
                value: IdentifyEvent(userId: "user-2", eventType: "$identify")
        )
        event = persistentStorage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
        XCTAssertEqual(event?.eventType, "$identify")
        XCTAssertEqual(event?.userId, "user-2")

        persistentStorage.reset()
    }
}
