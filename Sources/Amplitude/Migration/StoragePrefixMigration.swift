import Foundation

class StoragePrefixMigration {
    let source: PersistentStorage
    let destination: PersistentStorage

    init(source: PersistentStorage, destination: PersistentStorage) {
        self.source = source
        self.destination = destination
    }

    func execute() {
        if source.storagePrefix == destination.storagePrefix {
            return
        }

        if destination.hasWrittenEvents() {
            removeSourceEventFiles()
        } else {
            moveSourceEventFilesToDestination()
        }
        moveUserDefaults()
    }

    private func moveUserDefaults() {
        if let sourceDeviceId: String = source.read(key: StorageKey.DEVICE_ID) {
            if destination.read(key: StorageKey.DEVICE_ID) == nil {
                do {
                    try destination.write(key: StorageKey.DEVICE_ID, value: sourceDeviceId)
                } catch {
                    print("can't write destination DEVICE_ID: \(error)")
                }
            }

            do {
                try source.write(key: StorageKey.DEVICE_ID, value: nil)
            } catch {
                print("can't write source DEVICE_ID: \(error)")
            }
        }

        if let sourceUserId: String = source.read(key: StorageKey.USER_ID) {
            if destination.read(key: StorageKey.USER_ID) == nil {
                do {
                    try destination.write(key: StorageKey.USER_ID, value: sourceUserId)
                } catch {
                    print("can't write destination USER_ID: \(error)")
                }
            }

            do {
                try source.write(key: StorageKey.USER_ID, value: nil)
            } catch {
                print("can't clear source USER_ID: \(error)")
            }
        }

        if let sourcePreviousSessionId: Int = source.read(key: StorageKey.PREVIOUS_SESSION_ID) {
            let destinationPreviousSessionId: Int? = destination.read(key: StorageKey.PREVIOUS_SESSION_ID)
            if destinationPreviousSessionId == nil || destinationPreviousSessionId! < sourcePreviousSessionId {
                do {
                    try destination.write(key: StorageKey.PREVIOUS_SESSION_ID, value: sourcePreviousSessionId)
                } catch {
                    print("can't write destination PREVIOUS_SESSION_ID: \(error)")
                }
            }

            do {
                try source.write(key: StorageKey.PREVIOUS_SESSION_ID, value: nil)
            } catch {
                print("can't clear source PREVIOUS_SESSION_ID: \(error)")
            }
        }

        if let sourceLastEventTime: Int = source.read(key: StorageKey.LAST_EVENT_TIME) {
            let destinationLastEventTime: Int? = destination.read(key: StorageKey.LAST_EVENT_TIME)
            if destinationLastEventTime == nil || destinationLastEventTime! < sourceLastEventTime {
                do {
                    try destination.write(key: StorageKey.LAST_EVENT_TIME, value: sourceLastEventTime)
                } catch {
                    print("can't write destination LAST_EVENT_TIME: \(error)")
                }
            }

            do {
                try source.write(key: StorageKey.LAST_EVENT_TIME, value: nil)
            } catch {
                print("can't clear source LAST_EVENT_TIME: \(error)")
            }
        }

        if let sourceLastEventId: Int = source.read(key: StorageKey.LAST_EVENT_ID) {
            let destinationLastEventId: Int? = destination.read(key: StorageKey.LAST_EVENT_ID)
            if destinationLastEventId == nil || destinationLastEventId! < sourceLastEventId {
                do {
                    try destination.write(key: StorageKey.LAST_EVENT_ID, value: sourceLastEventId)
                } catch {
                    print("can't write destination LAST_EVENT_ID: \(error)")
                }
            }

            do {
                try source.write(key: StorageKey.LAST_EVENT_ID, value: nil)
            } catch {
                print("can't clear source LAST_EVENT_ID: \(error)")
            }
        }

        if let sourceEventFileKey: Int = source.userDefaults?.integer(forKey: source.eventsFileKey) {
            let destinationEventFileKey: Int? = destination.userDefaults?.integer(forKey: destination.eventsFileKey)
            if destinationEventFileKey == nil || destinationEventFileKey! < sourceEventFileKey {
                destination.userDefaults?.set(sourceEventFileKey, forKey: destination.eventsFileKey)
            }
        }
        source.userDefaults?.removeObject(forKey: source.eventsFileKey)
    }

    private func moveSourceEventFilesToDestination() {
        let sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        if sourceEventFiles.count == 0 {
            return
        }
        // Ensure destination directory exists.
        _ = destination.getEventsStorageDirectory(createDirectory: true)

        let fileManager = FileManager.default
        for sourceEventFile in sourceEventFiles {
            let destinationEventFile = sourceEventFile.path.replacingOccurrences(of: "/\(source.eventsFileKey)/", with: "/\(destination.eventsFileKey)/")
            if !fileManager.fileExists(atPath: destinationEventFile) {
                do {
                    try fileManager.moveItem(atPath: sourceEventFile.path, toPath: destinationEventFile)
                } catch {
                    print("Can't move \(sourceEventFile) to \(destinationEventFile): \(error)")
                }
            } else {
                do {
                    try fileManager.removeItem(at: sourceEventFile)
                } catch {
                    print("Can't remove \(sourceEventFile)")
                }
            }
        }
    }

    private func removeSourceEventFiles() {
        let fileManager = FileManager.default
        let sourceEventFiles = source.getEventFiles(includeUnfinished: true)
        for sourceEventFile in sourceEventFiles {
            do {
                try fileManager.removeItem(at: sourceEventFile)
            } catch {
                print("Can't remove \(sourceEventFile)")
            }
        }
    }
}
