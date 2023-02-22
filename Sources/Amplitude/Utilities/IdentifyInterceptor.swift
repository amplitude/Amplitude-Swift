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
            mergedInterceptedIdentifyEvent = mergeIdentifyEvents(event1: interceptedIdentifyEvent, event2: event)
        }

        if let mergedInterceptedIdentifyEvent {
            try writeInterceptedIdentifyEventToStorage(mergedInterceptedIdentifyEvent)
            return nil
        } else {
            _ = transferInterceptedIdentifyEvent()

            if canMergeIdentifyEvent(event) {
                try writeInterceptedIdentifyEventToStorage(event)
                return nil
            } else {
                return event
            }
        }
    }

    func transferInterceptedIdentifyEvent() -> Bool {
        do {
            if let interceptedIdentifyEvent = try getInterceptedIdentifyEventFromStorage() {
                pipeline.put(event: interceptedIdentifyEvent)
                try removeInterceptedIdentifyEventFromStorage()
                return true
            }
        } catch {
            logger?.error(message: "Error when transfer intercepted identify event: \(error.localizedDescription)")
        }
        return false
    }

    private func getInterceptedIdentifyEventFromStorage() throws -> BaseEvent? {
        return storage.read(key: StorageKey.INTERCEPTED_IDENTIFY)
    }

    private func writeInterceptedIdentifyEventToStorage(_ event: BaseEvent) throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: event)
        scheduleInterceptedIdentifyFlush()
    }

    private func removeInterceptedIdentifyEventFromStorage() throws {
        try storage.write(key: StorageKey.INTERCEPTED_IDENTIFY, value: nil)
        identifyTransferTimer = nil
    }

    private func scheduleInterceptedIdentifyFlush() {
        guard identifyTransferTimer == nil else {
            return
        }

        identifyTransferTimer = QueueTimer(interval: getIdentifyBatchInterval(), once: true) { [weak self] in
            let transferred = self?.transferInterceptedIdentifyEvent() == true
            let flush = self?.pipeline.flush
            self?.identifyTransferTimer = nil
            if transferred {
                flush?(nil)
            }
        }
    }

    func mergeIdentifyEvents(event1: BaseEvent, event2: BaseEvent) -> BaseEvent? {
        guard canMergeIdentifyEvents(event1: event1, event2: event2) else {
            return nil
        }

        if let mergedUserProperties = mergeUserProperties(userProperties1: event1.userProperties, userProperties2: event2.userProperties) {
            event1.userProperties = mergedUserProperties
        }
        return event1
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

    func canMergeIdentifyEvents(event1: BaseEvent, event2: BaseEvent) -> Bool {
        return event1.userId == event2.userId && event1.deviceId == event2.deviceId
            && canMergeIdentifyEvent(event1)
            && canMergeIdentifyEvent(event2)
            && (event1.userProperties?[Identify.Operation.CLEAR_ALL.rawValue] == nil
                || event2.userProperties?[Identify.Operation.SET.rawValue] == nil)
    }

    func canMergeIdentifyEvent(_ event: BaseEvent) -> Bool {
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
