//
//  State.swift
//  
//
//  Created by Marvin Liu on 12/10/22.
//

import Foundation

class State {
    @Atomic var userId: String? {
        didSet {
            lock.lock()
            defer { lock.unlock() }

            for plugin in plugins {
                plugin.onUserIdChanged(userId)
            }
        }
    }

    @Atomic var deviceId: String? {
        didSet {
            lock.lock()
            defer { lock.unlock() }

            for plugin in plugins {
                plugin.onDeviceIdChanged(deviceId)
            }
        }
    }

    private var plugins: [ObservePlugin] = []
    private let lock = NSLock()

    func add(plugin: ObservePlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugins.append(plugin)
    }

    func remove(plugin: ObservePlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugins.removeAll(where: { $0 === plugin })
    }
}
