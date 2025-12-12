//
//  IdentityTests.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 3/31/25.
//

@testable import AmplitudeSwift
import XCTest

class IdentityTests: XCTestCase {

    private let storedIdentity = Identity(userId: "user-id-1", deviceId: "device-id-1", userProperties: [:])
    private let updatedIdentity = Identity(userId: "user-id-2", deviceId: "device-id-2", userProperties: ["a": 1, "c": 2])

    private func makeStorage() throws -> FakeInMemoryStorage {
        let storage = FakeInMemoryStorage()
        try storage.write(key: .USER_ID, value: storedIdentity.userId)
        try storage.write(key: .DEVICE_ID, value: storedIdentity.deviceId)
        return storage
    }

    // MARK: - Set Identity Tests

    func testUpdateWithSameValues() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should not send identify")
        sendExpectation.isInverted = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        // Write new values to storage without notifying amplitude instance
        // We verify that there are no writes if storage hasn't changed from these values.
        let updatedIdentity = Identity(userId: "user-id-2", deviceId: "device-id-2", userProperties: ["b": "c"])
        try storage.write(key: .USER_ID, value: updatedIdentity.userId)
        try storage.write(key: .DEVICE_ID, value: updatedIdentity.deviceId)

        // All should not write to storage
        amplitude.identity = storedIdentity
        amplitude.identity.userId = storedIdentity.userId
        amplitude.identity.deviceId = storedIdentity.deviceId
        amplitude.identity.userProperties = storedIdentity.userProperties

