import Foundation

class RemnantDataMigration {
    private static let DEVICE_ID_KEY = "device_id"
    private static let USER_ID_KEY = "user_id"
    private static let LAST_EVENT_TIME_KEY = "last_event_time"
    private static let LAST_EVENT_ID_KEY = "last_event_id"
    private static let PREVIOUS_SESSION_ID_KEY = "previous_session_id"

    private let amplitude: Amplitude
    private let storage: LegacyDatabaseStorage

    init(_ amplitude: Amplitude) {
        self.amplitude = amplitude
        self.storage = LegacyDatabaseStorage.getStorage(amplitude.instanceName, amplitude.logger)
    }

    func execute() {
        let firstRunSinceUpgrade = amplitude.storage.read(key: StorageKey.LAST_EVENT_TIME) == nil

        moveDeviceAndUserId()
        moveSessionData()

        if firstRunSinceUpgrade {
            moveInterceptedIdentifies()
            moveIdentifies()
        }
        moveEvents()
    }

    private func moveDeviceAndUserId() {
        let deviceId = storage.getValue(RemnantDataMigration.DEVICE_ID_KEY)
        let userId = storage.getValue(RemnantDataMigration.USER_ID_KEY)

        if deviceId != nil {
            amplitude.setDeviceId(deviceId: deviceId)
        }

        if userId != nil {
            amplitude.setUserId(userId: userId)
        }
    }

    private func moveSessionData() {
        let currentSessionId = amplitude.sessions.sessionId
        let currentLastEventTime = amplitude.sessions.lastEventTime
        let currentLastEventId = amplitude.sessions.lastEventId

        let previousSessionId = storage.getLongValue(RemnantDataMigration.PREVIOUS_SESSION_ID_KEY)
        let lastEventTime = storage.getLongValue(RemnantDataMigration.LAST_EVENT_TIME_KEY)
        let lastEventId = storage.getLongValue(RemnantDataMigration.LAST_EVENT_ID_KEY)

        if currentSessionId < 0 && previousSessionId != nil && previousSessionId! >= 0 {
            amplitude.sessions.sessionId = previousSessionId!
            storage.removeLongValue(RemnantDataMigration.PREVIOUS_SESSION_ID_KEY)
        }

        if currentLastEventTime < 0 && lastEventTime != nil && lastEventTime! >= 0 {
            amplitude.sessions.lastEventTime = lastEventTime!
            storage.removeLongValue(RemnantDataMigration.LAST_EVENT_TIME_KEY)
        }

        if currentLastEventId <= 0 && lastEventId != nil && lastEventId! > 0 {
            amplitude.sessions.lastEventId = lastEventId!
            storage.removeLongValue(RemnantDataMigration.LAST_EVENT_ID_KEY)
        }
    }

    private func moveEvents() {
        let remnantEvents = storage.readEvents()
        remnantEvents.forEach { event in
            moveEvent(event, amplitude.storage, storage.removeEvent)
        }
    }

    private func moveIdentifies() {
        let remnantEvents = storage.readIdentifies()
        remnantEvents.forEach { event in
            moveEvent(event, amplitude.storage, storage.removeIdentify)
        }
    }

    private func moveInterceptedIdentifies() {
        let remnantEvents = storage.readInterceptedIdentifies()
        remnantEvents.forEach { event in
            moveEvent(event, amplitude.identifyStorage, storage.removeInterceptedIdentify)
        }
    }

    private func moveEvent(_ event: [String: Any], _ destinationStorage: Storage, _ removeFromSource: (_ rowId: Int64) -> Void) {
        do {
            let rowId = event["$rowId"] as! Int64
            let converted = convertLegacyEvent(rowId, event)
            let jsonData = try JSONSerialization.data(withJSONObject: converted)
            let convertedEvent = BaseEvent.fromString(jsonString: String(data: jsonData, encoding: .utf8)!)
            try destinationStorage.write(key: StorageKey.EVENTS, value: convertedEvent)
            removeFromSource(rowId)
        } catch {
            amplitude.logger?.error(message: "event migration failed: \(error)")
        }
    }

    private func convertLegacyEvent(_ eventId: Int64, _ event: [String: Any]) -> [String:Any] {
        var convertedEvent = event

        convertedEvent["event_id"] = eventId

        if let library = event["library"] as? [String: Any] {
            convertedEvent["library"] = "\(library["name"] ?? "unknown")/\(library["version"] ?? "unknown")"
        }

        if let timestamp = event["timestamp"] {
            convertedEvent["time"] = timestamp
        }

        if let uuid = event["uuid"] {
            convertedEvent["insert_id"] = uuid
        }

        if let apiProperties = event["api_properties"] as? [String: Any] {
            if let idfa = apiProperties["ios_idfa"] {
                convertedEvent["idfa"] = idfa
            }

            if let idfv = apiProperties["ios_idfv"] {
                convertedEvent["idfv"] = idfv
            }

            if let productId = apiProperties["productId"] {
                convertedEvent["productId"] = productId
            }

            if let quantity = apiProperties["quantity"] {
                convertedEvent["quantity"] = quantity
            }

            if let price = apiProperties["price"] {
                convertedEvent["price"] = price
            }

            if let location = apiProperties["location"] as? [String: Any] {
                if let lat = location["lat"] {
                    convertedEvent["location_lat"] = lat
                }
                if let lng = location["lng"] {
                    convertedEvent["location_lng"] = lng
                }
            }
        }

        if let productId = event["$productId"] {
            convertedEvent["productId"] = productId
        }

        if let quantity = event["$quantity"] {
            convertedEvent["quantity"] = quantity
        }

        if let price = event["$price"] {
            convertedEvent["price"] = price
        }

        if let revenueType = event["$revenueType"] {
            convertedEvent["revenueType"] = revenueType
        }

        return convertedEvent
    }
}
