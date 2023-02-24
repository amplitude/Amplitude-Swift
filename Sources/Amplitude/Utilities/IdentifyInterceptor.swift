import Foundation

public class IdentifyInterceptor {
    private struct Identity: Equatable {
        let userId: String?
        let deviceId: String?

        init(_ event: BaseEvent) {
            userId = event.userId
            deviceId = event.deviceId
        }
    }

    private let configuration: Configuration
    private let pipeline: EventPipeline
    private let logger: (any Logger)?
    private var identifyTransferTimer: QueueTimer?
    private let minIdentifyBatchInterval: Int
    private var lastIdentity: Identity?

    private lazy var storage: any Storage = {
        return self.configuration.identifyStorageProvider
    }()

    init(
        configuration: Configuration,
        pipeline: EventPipeline,
        minIdentifyBatchInterval: Int = Constants.Configuration.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS
    ) {
        self.configuration = configuration
        self.pipeline = pipeline
        self.logger = configuration.loggerProvider
        self.minIdentifyBatchInterval = minIdentifyBatchInterval
    }

    public func intercept(event: BaseEvent) -> BaseEvent? {
        do {
            return try interceptIdentifyEvent(event)
        } catch {
            logger?.error(message: "Error when intercept event: \(error.localizedDescription)")
        }

        return event
    }

    private func isIdentityUpdated(_ event: BaseEvent) -> Bool {
        let eventIdentity = Identity(event)

        if eventIdentity != lastIdentity {
            lastIdentity = eventIdentity
            return true
        }

        return false
    }

    private func interceptIdentifyEvent(_ event: BaseEvent) throws -> BaseEvent? {
        if isIdentityUpdated(event) {
            transferInterceptedIdentifyEvent()
        }

        switch event.eventType  {
        case Constants.IDENTIFY_EVENT:
            if isInterceptEvent(event) {
                try writeEventToStorage(event)
                return nil
            } else if hasOperation(properties: event.userProperties, operation: Identify.Operation.CLEAR_ALL) {
                removeEventsFromStorage()
                return event;
            } else {
                return mergeEventUserProperties(destination: event, source: getCombinedInterceptedIdentify())
            }
        case Constants.GROUP_IDENTIFY_EVENT:
            return event
        default:
            if hasOperation(properties: event.userProperties, operation: Identify.Operation.CLEAR_ALL) {
                removeEventsFromStorage()
                return event
            } else {
                return mergeEventUserProperties(destination: event, source: getCombinedInterceptedIdentify())
            }
        }
    }

    func getCombinedInterceptedIdentify() -> BaseEvent? {
        var combinedInterceptedIdentify: BaseEvent?
        let eventFiles: [URL]? = storage.read(key: StorageKey.EVENTS)

        if let eventFiles {
            for eventFile in eventFiles {
                guard let eventsString = storage.getEventsString(eventBlock: eventFile) else {
                    continue
                }
                if eventsString.isEmpty {
                    continue
                }

                if let events = BaseEvent.fromArrayString(jsonString: eventsString) {
                    for event in events {
                        if let dest = combinedInterceptedIdentify {
                            combinedInterceptedIdentify = mergeEventUserProperties(destination: dest, source: event)
                        } else {
                            combinedInterceptedIdentify = event
                        }
                    }
                }
            }

            for eventFile in eventFiles {
                storage.remove(eventBlock: eventFile)
            }
        }

        return combinedInterceptedIdentify
    }

    func getUserPropertySetValues(_ event: BaseEvent) -> [String: Any?]? {
        if let setProperties = event.userProperties?[Identify.Operation.SET.rawValue] as? [String: Any?]? {
            return setProperties
        }
        
        return nil
    }
    
