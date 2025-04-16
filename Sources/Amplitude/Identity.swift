//
//  Identity.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 3/28/25.
//

public struct Identity {
    var userId: String?
    var deviceId: String?
    var userProperties: [String: Any] = [:]
}

extension Identity {

    mutating func apply(identify: [String: Any]) {
        var updatedProperties = userProperties

        for op in Identify.Operation.orderedCases {
            guard let properties = identify[op.rawValue] else {
                continue
            }

            let opProperties = properties as? [String: Any] ?? [:]

            switch op {
            case .SET:
                updatedProperties.merge(opProperties) { (_, new) in new }
            case .CLEAR_ALL:
                updatedProperties = [:]
            case .UNSET:
                for (key, _) in opProperties {
                    updatedProperties[key] = nil
                }
            case .SET_ONCE, .ADD, .APPEND, .PREPEND, .PRE_INSERT, .POST_INSERT, .REMOVE:
                // Unsupported
                break
            }
        }

        userProperties = updatedProperties
    }
}
