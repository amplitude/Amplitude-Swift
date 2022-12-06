//
//  PersitentStorageResponseHandlerTests.swift
//
//
//  Created by Marvin Liu on 12/2/22.
//

import XCTest

@testable import Amplitude_Swift

final class PersitentStorageResponseHandlerTests: XCTestCase {
    private var configuration: Configuration!
    private var amplitude: Amplitude!
    private var storage: PersistentStorage!
    private var eventPipeline: EventPipeline!
    private var eventBlock: URL!
    private var eventsString: String!

    override func setUp() {
        super.setUp()
        configuration = Configuration(apiKey: "testApiKey")
        amplitude = Amplitude(configuration: configuration)
        storage = PersistentStorage(apiKey: "testApiKey")
        eventPipeline = EventPipeline(amplitude: amplitude)
        eventBlock = URL(string: "test")
    }

    func testInit() {
        eventsString = """
            [
                {"event_type": "test"}
            ]
            """
        let handler = PersitentStorageResponseHandler(
            configuration: configuration,
            storage: storage,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )

        XCTAssertEqual(handler.eventsString, eventsString)
    }
}
