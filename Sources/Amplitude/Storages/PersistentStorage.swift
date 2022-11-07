//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

actor PersistentStorage: Storage {
    let storagePrefix: String
    let userDefaults: UserDefaults?
    let fileManager: FileManager?

    init(storagePrefix: String = Constants.Storage.STORAGE_PREFIX) {
        self.storagePrefix = storagePrefix
        self.userDefaults = UserDefaults(suiteName: "com.amplitude.storage.\(storagePrefix)")
        self.fileManager = FileManager.default
    }

    func write(key: String, value: Any?) async {

    }

    func read(key: String) async -> Any? {
        return nil
    }

    func reset() async {

    }
}
