//
//  Swizzler.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 3/6/25.
//

import Foundation
import ObjectiveC.runtime

final class MethodSwizzler {

    private struct MethodChain {
        var originalIMP: IMP
        var swizzledSelectors: [Selector]
    }

    private static var swizzleChains: [ObjectIdentifier: [String: MethodChain]] = [:]

    private static let lock = NSLock()

    @discardableResult
    static func swizzleInstanceMethod(for cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let classKey = ObjectIdentifier(cls)
        let originalSelName = NSStringFromSelector(originalSelector)
        let swizzledSelName = NSStringFromSelector(swizzledSelector)

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector) else {
            print("Failed to swizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the original method was not found")
            return false
        }

        guard let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            print("Failed to swizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the swizzled method was not found")
            return false
        }

        var classSwizzles = swizzleChains[classKey] ?? [:]
        var methodChain = classSwizzles[originalSelName]
        let originalIMP = method_getImplementation(originalMethod)

        if methodChain == nil {
            methodChain = MethodChain(originalIMP: originalIMP, swizzledSelectors: [])
        } else {
            guard methodChain?.swizzledSelectors.contains(swizzledSelector) != true else {
                print("Failed to swizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the method has already been swizzled")
                return false
            }
        }

        let methodAdded = class_addMethod(
            cls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if methodAdded {
            class_replaceMethod(
                cls,
                swizzledSelector,
                originalIMP,
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        methodChain?.swizzledSelectors.append(swizzledSelector)
        classSwizzles[originalSelName] = methodChain
        swizzleChains[classKey] = classSwizzles

        return true
    }

    @discardableResult
    static func unswizzleInstanceMethod(for cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let classKey = ObjectIdentifier(cls)
        let originalSelName = NSStringFromSelector(originalSelector)
        let swizzledSelName = NSStringFromSelector(swizzledSelector)

        guard var classSwizzles = swizzleChains[classKey],
              var methodChain = classSwizzles[originalSelName] else {
            print("Failed to unswizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the method was not swizzled")
            return false
        }

        guard let index = methodChain.swizzledSelectors.firstIndex(of: swizzledSelector) else {
            print("Failed to unswizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the method was not swizzled")
            return false
        }

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            print("Failed to unswizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the method was not found")
            return false
        }

        let isLastSwizzle = index == methodChain.swizzledSelectors.count - 1
        if isLastSwizzle {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        } else {
            let nextSwizzledSelector = methodChain.swizzledSelectors[index + 1]
            guard let nextSwizzledMethod = class_getInstanceMethod(cls, nextSwizzledSelector) else {
                print("Failed to unswizzle \(originalSelName) with \(swizzledSelName) on \(cls) because the next swizzled method was not found")
                return false
            }
            method_exchangeImplementations(swizzledMethod, nextSwizzledMethod)
        }

        methodChain.swizzledSelectors.remove(at: index)
        classSwizzles[originalSelName] = methodChain
        swizzleChains[classKey] = classSwizzles

        return true
    }
}
