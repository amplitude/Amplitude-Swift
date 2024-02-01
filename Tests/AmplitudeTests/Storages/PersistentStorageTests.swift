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

    func testStorageDirectorySandboxed() {
        let persistentStorage = PersistentStorage(storagePrefix: "sandbox-instance")

        // e.g. /Library/Developer/CoreSimulator/Devices/AA0CFF70-35A4-4D85-AB9A-C27A8DBF94D7/data/Library/Application%20Support/amplitude/amplitude-swift-sandbox-instance.events.inde
        // /Library/Developer/CoreSimulator/Devices/AA0CFF70-35A4-4D85-AB9A-C27A8DBF94D7/data/Containers/Data/Application/06213CC5-0BE3-4822-BF6A-44C711467CB7/Library/Application%20Support/amplitude/amplitude-swift-identify-default_instance.events.index
        let iOSSandboxPathRegex = "CoreSimulator/Devices/[A-Z0-9-]*/data/"
        let bundleId = Bundle.main.bundleIdentifier!

        let storageUrl = persistentStorage.getEventsStorageDirectory(createDirectory: false)

        // print("bundleId=\(bundleId)")
        // print("storageUrl=\(storageUrl)")

        #if os(iOS)
            XCTAssertNotNil(storageUrl.absoluteString.range(of: iOSSandboxPathRegex, options: .regularExpression, range: nil, locale: nil))
        #else
            XCTAssertEqual(storageUrl.absoluteString.contains(bundleId), true)
        #endif
        persistentStorage.reset()
    }
}
