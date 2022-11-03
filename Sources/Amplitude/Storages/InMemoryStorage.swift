//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    func set(key: String, value: String) async {
    }

    func get(key: String) async -> String? {
        return nil
    }

    func saveEvent(event: BaseEvent) async {
    }

    func getEvents() async -> [Any]? {
        return nil
    }

    func reset() async {
    }
}
