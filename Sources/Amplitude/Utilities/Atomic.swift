//
//  Atomic.swift
//
//
//  Created by Marvin Liu on 11/29/22.
//

import Foundation

@propertyWrapper
public struct Atomic<T> {
    var value: T
    private let lock = NSLock()

    public init(wrappedValue value: T) {
        self.value = value
    }

    public var wrappedValue: T {
        get { return load() }
        set { store(newValue: newValue) }
    }

    func load() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    mutating func store(newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}

extension NSLock {
    func synchronizedLazy<T>(_ storage: inout T?, initializer: () -> T) -> T {
        lock()
        defer { unlock() }
        if let existing = storage {
            return existing
        }
        let newValue = initializer()
        storage = newValue
        return newValue
    }
}
