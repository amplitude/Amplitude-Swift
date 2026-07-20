import XCTest
@testable import AmplitudeSwift

final class DelayedEventsHttpClientTests: XCTestCase {
    func testGetUrlDefaultsToUSDelayedHost() {
        let client = DelayedEventsHttpClient(configuration: Configuration(apiKey: "test-key"))
        XCTAssertEqual(client.getUrl(), "https://api2.amplitude.com/2/httpapi/delayed")
    }

    func testGetUrlUsesEUDelayedHost() {
        let config = Configuration(apiKey: "test-key", serverZone: .EU)
        XCTAssertEqual(DelayedEventsHttpClient(configuration: config).getUrl(),
                       "https://api.eu.amplitude.com/2/httpapi/delayed")
    }

    func testGetUrlAppendsDelayedToCustomServerUrl() {
        let config = Configuration(apiKey: "test-key", serverUrl: "http://localhost:8123/2/httpapi")
        XCTAssertEqual(DelayedEventsHttpClient(configuration: config).getUrl(),
                       "http://localhost:8123/2/httpapi/delayed")
    }

    func testRequestBodyEncodesContractShape() throws {
        let event = BaseEvent(eventType: "Video Content Stopped")
        event.insertId = "ins-1"
        event.timestamp = 1_752_000_000_000
        let body = DelayedRequestBody(apiKey: "k", id: "d-1", timeout: 3_600_000,
                                      events: [event], instantEvents: nil)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as! [String: Any]
        XCTAssertEqual(json["api_key"] as? String, "k")
        XCTAssertEqual(json["id"] as? String, "d-1")
        XCTAssertEqual(json["timeout"] as? Int64, 3_600_000)
        let events = json["events"] as! [[String: Any]]
        XCTAssertEqual(events[0]["event_type"] as? String, "Video Content Stopped")
        XCTAssertEqual(events[0]["insert_id"] as? String, "ins-1")
        XCTAssertEqual(events[0]["time"] as? Int64, 1_752_000_000_000)
        XCTAssertNil(json["instant_events"])
    }
}
