//
//  PersistentStorageTests.swift
//
//
//  Created by Marvin Liu on 11/21/22.
//

import XCTest

@testable import Amplitude_Swift

final class PersistentStorageTests: XCTestCase {
    func testIsBasicType() async {
        let persistentStorage = PersistentStorage()
        var isValueBasicType = await persistentStorage.isBasicType(value: 111)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = await persistentStorage.isBasicType(value: true)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = await persistentStorage.isBasicType(value: "test")
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = await persistentStorage.isBasicType(value: nil)
        XCTAssertEqual(isValueBasicType, true)

        isValueBasicType = await persistentStorage.isBasicType(value: Date())
        XCTAssertEqual(isValueBasicType, false)
    }

    func testWrite() async {
        let persistentStorage = PersistentStorage(apiKey: "xxx-api-key")
        try? await persistentStorage.write(
            key: PersistentStorage.StorageKey.EVENTS,
            value: BaseEvent(eventType: "test1")
        )
        try? await persistentStorage.write(
            key: PersistentStorage.StorageKey.EVENTS,
            value: BaseEvent(eventType: "test2")
        )
        let eventFiles: [URL]? = await persistentStorage.read(key: PersistentStorage.StorageKey.EVENTS)
        XCTAssertEqual(eventFiles?[0].absoluteString.contains("xxx-api-key.events.index"), true)
        XCTAssertNotEqual(eventFiles?[0].pathExtension, PersistentStorage.TEMP_FILE_EXTENSION)
        await persistentStorage.reset()
    }
}
