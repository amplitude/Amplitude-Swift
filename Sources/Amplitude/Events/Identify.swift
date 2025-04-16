//
//  Identify.swift
//
//
//  Created by Marvin Liu on 12/8/22.
//

import Foundation
import OSLog

open class Identify {
    static let UNSET_VALUE = "-"

    enum Operation: String {
        case SET = "$set"
        case SET_ONCE = "$setOnce"
        case ADD = "$add"
        case APPEND = "$append"
        case CLEAR_ALL = "$clearAll"
        case PREPEND = "$prepend"
        case UNSET = "$unset"
        case PRE_INSERT = "$preInsert"
        case POST_INSERT = "$postInsert"
        case REMOVE = "$remove"

        static let orderedCases: [Operation] = [
            .CLEAR_ALL,
            .UNSET,
            .SET,
            .SET_ONCE,
            .ADD,
            .APPEND,
            .PREPEND,
            .PRE_INSERT,
            .POST_INSERT,
            .REMOVE,
        ]
    }

    public init() {}

    var propertySet = Set<String>()
    var properties = [String: Any]()

    // $set operation
    @discardableResult
    public func set(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: Int) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: Float) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: Double) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: String) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    public func set(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    // $setOnce operation
    @discardableResult
    public func setOnce(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: Int) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: Float) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: Double) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: String) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    public func setOnce(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    // $prepend operation
    @discardableResult
    public func prepend(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: Int) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: Float) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: Double) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: String) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func prepend(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    // $append operation
    @discardableResult
    public func append(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: Int) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: Float) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: Double) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: String) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    public func append(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    // $postInsert operation
    @discardableResult
    public func postInsert(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: Int) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: Float) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: Double) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: String) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func postInsert(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    // $preInsert operation
    @discardableResult
    public func preInsert(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: Int) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: Float) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: Double) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: String) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    public func preInsert(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    // $remove operation
    @discardableResult
    public func remove(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: Int) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: Float) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: Double) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: String) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    public func remove(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    // $add operation
    @discardableResult
    public func add(property: String, value: Int) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    public func add(property: String, value: Float) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    public func add(property: String, value: Double) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    public func add(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    // $unset operation
    @discardableResult
    public func unset(property: String) -> Identify {
        setUserProperty(operation: .UNSET, property: property, value: Identify.UNSET_VALUE)
        return self
    }

    // $clearAll operation
    @discardableResult
    public func clearAll() -> Identify {
        properties.removeAll()
        properties[Operation.CLEAR_ALL.rawValue] = Identify.UNSET_VALUE
        return self
    }

    private static let logger = OSLog(subsystem: "Amplitude", category: "Logging")

    func setUserProperty(operation: Operation, property: String, value: Any?) {
        guard !property.isEmpty else {
            os_log(.default,
                   log: Self.logger,
                   "Warn: Attempting to perform operation %@ with a null or empty string property, ignoring",
                   operation.rawValue)
            return
        }
        guard value != nil else {
            os_log(.default,
                   log: Self.logger,
                   "Warn: Attempting to perform operation %@ with null value for property %@, ignoring",
                   operation.rawValue,
                   property)
            return
        }
        guard properties[Operation.CLEAR_ALL.rawValue] == nil else {
            os_log(.default,
                   log: Self.logger,
                   "Warn: This Identify already contains a $clearAll operation, ignoring operation %@",
                   operation.rawValue)
            return
        }
        guard properties[property] == nil else {
            os_log(.default,
                   log: Self.logger,
                   "Warn: Already used property %@ in previous operation, ignoring operation %@",
                   property,
                   operation.rawValue)
            return
        }
        if properties[operation.rawValue] == nil {
            properties[operation.rawValue] = [String: Any]()
        }
        if var prop = properties[operation.rawValue] as? [String: Any] {
            prop[property] = value!
            properties[operation.rawValue] = prop  // need to assign back for nested dict
            propertySet.insert(property)
        }
    }
}
