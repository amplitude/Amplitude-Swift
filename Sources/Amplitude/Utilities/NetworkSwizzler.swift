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

    private let listenerLock = NSLock()

    func swizzle() {
        MethodSwizzler.swizzleInstanceMethod(for: URLSessionTask.self, originalSelector: #selector(URLSessionTask.resume), swizzledSelector: #selector(URLSessionTask.amp_resume))
        MethodSwizzler.swizzleInstanceMethod(for: URLSessionTask.self, originalSelector: NSSelectorFromString("setState:"), swizzledSelector: #selector(URLSessionTask.amp_setState))
    }

    func unswizzle() {
        MethodSwizzler.unswizzleInstanceMethod(for: URLSessionTask.self, originalSelector: #selector(URLSessionTask.resume), swizzledSelector: #selector(URLSessionTask.amp_resume))
        MethodSwizzler.unswizzleInstanceMethod(for: URLSessionTask.self, originalSelector: NSSelectorFromString("setState:"), swizzledSelector: #selector(URLSessionTask.amp_setState))
    }

    func addListener(listener: NetworkTaskListener) {
        listenerLock.withLock {
            listeners.append(listener)
        }
    }

    func removeListener(listener: NetworkTaskListener) {
        listenerLock.withLock {
            listeners.removeAll { $0 === listener }
        }
    }

    fileprivate func onTaskResume(task: URLSessionTask) {
        let listeners = listenerLock.withLock { return self.listeners }
        for listener in listeners {
            listener.onTaskResume(task)
        }
    }

    fileprivate func onTaskSetState(task: URLSessionTask, state: URLSessionTask.State) {
        let listeners = listenerLock.withLock { return self.listeners }
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
