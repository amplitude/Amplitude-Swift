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
            for plugin in plugins {
                plugin.onUserIdChanged(userId)
            }
        }
    }

    @Atomic var deviceId: String? {
        didSet {
            for plugin in plugins {
                plugin.onDeviceIdChanged(deviceId)
            }
        }
    }

    private var plugins: [ObservePlugin] = []

    func add(plugin: ObservePlugin) {
        plugins.append(plugin)
    }

    func remove(plugin: ObservePlugin) {
        plugins.removeAll(where: { $0 === plugin })
    }
}
