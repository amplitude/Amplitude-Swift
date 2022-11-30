//
//  PersistentStorage.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

actor PersistentStorage: Storage {
    let storagePrefix: String
    let userDefaults: UserDefaults?
    let fileManager: FileManager?
    private var outputStream: OutputFileStream?
    internal weak var amplitude: Amplitude?

    init(apiKey: String = "") {
        self.storagePrefix = "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-\(apiKey)"
        self.userDefaults = UserDefaults(suiteName: "\(PersistentStorage.AMP_STORAGE_PREFIX).\(storagePrefix)")
        self.fileManager = FileManager.default
    }

    func write(key: StorageKey, value: Any?) async throws {
        switch key {
        case .EVENTS:
            if let event = value as? BaseEvent {
                let eventStoreFile = getCurrentFile()
                self.storeEvent(toFile: eventStoreFile, event: event)
            }
        default:
            if isBasicType(value: value) {
                userDefaults?.set(value, forKey: key.rawValue)
            } else {
                throw Exception.unsupportedType
            }
        }
    }

    func read<T>(key: StorageKey) async -> T? {
        var result: T?
        switch key {
        case .EVENTS:
            result = getEventFiles() as? T
        default:
            result = userDefaults?.object(forKey: key.rawValue) as? T
        }
        return result
    }

    func getEventsString(eventBlock: Any) async -> String? {
        var content: String?
        guard let eventBlock = eventBlock as? URL else { return content }
        do {
            content = try String(contentsOf: eventBlock, encoding: .utf8)
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
        return content
    }

    func reset() async {
        let urls = getEventFiles(includeUnfinished: true)
        let keys = userDefaults?.dictionaryRepresentation().keys
        keys?.forEach { key in
            userDefaults?.removeObject(forKey: key)
        }
        for url in urls {
            try? fileManager!.removeItem(atPath: url.path)
        }
    }

    func rollover() async {
        let currentFile = getCurrentFile()
        if fileManager?.fileExists(atPath: currentFile.path) == false {
            return
        }
        if let attributes = try? fileManager?.attributesOfItem(atPath: currentFile.path),
            let fileSize = attributes[FileAttributeKey.size] as? UInt64,
            fileSize >= 0
        {
            finish(file: currentFile)
        }
    }

    func isBasicType(value: Any?) -> Bool {
        var result = false
        if value == nil {
            result = true
        } else {
            switch value {
            case is NSNull, is Int, is Float, is Double, is Decimal, is NSNumber, is Bool, is String, is NSString:
                result = true
            default:
                break
            }
        }
        return result
    }
}

extension PersistentStorage {
    static let DEFAULT_STORAGE_PREFIX = "amplitude-swift"
    static let AMP_STORAGE_PREFIX = "com.amplitude.storage"
    static let MAX_FILE_SIZE = 975000  // 975KB
    static let TEMP_FILE_EXTENSION = "tmp"

    enum Exception: Error {
        case unsupportedType
    }
}

extension PersistentStorage {
    private var eventsFileKey: String {
        return "\(storagePrefix).\(StorageKey.EVENTS.rawValue).index"
    }

    private func getCurrentFile() -> URL {
        var currentFileIndex = 0
        let index: Int = userDefaults?.integer(forKey: eventsFileKey) ?? 0
        userDefaults?.set(index, forKey: eventsFileKey)
        currentFileIndex = index
        return getEventsFile(index: currentFileIndex)
    }

    private func getEventsFile(index: Int) -> URL {
        let dir = getEventsStorageDirectory()
        let fileURL = dir.appendingPathComponent("\(index)").appendingPathExtension(
            PersistentStorage.TEMP_FILE_EXTENSION
        )
        return fileURL
    }

    private func getEventFiles(includeUnfinished: Bool = false) -> [URL] {
        var result = [URL]()

        // finish out any file in progress
        let index = userDefaults?.integer(forKey: eventsFileKey) ?? 0
        finish(file: getEventsFile(index: index))

        let allFiles = try? fileManager!.contentsOfDirectory(
            at: getEventsStorageDirectory(),
            includingPropertiesForKeys: [],
            options: .skipsHiddenFiles
        )
        var files = allFiles
        if includeUnfinished == false {
            files = allFiles?.filter { (file) -> Bool in
                return file.pathExtension != PersistentStorage.TEMP_FILE_EXTENSION
            }
        }
        let sorted = files?.sorted { (left, right) -> Bool in
            return left.lastPathComponent > right.lastPathComponent
        }
        if let s = sorted {
            result = s
        }
        return result
    }

    private func getEventsStorageDirectory() -> URL {
        // tvOS doesn't have access to document
        // macOS /Documents dir might be synced with iCloud
        #if os(tvOS) || os(macOS)
            let searchPathDirectory = FileManager.SearchPathDirectory.cachesDirectory
        #else
            let searchPathDirectory = FileManager.SearchPathDirectory.documentDirectory
        #endif

        let urls = fileManager!.urls(for: searchPathDirectory, in: .userDomainMask)
        let docUrl = urls[0]
        let storageUrl = docUrl.appendingPathComponent("amplitude/\(eventsFileKey)/")
        // try to create it, will fail if already exists.
        // tvOS, watchOS regularly clear out data.
        try? FileManager.default.createDirectory(at: storageUrl, withIntermediateDirectories: true, attributes: nil)
        return storageUrl
    }

    private func storeEvent(toFile file: URL, event: BaseEvent) {
        var storeFile = file

        var newFile = false
        if fileManager?.fileExists(atPath: storeFile.path) == false {
            start(file: storeFile)
            newFile = true
        } else if outputStream == nil {
            // this can happen if an instance was terminated before finishing a file.
            open(file: storeFile)
        }

        // Verify file size isn't too large
        if let attributes = try? fileManager?.attributesOfItem(atPath: storeFile.path),
            let fileSize = attributes[FileAttributeKey.size] as? UInt64,
            fileSize >= PersistentStorage.MAX_FILE_SIZE
        {
            finish(file: storeFile)
            // Set the new file path
            storeFile = getCurrentFile()
            start(file: storeFile)
            newFile = true
        }

        let jsonString = event.toString()
        do {
            if outputStream == nil {
                amplitude?.logger?.error(message: "OutputStream is nil with file: \(storeFile)")
            }
            if newFile == false {
                // prepare for the next entry
                try outputStream?.write(",")
            }
            try outputStream?.write(jsonString)
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
    }

    private func start(file: URL) {
        let contents = "["
        do {
            outputStream = try OutputFileStream(fileURL: file)
            try outputStream?.create()
            try outputStream?.write(contents)
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
    }

    private func open(file: URL) {
        if outputStream == nil {
            // this can happen if an instance was terminated before finishing a file.
            do {
                outputStream = try OutputFileStream(fileURL: file)
                if let outputStream = outputStream {
                    try outputStream.open()
                }
            } catch {
                amplitude?.logger?.error(message: error.localizedDescription)
            }
        }
    }

    private func finish(file: URL) {
        guard let outputStream = self.outputStream else {
            return
        }

        let fileEnding = "]"
        do {
            try outputStream.write(fileEnding)
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
        outputStream.close()
        self.outputStream = nil

        let fileWithoutTemp = file.deletingPathExtension()
        do {
            try fileManager?.moveItem(at: file, to: fileWithoutTemp)
        } catch {
            amplitude?.logger?.error(message: "Unable to rename file: \(file.path)")
        }

        let currentFileIndex: Int = (userDefaults?.integer(forKey: eventsFileKey) ?? 0) + 1
        userDefaults?.set(currentFileIndex, forKey: eventsFileKey)
    }
}
