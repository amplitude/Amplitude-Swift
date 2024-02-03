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

    #if os(macOS)
    func testMacOsStorageDirectorySandboxedWhenAppSandboxDisabled() {
        let persistentStorage = PersistentStorage(storagePrefix: "mac-instance")

        let bundleId = Bundle.main.bundleIdentifier!
        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        XCTAssertEqual(persistentStorage.sandboxHelper.isSandboxEnabled(), false)
        XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), true)
        persistentStorage.reset()
    }

    func testMacOsStorageDirectorySandboxedWhenAppSandboxEnabled() {
        let persistentStorage = FakePersistentStorageWithAppSandboxEnabled(storagePrefix: "mac-app-sandbox-instance")

        let bundleId = Bundle.main.bundleIdentifier!
        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        XCTAssertEqual(persistentStorage.sandboxHelper.isSandboxEnabled(), true)
        XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), false)
        persistentStorage.reset()
    }
    #endif
}
