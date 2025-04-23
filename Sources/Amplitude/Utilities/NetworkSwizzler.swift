//
//  NetworkSwizzler.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 3/6/25.
//

import Foundation

public protocol NetworkTaskListener: AnyObject {
    func onTaskResume(_ task: URLSessionTask)
    func onTask(_ task: URLSessionTask, setState state: URLSessionTask.State)
}

class NetworkSwizzler {

    static let shared = NetworkSwizzler()

    private var listeners: [NetworkTaskListener] = []
    private var swizzled: Bool = false
    private let lock = NSLock()

    func swizzle() {
        lock.lock()
        defer { lock.unlock() }

        guard !swizzled else { return }

        swizzled = true
        MethodSwizzler.swizzleInstanceMethod(for: URLSessionTask.self, originalSelector: #selector(URLSessionTask.resume), swizzledSelector: #selector(URLSessionTask.amp_resume))
        MethodSwizzler.swizzleInstanceMethod(for: URLSessionTask.self, originalSelector: NSSelectorFromString("setState:"), swizzledSelector: #selector(URLSessionTask.amp_setState))
    }

    func unswizzle() {
        lock.lock()
        defer { lock.unlock() }

        guard !swizzled else { return }
        swizzled = false

        MethodSwizzler.unswizzleInstanceMethod(for: URLSessionTask.self, originalSelector: #selector(URLSessionTask.resume), swizzledSelector: #selector(URLSessionTask.amp_resume))
        MethodSwizzler.unswizzleInstanceMethod(for: URLSessionTask.self, originalSelector: NSSelectorFromString("setState:"), swizzledSelector: #selector(URLSessionTask.amp_setState))
    }

    func addListener(listener: NetworkTaskListener) {
        lock.withLock {
            listeners.append(listener)
        }
    }

    func removeListener(listener: NetworkTaskListener) {
        lock.withLock {
            listeners.removeAll { $0 === listener }
        }
    }

    fileprivate func onTaskResume(task: URLSessionTask) {
        let listeners = lock.withLock { return self.listeners }
        for listener in listeners {
            listener.onTaskResume(task)
        }
    }

    fileprivate func onTaskSetState(task: URLSessionTask, state: URLSessionTask.State) {
        let listeners = lock.withLock { return self.listeners }
        for listener in listeners {
            listener.onTask(task, setState: state)
        }
    }
}

extension URLSessionTask {
    @objc fileprivate func amp_resume() {
        NetworkSwizzler.shared.onTaskResume(task: self)
        amp_resume()
    }

    @objc fileprivate func amp_setState(_ state: URLSessionTask.State) {
        NetworkSwizzler.shared.onTaskSetState(task: self, state: state)
        amp_setState(state)
    }
}
