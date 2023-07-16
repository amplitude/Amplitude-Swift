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

        let hasDestinationWrittenEvents = destination.hasWrittenEvents()

        moveUserDefaults()
        if !hasDestinationWrittenEvents {
            moveEventFiles()
        } else {
            removeEventFiles()
        }
    }

    private func moveUserDefaults() {
        if let sourceUserDefaults = source.userDefaults?.dictionaryRepresentation(),
           let destinationUserDefaults = destination.userDefaults {
            for entry in sourceUserDefaults {
                if destinationUserDefaults.object(forKey: entry.key) == nil {
                    destinationUserDefaults.set(entry.value, forKey: entry.key)
                }
                source.userDefaults?.removeObject(forKey: entry.key)
            }
        }
    }

    private func moveEventFiles() {
        let fileManager = FileManager.default
        let sourceEventFiles = source.getEventFiles(includeUnfinished: true)
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

    private func removeEventFiles() {
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
