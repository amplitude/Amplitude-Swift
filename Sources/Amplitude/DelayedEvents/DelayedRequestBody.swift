import Foundation

struct DelayedRequestBody: Codable {
    let apiKey: String
    let id: String
    let timeout: Int64        // milliseconds
    let events: [BaseEvent]
    let instantEvents: [BaseEvent]?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case id
        case timeout
        case events
        case instantEvents = "instant_events"
    }
}
