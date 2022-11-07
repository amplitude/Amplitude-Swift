//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    func write(key: String, value: Any?) async {

    }

    func read(key: String) async -> Any? {
        return nil
    }

    func reset() async {

    }
}
