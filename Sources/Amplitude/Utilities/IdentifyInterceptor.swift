import Foundation

public class IdentifyInterceptor {
    private struct EventState: Equatable {
        let userId: String?
        let deviceId: String?

        init(_ event: BaseEvent) {
            userId = event.userId
            deviceId = event.deviceId
        }
    }

    private static let allowedOperations = Set([
        Identify.Operation.CLEAR_ALL.rawValue,
        Identify.Operation.SET.rawValue
    ])

    private let configuration: Configuration
    private let pipeline: EventPipeline
    private let logger: (any Logger)?
    private var identifyTransferTimer: QueueTimer?
    private let minIdentifyBatchInterval: Int

    private var lastEventState: EventState?

    private lazy var storage: any Storage = {
        return self.configuration.identifyStorageProvider
    }()

    init(
        configuration: Configuration,
        pipeline: EventPipeline,
        logger: (any Logger)?,
        minIdentifyBatchInterval: Int = Constants.Configuration.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS
    ) {
        self.configuration = configuration
        self.pipeline = pipeline
        self.logger = logger
        self.minIdentifyBatchInterval = minIdentifyBatchInterval
    }

    public func intercept(event: BaseEvent) {
        do {
            try interceptIdentifyEvent(event)
        } catch {
            logger?.error(message: "Error when intercept event: \(error.localizedDescription)")
        }
    }

    private func interceptIdentifyEvent(_ event: BaseEvent) throws {
        let eventState = EventState(event)
        if (lastEventState != eventState) {
            transferInterceptedIdentifyEvent(destination: nil)
            lastEventState = eventState
        }

        switch event.eventType  {
        case Constants.IDENTIFY_EVENT:
            if isAllowedMergeSource(event) {
                try writeEventToStorage(event)
            } else if hasOperation(properties: event.userProperties, operation: Identify.Operation.CLEAR_ALL) {
                removeEventsFromStorage()
            } else {
                transferInterceptedIdentifyEvent(destination: event)
            }
        case Constants.GROUP_IDENTIFY_EVENT:
            pipeline.put(event: event)
        default:
            if hasOperation(properties: event.userProperties, operation: Identify.Operation.CLEAR_ALL) {
                removeEventsFromStorage()
                pipeline.put(event: event)
            } else {
                transferInterceptedIdentifyEvent(destination: event)
            }
        }
    }

    func transferInterceptedIdentifyEvent(destination: BaseEvent?) {
        var interceptedEvent = destination
        let eventFiles: [URL]? = storage.read(key: StorageKey.EVENTS)

        if let eventFiles {
            var destinationUserProperties: [String: Any?]? = nil
            if let destination, let setProperties = destination.userProperties?[Identify.Operation.SET.rawValue] as? [String: Any?]? {
                destinationUserProperties = [Identify.Operation.SET.rawValue: setProperties]
                destination.userProperties![Identify.Operation.SET.rawValue] = [:]
            }

            for eventFile in eventFiles {
                guard let eventsString = storage.getEventsString(eventBlock: eventFile) else {
                    continue
                }
                if eventsString.isEmpty {
                    continue
                }

                if let events = BaseEvent.fromArrayString(jsonString: eventsString) {
                    for event in events {
                        if let dest = interceptedEvent {
                            interceptedEvent!.userProperties = mergeUserProperties(destination: dest.userProperties, source: event.userProperties)
                        } else {
                            interceptedEvent = event
                        }
                    }
                }
            }

            if let destinationUserProperties {
                interceptedEvent!.userProperties = mergeUserProperties(destination: interceptedEvent!.userProperties, source: destinationUserProperties)
            }
        }

        if let interceptedEvent {
            pipeline.put(event: interceptedEvent)
        }

        if let eventFiles {
            for eventFile in eventFiles {
                storage.remove(eventBlock: eventFile)
            }
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
            transferInterceptedIdentifyEvent?(nil)
        }
    }

    func mergeUserProperties(destination: [String: Any?]?, source: [String: Any?]?) -> [String: Any?] {
        let destinationSetProperties = destination?[Identify.Operation.SET.rawValue] as? [String: Any?] ?? [:]
        let sourceSetProperties = source?[Identify.Operation.SET.rawValue] as? [String: Any?] ?? [:]

        var result = destination ?? [:]
        result[Identify.Operation.SET.rawValue] = destinationSetProperties.merging(sourceSetProperties) { _, new in new }
        return result
    }

    func isAllowedMergeSource(_ event: BaseEvent) -> Bool {
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
