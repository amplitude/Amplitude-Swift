//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    func write(key: StorageKey, value: Any?) async {

    }

    func read<T>(key: StorageKey) async -> T? {
        return nil
    }

    func reset() async {

    }

    func rollover() async {

    }

    func getEventsString(eventBlock: Any) async -> String? {
        return nil
    }
}
