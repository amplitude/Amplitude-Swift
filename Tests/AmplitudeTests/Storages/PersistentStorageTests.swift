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
}
