import Foundation

public class IdentifyInterceptor {
    private static let allowedOperations = Set([
        Identify.Operation.CLEAR_ALL.rawValue,
        Identify.Operation.SET.rawValue
    ])

    private let configuration: Configuration
    private let pipeline: EventPipeline
    private let logger: (any Logger)?
    private var identifyTransferTimer: QueueTimer?
    private let minIdentifyBatchInterval: Int

    private lazy var storage: any Storage = {
        return self.configuration.storageProvider
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

    public func intercept(event: BaseEvent) -> BaseEvent? {
        do {
            return try interceptIdentifyEvent(event)
        } catch {
            logger?.error(message: "Error when intercept event: \(error.localizedDescription)")
            return event
        }
    }

    private func interceptIdentifyEvent(_ event: BaseEvent) throws -> BaseEvent? {
        var mergedInterceptedIdentifyEvent: BaseEvent?
        let interceptedIdentifyEvent = try getInterceptedIdentifyEventFromStorage()
        if let interceptedIdentifyEvent {
            mergedInterceptedIdentifyEvent = mergeEvents(destination: interceptedIdentifyEvent, source: event)
        }

        if let mergedInterceptedIdentifyEvent {
            try writeInterceptedIdentifyEventToStorage(mergedInterceptedIdentifyEvent)
            return nil
        } else {
            if let interceptedIdentifyEvent {
                if let mergedEvent = mergeEvents(destination: event, source: interceptedIdentifyEvent) {
                    try removeInterceptedIdentifyEventFromStorage()
                    return mergedEvent
                }
                transferInterceptedIdentifyEvent()
            }

            if event.eventType == Constants.IDENTIFY_EVENT && isAllowedMergeDestination(event) {
                try writeInterceptedIdentifyEventToStorage(event)
                return nil
            } else {
                return event
            }
        }
    }

    func transferInterceptedIdentifyEvent() {
        do {
            if let interceptedIdentifyEvent = try getInterceptedIdentifyEventFromStorage() {
                pipeline.put(event: interceptedIdentifyEvent)
                try removeInterceptedIdentifyEventFromStorage()
            }
        } catch {
            logger?.error(message: "Error when transfer intercepted identify event: \(error.localizedDescription)")
        }
    }

    private func getInterceptedIdentifyEventFromStorage() throws -> BaseEvent? {
        return storage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
    }

    private func writeInterceptedIdentifyEventToStorage(_ event: BaseEvent) throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: event)
        scheduleTransferInterceptedIdentifyEvent()
    }

    private func removeInterceptedIdentifyEventFromStorage() throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: nil)
        identifyTransferTimer = nil
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

    func mergeEvents(destination: BaseEvent, source: BaseEvent) -> BaseEvent? {
        guard canMergeEvents(destination: destination, source: source) else {
            return nil
        }

        if let mergedUserProperties = mergeUserProperties(userProperties1: destination.userProperties, userProperties2: source.userProperties) {
            destination.userProperties = mergedUserProperties
        }
        return destination
    }

    private func mergeUserProperties(userProperties1: [String: Any?]?, userProperties2: [String: Any?]?) -> [String: Any?]? {
        if isEmptyValues(userProperties1) {
            return userProperties2
        }
        if isEmptyValues(userProperties2) {
            return userProperties1
        }
        if userProperties1?[Identify.Operation.CLEAR_ALL.rawValue] != nil {
            return userProperties2
        }
        if userProperties2?[Identify.Operation.CLEAR_ALL.rawValue] != nil {
            return userProperties2
        }

        let userSetProperties1 = userProperties1?[Identify.Operation.SET.rawValue] as? [String: Any?]
        let userSetProperties2 = userProperties2?[Identify.Operation.SET.rawValue] as? [String: Any?]

        if isEmptyValues(userSetProperties1) {
            return userProperties2
        }
        if isEmptyValues(userSetProperties2) {
            return userProperties1
        }

        var result = userProperties1!
        result[Identify.Operation.SET.rawValue] = userSetProperties1!.merging(userSetProperties2!) { _, new in new }
        return result
    }

    func canMergeEvents(destination: BaseEvent, source: BaseEvent) -> Bool {
        return destination.userId == source.userId && destination.deviceId == source.deviceId
            && isAllowedMergeDestination(destination)
            && isAllowedMergeSource(source)
            && (destination.userProperties?[Identify.Operation.CLEAR_ALL.rawValue] == nil
                || source.userProperties?[Identify.Operation.SET.rawValue] == nil)
    }

    func isAllowedMergeDestination(_ event: BaseEvent) -> Bool {
        return event.eventType != Constants.GROUP_IDENTIFY_EVENT
            && isEmptyValues(event.groups)
            && hasAllowedOperationsOnly(event.userProperties)
    }

    func isAllowedMergeSource(_ event: BaseEvent) -> Bool {
        return event.eventType == Constants.IDENTIFY_EVENT
            && isEmptyValues(event.groups)
            && hasAllowedOperationsOnly(event.userProperties)
    }

    private func isEmptyValues(_ values: [String: Any?]?) -> Bool {
        return values == nil || values?.isEmpty == true
    }

    private func hasAllowedOperationsOnly(_ values: [String: Any?]?) -> Bool {
        return isEmptyValues(values) || values!.allSatisfy { key, _ in Self.allowedOperations.contains(key) }
    }

    private func getIdentifyBatchInterval() -> TimeInterval {
        let identifyBatchIntervalMillis = max(
            configuration.identifyBatchIntervalMillis,
            minIdentifyBatchInterval
        )
        return TimeInterval.milliseconds(identifyBatchIntervalMillis)
    }
}
