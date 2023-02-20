import Foundation

public class IdentifyInterceptor {
    private let allowedOperations = Set([
        Identify.Operation.CLEAR_ALL.rawValue,
        Identify.Operation.SET.rawValue
    ])

    public func mergeIdentifyEvents(event1: BaseEvent, event2: BaseEvent) -> BaseEvent? {
        guard canMergeIdentifyEvents(event1: event1, event2: event2) else {
            return nil
        }

        event1.userProperties = mergeUserProperties(userProperties1: event1.userProperties, userProperties2: event2.userProperties)
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

    public func canMergeIdentifyEvents(event1: BaseEvent, event2: BaseEvent) -> Bool {
        return event1.userId == event2.userId && event1.deviceId == event2.deviceId
            && canMergeIdentifyEvent(event1)
            && canMergeIdentifyEvent(event2)
    }

    public func canMergeIdentifyEvent(_ event: BaseEvent) -> Bool {
        return event.eventType == Constants.IDENTIFY_EVENT
            && isEmptyValues(event.groups)
            && hasAllowedOperationsOnly(event.userProperties)
    }

    private func isEmptyValues(_ values: [String: Any?]?) -> Bool {
        return values == nil || values?.isEmpty == true
    }

    private func hasAllowedOperationsOnly(_ values: [String: Any?]?) -> Bool {
        return isEmptyValues(values) || values!.allSatisfy { key, _ in allowedOperations.contains(key) }
    }
}