        XCTAssertEqual(amplitude.getUserId(), storedIdentity.userId)
        XCTAssertEqual(amplitude.getDeviceId(), storedIdentity.deviceId)
        XCTAssertEqual(storage.read(key: .USER_ID), updatedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), updatedIdentity.deviceId)

        wait(for: [sendExpectation], timeout: 1)
    }

    func testUpdateWithIdentity() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should send identify")
        sendExpectation.assertForOverFulfill = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        // Check Identity Call
        amplitude.identity = updatedIdentity

        XCTAssertEqual(storage.read(key: .USER_ID), updatedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.getUserId(), updatedIdentity.userId)
        XCTAssertEqual(amplitude.getDeviceId(), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedIdentity.userProperties as NSDictionary)

        wait(for: [sendExpectation], timeout: 1)
    }

    func testUpdateWithUserId() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should not send identify")
        sendExpectation.isInverted = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        amplitude.identity.userId = updatedIdentity.userId

        XCTAssertEqual(storage.read(key: .USER_ID), updatedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), storedIdentity.deviceId)
        XCTAssertEqual(amplitude.getUserId(), updatedIdentity.userId)
        XCTAssertEqual(amplitude.identity.userId, updatedIdentity.userId)

        wait(for: [sendExpectation], timeout: 1)
    }

    func testUpdateWithDeviceId() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should not send identify")
        sendExpectation.isInverted = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        amplitude.identity.deviceId = updatedIdentity.deviceId

        XCTAssertEqual(storage.read(key: .USER_ID), storedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.getDeviceId(), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.identity.deviceId, updatedIdentity.deviceId)

        wait(for: [sendExpectation], timeout: 1)
    }

    func testUpdateWithUserProperties() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should send identify")
        sendExpectation.assertForOverFulfill = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { event in
            XCTAssertEqual(event.eventType, Constants.IDENTIFY_EVENT)
            XCTAssertEqual((event.userProperties ?? [:]) as NSDictionary, ["$set": self.updatedIdentity.userProperties])
            sendExpectation.fulfill()
        }))

        amplitude.identity.userProperties = updatedIdentity.userProperties

        XCTAssertEqual(storage.read(key: .USER_ID), storedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), storedIdentity.deviceId)
        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedIdentity.userProperties as NSDictionary)

        wait(for: [sendExpectation], timeout: 100)
    }

    // MARK: - Legacy Setters

    func testSetUserId() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should not send identify")
        sendExpectation.isInverted = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        amplitude.setUserId(userId: updatedIdentity.userId)

        XCTAssertEqual(storage.read(key: .USER_ID), updatedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), storedIdentity.deviceId)
        XCTAssertEqual(amplitude.getUserId(), updatedIdentity.userId)
        XCTAssertEqual(amplitude.identity.userId, updatedIdentity.userId)

        wait(for: [sendExpectation], timeout: 1)
    }

    func testSetDeviceId() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let sendExpectation = XCTestExpectation(description: "It should not send identify")
        sendExpectation.isInverted = true
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in
            sendExpectation.fulfill()
        }))

        amplitude.setDeviceId(deviceId: updatedIdentity.deviceId)

        XCTAssertEqual(storage.read(key: .USER_ID), storedIdentity.userId)
        XCTAssertEqual(storage.read(key: .DEVICE_ID), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.getDeviceId(), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.identity.deviceId, updatedIdentity.deviceId)

        wait(for: [sendExpectation], timeout: 1)
    }

    // MARK: - Identifies

    func testIdentifySet() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        let identify = Identify()
        identify.setUserProperty(operation: .SET, property: "foo", value: "bar")
        amplitude.identify(identify: identify)

        var updatedUserProperties = storedIdentity.userProperties
        updatedUserProperties["foo"] = "bar"

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedUserProperties as NSDictionary)
    }

    func testIdentifyUnset() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))
        amplitude.identity.userProperties = updatedIdentity.userProperties

        let key = updatedIdentity.userProperties.keys.first!

        let identify = Identify()
        identify.setUserProperty(operation: .UNSET, property: key, value: Identify.UNSET_VALUE)
        amplitude.identify(identify: identify)

        var updatedUserProperties = updatedIdentity.userProperties
        updatedUserProperties[key] = nil

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedUserProperties as NSDictionary)
    }

    func testIdentifyClearAll() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        let identify = Identify()
        identify.clearAll()
        amplitude.identify(identify: identify)

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, NSDictionary())
    }

    func testIdentifyUpdate() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        let ignorePlugin = IdentifyInterceptPlugin { _ in }
        amplitude.add(plugin: ignorePlugin)
        amplitude.identity.userProperties = updatedIdentity.userProperties
        amplitude.waitForTrackingQueue()
        amplitude.remove(plugin: ignorePlugin)

        let identify = Identify()
        identify.setUserProperty(operation: .SET, property: "foo", value: "bar")

        let identifyExpectation = XCTestExpectation(description: "It should call identify")
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { event in
            XCTAssertEqual(event.userProperties as? NSDictionary, identify.properties as NSDictionary)
            identifyExpectation.fulfill()
        }))

        amplitude.identify(identify: identify)

        var updatedUserProperties = updatedIdentity.userProperties
        updatedUserProperties["foo"] = "bar"

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedUserProperties as NSDictionary)

        wait(for: [identifyExpectation])
    }

    func testIdentifyNoOps() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        let identify = Identify()
        identify.setUserProperty(operation: .SET_ONCE, property: "set_once", value: 1)
        identify.setUserProperty(operation: .ADD, property: "add", value: 2)
        identify.setUserProperty(operation: .APPEND, property: "append", value: 3)
        identify.setUserProperty(operation: .PREPEND, property: "prepend", value: 4)
        identify.setUserProperty(operation: .PRE_INSERT, property: "preInsert", value: 5)
        identify.setUserProperty(operation: .POST_INSERT, property: "postInsert", value: 6)
        identify.setUserProperty(operation: .REMOVE, property: "remove", value: 7)
        amplitude.identify(identify: identify)

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, storedIdentity.userProperties as NSDictionary)
    }

    func testIdentifyOrder() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        let existingProperties = ["foo": 1, "bar": 2]
        amplitude.identity.userProperties = existingProperties

        let identify = IdentifyEvent()
        identify.userProperties = [
            Identify.Operation.CLEAR_ALL.rawValue: Identify.UNSET_VALUE,
            Identify.Operation.SET.rawValue: ["foo": "bar"],
            Identify.Operation.UNSET.rawValue: ["foo": Identify.UNSET_VALUE],
        ]
        amplitude.track(event: identify)

        let updatedUserProperties = ["foo": "bar"]
        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedUserProperties as NSDictionary)
    }

    func testIdentifyNonOpProperties() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        let identify = IdentifyEvent()
        identify.userProperties = ["a": 1]
        amplitude.track(event: identify)

        var updatedUserProperties = storedIdentity.userProperties
        updatedUserProperties["a"] = 1

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, updatedUserProperties as NSDictionary)
    }

    func testIdentifyEventOptionsSetsUserAndDeviceId() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.add(plugin: IdentifyInterceptPlugin(block: { _ in }))

        amplitude.identify(userProperties: [:], options: EventOptions(userId: updatedIdentity.userId,
                                                                      deviceId: updatedIdentity.deviceId))

        XCTAssertEqual(storage.read(key: .USER_ID), updatedIdentity.userId)
        XCTAssertEqual(amplitude.identity.userId, updatedIdentity.userId)

        XCTAssertEqual(storage.read(key: .DEVICE_ID), updatedIdentity.deviceId)
        XCTAssertEqual(amplitude.identity.deviceId, updatedIdentity.deviceId)
    }

    // MARK: - Reset

    func testReset() throws {
        let storage = try makeStorage()
        let amplitude = Amplitude(configuration: Configuration(apiKey: "", storageProvider: storage, offline: NetworkConnectivityCheckerPlugin.Disabled))
        amplitude.reset()

        XCTAssertEqual(amplitude.identity.userProperties as NSDictionary, NSDictionary())
        XCTAssertEqual(storage.read(key: .USER_ID) as String?, nil)
        XCTAssertEqual(amplitude.identity.userId, nil)

        XCTAssertNotEqual(storage.read(key: .DEVICE_ID), storedIdentity.deviceId)
        XCTAssertNotEqual(amplitude.identity.deviceId as String?, storedIdentity.deviceId)
    }

    // MARK: - InterceptPlugin

    class IdentifyInterceptPlugin: BeforePlugin {

        var block: ((IdentifyEvent) -> Void)

        init(block: @escaping (IdentifyEvent) -> Void) {
            self.block = block
        }

        override func execute(event: BaseEvent) -> BaseEvent? {
            if let identifyEvent = event as? IdentifyEvent  {
                block(identifyEvent)
            }
            return nil
        }
    }
}
