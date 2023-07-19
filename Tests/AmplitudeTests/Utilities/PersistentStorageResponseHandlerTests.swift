//
//  PersistentStorageResponseHandlerTests.swift
//
//
//  Created by Marvin Liu on 12/2/22.
//

import XCTest

@testable import Amplitude_Swift

final class PersistentStorageResponseHandlerTests: XCTestCase {
    private var configuration: Configuration!
    private var amplitude: Amplitude!
    private var storage: PersistentStorage!
    private var eventPipeline: EventPipeline!
    private var eventBlock: URL!
    private var eventsString: String!

    override func setUp() {
        super.setUp()
        storage = PersistentStorage(storagePrefix: "storage")
        configuration = Configuration(apiKey: "testApiKey", storageProvider: storage)
        amplitude = Amplitude(configuration: configuration)
        eventPipeline = EventPipeline(amplitude: amplitude)
        eventBlock = URL(string: "test")
    }

    func testInit() {
        eventsString = """
            [
                {"event_type": "test"}
            ]
            """
        let handler = PersistentStorageResponseHandler(
            configuration: configuration,
            storage: storage,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )

        XCTAssertEqual(handler.eventsString, eventsString)
    }

    func testRemoveEventCallbackByEventsString_callsRemoveEventCallback() {
        let eventsString = """
            [
              {"event_type":"test","insert_id":"e3e4488d-6877-4775-ae88-344df7ccd5d8","user_id":"test-user"},
              {"event_type":"test","insert_id":"c8d58999-7539-4184-8a7d-54302697baf0","user_id":"test-user"}
            ]
            """
        let fakePersistentStorage = FakePersistentStorage(storagePrefix: "storage")
        let handler = PersistentStorageResponseHandler(
            configuration: configuration,
            storage: fakePersistentStorage,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )

        handler.removeEventCallbackByEventsString(eventsString: eventsString)
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith.count,
            2
        )
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith[0],
            "removeEventCallback(insertId: e3e4488d-6877-4775-ae88-344df7ccd5d8)"
        )
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith[1],
            "removeEventCallback(insertId: c8d58999-7539-4184-8a7d-54302697baf0)"
        )
    }

    func testRemoveEventCallbackByEventsString_notCallRemoveEventCallback() {
        // insert_id format, missing insert_id
        let eventsString = """
            [
              {"event_type":"wrong-insert_id-format","insert_id":"6877-4775-ae88-344df7ccd5d8","user_id":"test-user"},
              {"event_type":"missing-insert_id","user_id":"test-user"}
            ]
            """

        let fakePersistentStorage = FakePersistentStorage(storagePrefix: "storage")
        let handler = PersistentStorageResponseHandler(
            configuration: configuration,
            storage: fakePersistentStorage,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )

        handler.removeEventCallbackByEventsString(eventsString: eventsString)
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith.count,
            0
        )
    }

    func testHandleSuccessResponseWithInvalidEventsString_removesEventBlockAndEventCallback() {
        // valid event, invalid event
        let eventsString = """
            [
              {"event_type":"valid-event","insert_id":"e3e4488d-6877-4775-ae88-344df7ccd5d8","user_id":"test-user"},
              {"event_type":"invalid-event",user_id:test-user,xxx}
            ]
            """

        let fakePersistentStorage = FakePersistentStorage(storagePrefix: "storage")
        let handler = PersistentStorageResponseHandler(
            configuration: configuration,
            storage: fakePersistentStorage,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )

        handler.handleSuccessResponse(code: 200)
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith[0],
            "remove(eventBlock: \(eventBlock.absoluteURL))"
        )
        XCTAssertEqual(
            fakePersistentStorage.haveBeenCalledWith[1],
            "removeEventCallback(insertId: e3e4488d-6877-4775-ae88-344df7ccd5d8)"
        )
    }
}