    func mergeEventUserProperties(destination: BaseEvent, source: BaseEvent?) -> BaseEvent {
        if let source {
            var sourceUserProperties: [String: Any?]?
            var destinationUserProperties: [String: Any?]?
            let flattenUserProperties = destination.eventType != Constants.IDENTIFY_EVENT;
            
            // note source is always an Identify
            sourceUserProperties = getUserPropertySetValues(source)
            destinationUserProperties = flattenUserProperties
            ? destination.userProperties
            : getUserPropertySetValues(destination)
            
            if (flattenUserProperties) {
                destination.userProperties = mergeUserProperties(
                    destination: destinationUserProperties,
                    source: sourceUserProperties
                )
            } else {
                destination.userProperties = destination.userProperties ?? [:];
                destination.userProperties![Identify.Operation.SET.rawValue] = mergeUserProperties(
                    destination: destinationUserProperties,
                    source: sourceUserProperties
                )
            }
            
            if let destinationUserProperties {
                if (flattenUserProperties) {
                    destination.userProperties = mergeUserProperties(
                        destination: destination.userProperties,
                        source: destinationUserProperties
                    )
                } else {
                    destination.userProperties = mergeUserPropertiesOperations(
                        destination: destination.userProperties,
                        source: [Identify.Operation.SET.rawValue: destinationUserProperties]
                    )
                }
            }
        }
        return destination
    }

    func transferInterceptedIdentifyEvent() {
        if let interceptedEvent = getCombinedInterceptedIdentify() {
            pipeline.put(event: interceptedEvent)
        }
    }

    private func writeEventToStorage(_ event: BaseEvent) throws {
        try storage.write(key: StorageKey.EVENTS, value: event)
        scheduleTransferInterceptedIdentifyEvent()
    }

    private func removeEventsFromStorage() {
        guard let eventFiles: [URL] = storage.read(key: StorageKey.EVENTS) else { return }
        for eventFile in eventFiles {
            storage.remove(eventBlock: eventFile)
        }
    }

    private func scheduleTransferInterceptedIdentifyEvent() {
        guard identifyTransferTimer == nil else {
            return
        }

        identifyTransferTimer = QueueTimer(interval: getIdentifyBatchInterval(), once: true) { [weak self] in
            let transferInterceptedIdentifyEvent = self?.transferInterceptedIdentifyEvent
            self?.identifyTransferTimer = nil
            transferInterceptedIdentifyEvent?()
        }
    }

    func mergeUserPropertiesOperations(destination: [String: Any?]?, source: [String: Any?]?) -> [String: Any?] {
        let destinationSetProperties = destination?[Identify.Operation.SET.rawValue] as? [String: Any?] ?? [:]
        let sourceSetProperties = source?[Identify.Operation.SET.rawValue] as? [String: Any?] ?? [:]

        var result = destination ?? [:]
        result[Identify.Operation.SET.rawValue] = mergeUserProperties(
            destination: destinationSetProperties,
            source: sourceSetProperties
        );
        return result
    }
    
    func mergeUserProperties(destination: [String: Any?]?, source: [String: Any?]?) -> [String: Any?] {
        var result = destination ?? [:]
        result = result.merging(source ?? [:]) { _, new in new }
        
        return result
    }

    /**
     * Returns true if the given event should be intercepted
     */
    func isInterceptEvent(_ event: BaseEvent) -> Bool {
        return event.eventType == Constants.IDENTIFY_EVENT
            && isEmptyValues(event.groups)
            && hasOnlyOperation(properties: event.userProperties, operation: Identify.Operation.SET)
    }

    private func isEmptyValues(_ values: [String: Any?]?) -> Bool {
        return values == nil || values?.isEmpty == true
    }

    private func hasOnlyOperation(properties: [String: Any?]?, operation: Identify.Operation) -> Bool {
        return hasOperation(properties: properties, operation: operation) && properties?.count == 1
    }

    private func hasOperation(properties: [String: Any?]?, operation: Identify.Operation) -> Bool {
        return !isEmptyValues(properties) && properties![operation.rawValue] != nil
    }

    private func getIdentifyBatchInterval() -> TimeInterval {
        let identifyBatchIntervalMillis = max(
            configuration.identifyBatchIntervalMillis,
            minIdentifyBatchInterval
        )
        return TimeInterval.milliseconds(identifyBatchIntervalMillis)
    }
}
