//
//  Identify.swift
//
//
//  Created by Marvin Liu on 12/8/22.
//

import Foundation

@objc public class Identify : NSObject {
    static let UNSET_VALUE = "-"

    enum Operation: String {
        case SET = "$set"
        case SET_ONCE = "$set_once"
        case ADD = "$add"
        case APPEND = "$append"
        case CLEAR_ALL = "$clearAll"
        case PREPEND = "$prepend"
        case UNSET = "$unset"
        case PRE_INSERT = "$preInsert"
        case POST_INSERT = "$postInsert"
        case REMOVE = "$remove"
    }

    public override init() {}

    var propertySet = Set<String>()
    var properties = [String: Any?]()
    var logger = ConsoleLogger(logLevel: LogLevelEnum.WARN.rawValue)

    // $set operation
    @discardableResult
    @objc(setBool::)
    public func set(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setInt::)
    public func set(property: String, value: Int) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setFloat::)
    public func set(property: String, value: Float) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setDouble::)
    public func set(property: String, value: Double) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setInt64::)
    public func set(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setString::)
    public func set(property: String, value: String) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setObjectArray::)
    public func set(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setAnyArray::)
    public func set(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setBoolArray::)
    public func set(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setIntArray::)
    public func set(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setFloatArray::)
    public func set(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setDoubleArray::)
    public func set(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setInt64Array::)
    public func set(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setStringArray::)
    public func set(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setAny::)
    public func set(property: String, value: Any?) -> Identify {
        setUserProperty(operation: .SET, property: property, value: value)
        return self
    }

    // $setOnce operation
    @discardableResult
    @objc(setOnceBool::)
    public func setOnce(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceInt::)
    public func setOnce(property: String, value: Int) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceFloat::)
    public func setOnce(property: String, value: Float) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceDouble::)
    public func setOnce(property: String, value: Double) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceInt64::)
    public func setOnce(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceString::)
    public func setOnce(property: String, value: String) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceObjectArray::)
    public func setOnce(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceAnyArray::)
    public func setOnce(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceBoolArray::)
    public func setOnce(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceIntArray::)
    public func setOnce(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceFloatArray::)
    public func setOnce(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceDoubleArray::)
    public func setOnce(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceInt64Array::)
    public func setOnce(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(setOnceStringArray::)
    public func setOnce(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .SET_ONCE, property: property, value: value)
        return self
    }

    // $prepend operation
    @discardableResult
    @objc(prependBool::)
    public func prepend(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependInt::)
    public func prepend(property: String, value: Int) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependFloat::)
    public func prepend(property: String, value: Float) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependDouble::)
    public func prepend(property: String, value: Double) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependInt64::)
    public func prepend(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependString::)
    public func prepend(property: String, value: String) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependObject::)
    public func prepend(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependAnyArray::)
    public func prepend(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependBoolArray::)
    public func prepend(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependIntArray::)
    public func prepend(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependFloatArray::)
    public func prepend(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependDoubleArray::)
    public func prepend(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependInt64Array::)
    public func prepend(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(prependStringArray::)
    public func prepend(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .PREPEND, property: property, value: value)
        return self
    }

    // $append operation
    @discardableResult
    @objc(appendBool::)
    public func append(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendInt::)
    public func append(property: String, value: Int) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendFloat::)
    public func append(property: String, value: Float) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendDouble::)
    public func append(property: String, value: Double) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendInt64::)
    public func append(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendString::)
    public func append(property: String, value: String) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendObject::)
    public func append(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendAnyArray::)
    public func append(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendBoolArray::)
    public func append(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendIntArray::)
    public func append(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendFloatArray::)
    public func append(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendDoubleArray::)
    public func append(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendInt64Array::)
    public func append(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(appendStringArray::)
    public func append(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .APPEND, property: property, value: value)
        return self
    }

    // $postInsert operation
    @discardableResult
    @objc(postInsertBool::)
    public func postInsert(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertInt::)
    public func postInsert(property: String, value: Int) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertFloat::)
    public func postInsert(property: String, value: Float) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertDouble::)
    public func postInsert(property: String, value: Double) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertInt64::)
    public func postInsert(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertString::)
    public func postInsert(property: String, value: String) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertObjectArray::)
    public func postInsert(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertAnyArray::)
    public func postInsert(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertBoolArray::)
    public func postInsert(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertIntArray::)
    public func postInsert(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertFloatArray::)
    public func postInsert(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertDoubleArray::)
    public func postInsert(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertInt64Array::)
    public func postInsert(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(postInsertStringArray::)
    public func postInsert(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .POST_INSERT, property: property, value: value)
        return self
    }

    // $preInsert operation
    @discardableResult
    @objc(preInsertBool::)
    public func preInsert(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertInt::)
    public func preInsert(property: String, value: Int) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertFloat::)
    public func preInsert(property: String, value: Float) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertDouble::)
    public func preInsert(property: String, value: Double) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertInt64::)
    public func preInsert(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertString::)
    public func preInsert(property: String, value: String) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertObjectArray::)
    public func preInsert(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertAnyArray::)
    public func preInsert(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertBoolArray::)
    public func preInsert(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertIntArray::)
    public func preInsert(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertFloatArray::)
    public func preInsert(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertDoubleArray::)
    public func preInsert(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertInt64Array::)
    public func preInsert(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(preInsertStringArray::)
    public func preInsert(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .PRE_INSERT, property: property, value: value)
        return self
    }

    // $remove operation
    @discardableResult
    @objc(removeBool::)
    public func remove(property: String, value: Bool) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeInt::)
    public func remove(property: String, value: Int) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeFloat::)
    public func remove(property: String, value: Float) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeDouble::)
    public func remove(property: String, value: Double) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeInt64::)
    public func remove(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeString::)
    public func remove(property: String, value: String) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeObjectArray::)
    public func remove(property: String, value: [String: Any]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeAnyArray::)
    public func remove(property: String, value: [Any]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeBoolArray::)
    public func remove(property: String, value: [Bool]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeIntArray::)
    public func remove(property: String, value: [Int]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeFloatArray::)
    public func remove(property: String, value: [Float]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeDoubleArray::)
    public func remove(property: String, value: [Double]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeInt64Array::)
    public func remove(property: String, value: [Int64]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(removeStringArray::)
    public func remove(property: String, value: [String]) -> Identify {
        setUserProperty(operation: .REMOVE, property: property, value: value)
        return self
    }

    // $add operation
    @discardableResult
    @objc(addInt::)
    public func add(property: String, value: Int) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(addFloat::)
    public func add(property: String, value: Float) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(addDouble::)
    public func add(property: String, value: Double) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    @discardableResult
    @objc(addInt64::)
    public func add(property: String, value: Int64) -> Identify {
        setUserProperty(operation: .ADD, property: property, value: value)
        return self
    }

    // $unset operation
    @discardableResult
    @objc public func unset(proprety: String) -> Identify {
        setUserProperty(operation: .UNSET, property: proprety, value: Identify.UNSET_VALUE)
        return self
    }

    // $clearAll operation
    @discardableResult
    @objc
    public func clearAll() -> Identify {
        properties.removeAll()
        properties[Operation.CLEAR_ALL.rawValue] = Identify.UNSET_VALUE
        return self
    }

    func setUserProperty(operation: Operation, property: String, value: Any?) {
        guard !property.isEmpty else {
            logger.warn(
                message:
                    "Attempting to perform operation \(operation.rawValue) with a null or empty string property, ignoring"
            )
            return
        }
        guard value != nil else {
            logger.warn(
                message:
                    "Attempting to perform operation \(operation.rawValue) with null value for property \(property), ignoring"
            )
            return
        }
        guard properties[Operation.CLEAR_ALL.rawValue] == nil else {
            logger.warn(
                message:
                    "This Identify already contains a $clearAll operation, ignoring operation \(operation.rawValue)"
            )
            return
        }
        guard !propertySet.contains(property) else {
            logger.warn(
                message:
                    "Already used property \(property) in previous operation, ignoring operation \(operation.rawValue)"
            )
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
