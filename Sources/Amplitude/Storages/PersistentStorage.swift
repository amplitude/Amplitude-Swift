//
//  PersistentStorage.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class PersistentStorage: Storage {
    typealias EventBlock = URL

    static internal func getEventStoragePrefix(_ apiKey: String, _ instanceName: String) -> String {
        return "storage-\(apiKey)-\(instanceName)"
    }

    static internal func getIdentifyStoragePrefix(_ apiKey: String, _ instanceName: String) -> String {
        return "identify-\(apiKey)-\(instanceName)"
    }

    let storagePrefix: String
    let userDefaults: UserDefaults?
    let fileManager: FileManager
    private var outputStream: OutputFileStream?
    internal weak var amplitude: Amplitude?
    // Store event.callback in memory as it cannot be ser/deser in files.
    private var eventCallbackMap: [String: EventCallback]
    private var appPath: String!
    let syncQueue = DispatchQueue(label: "syncPersistentStorage.amplitude.com")

    init(storagePrefix: String) {
        self.storagePrefix = storagePrefix == PersistentStorage.DEFAULT_STORAGE_PREFIX || storagePrefix.starts(with: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-")
            ? storagePrefix
            : "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-\(storagePrefix)"
        self.userDefaults = UserDefaults(suiteName: "\(PersistentStorage.AMP_STORAGE_PREFIX).\(self.storagePrefix)")
        self.fileManager = FileManager.default
        self.eventCallbackMap = [String: EventCallback]()
        // Make sure Amplitude data is sandboxed per app
        self.appPath = isStorageSandboxed() ? "" : "\(Bundle.main.bundleIdentifier!)/"
        handleV1Files()
    }

    func write(key: StorageKey, value: Any?) throws {
        try syncQueue.sync {
            switch key {
            case .EVENTS:
                if let event = value as? BaseEvent {
                    let eventStoreFile = getCurrentEventFile()
                    self.storeEvent(toFile: eventStoreFile, event: event)
                    if let eventCallback = event.callback, let eventInsertId = event.insertId {
                        eventCallbackMap[eventInsertId] = eventCallback
                    }
                }
            default:
                if isBasicType(value: value) {
                    userDefaults?.set(value, forKey: key.rawValue)
                } else {
                    throw Exception.unsupportedType
                }
            }
        }
    }

    func read<T>(key: StorageKey) -> T? {
        syncQueue.sync {
            var result: T?
            switch key {
            case .EVENTS:
                result = getEventFiles() as? T
            default:
                result = userDefaults?.object(forKey: key.rawValue) as? T
            }
            return result
        }
    }

    func getEventsString(eventBlock: EventBlock) -> String? {
        var content: String?
        do {
            content = try String(contentsOf: eventBlock, encoding: .utf8)
            if (content?.hasSuffix(PersistentStorage.DELMITER) == true) {
                // v2 file
                return readV2File(content: content!)
            } else {
                // handle v1 file
                return readV1File(content: content!)
            }
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
        return content
    }

    func remove(eventBlock: EventBlock) {
        syncQueue.sync {
            do {
                try fileManager.removeItem(atPath: eventBlock.path)
            } catch {
                amplitude?.logger?.error(message: error.localizedDescription)
            }
        }
    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) {
        syncQueue.sync {
            let total = events.count
            let half = total / 2
            let leftSplit = Array(events[0..<half])
            let rightSplit = Array(events[half..<total])
            storeEventsInNewFile(toFile: eventBlock.appendFileNameSuffix(suffix: "-1"), events: leftSplit)
            storeEventsInNewFile(toFile: eventBlock.appendFileNameSuffix(suffix: "-2"), events: rightSplit)
            do {
                try fileManager.removeItem(atPath: eventBlock.path)
            } catch {
                amplitude?.logger?.error(message: error.localizedDescription)
            }
        }
    }

    func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: EventBlock,
        eventsString: String
    ) -> ResponseHandler {
        return PersistentStorageResponseHandler(
            configuration: configuration,
            storage: self,
            eventPipeline: eventPipeline,
            eventBlock: eventBlock,
            eventsString: eventsString
        )
    }

    func reset() {
        syncQueue.sync {
            let urls = getEventFiles(includeUnfinished: true)
            let keys = userDefaults?.dictionaryRepresentation().keys
            keys?.forEach { key in
                userDefaults?.removeObject(forKey: key)
            }
            for url in urls {
                try? fileManager.removeItem(atPath: url.path)
            }
        }
    }

    func rollover() {
        syncQueue.sync {
            if getCurrentEventFileIndex() == nil {
                return
            }
            let currentFile = getCurrentEventFile()
            if fileManager.fileExists(atPath: currentFile.path) == false {
                return
            }
            if let attributes = try? fileManager.attributesOfItem(atPath: currentFile.path),
                let fileSize = attributes[FileAttributeKey.size] as? UInt64,
                fileSize >= 0
            {
                finish(file: currentFile)
            }
        }
    }

    func getEventCallback(insertId: String) -> EventCallback? {
        return eventCallbackMap[insertId]
    }

    func removeEventCallback(insertId: String) {
        eventCallbackMap.removeValue(forKey: insertId)
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

    internal func isStorageSandboxed() -> Bool {
        return SandboxHelper().isSandboxEnabled()
    }
}

extension PersistentStorage {
    static let DEFAULT_STORAGE_PREFIX = "amplitude-swift"
    static let AMP_STORAGE_PREFIX = "com.amplitude.storage"
    static let MAX_FILE_SIZE = 975000  // 975KB
    static let TEMP_FILE_EXTENSION = "tmp"
    static let DELMITER = "\u{0000}"

    enum Exception: Error {
        case unsupportedType
    }
}

extension PersistentStorage {
    internal var eventsFileKey: String {
        return "\(storagePrefix).\(StorageKey.EVENTS.rawValue).index"
    }

    private func getCurrentEventFile() -> URL {
        var currentFileIndex = 0
        let index: Int = getCurrentEventFileIndex() ?? 0
        userDefaults?.set(index, forKey: eventsFileKey)
        currentFileIndex = index
        return getEventsFile(index: currentFileIndex)
    }

    private func getCurrentEventFileIndex() -> Int? {
        return userDefaults?.object(forKey: eventsFileKey) as? Int
    }

    private func getEventsFile(index: Int) -> URL {
        let dir = getEventsStorageDirectory()
        let fileURL = dir.appendingPathComponent("\(index)").appendingPathExtension(
            PersistentStorage.TEMP_FILE_EXTENSION
        )
        return fileURL
    }

    internal func getEventFiles(includeUnfinished: Bool = false) -> [URL] {
        var result = [URL]()

        let eventsStorageDirectory = getEventsStorageDirectory(createDirectory: false)
        if !fileManager.fileExists(atPath: eventsStorageDirectory.path) {
            return result
        }

        // finish out any file in progress
        let index = getCurrentEventFileIndex() ?? 0
        finish(file: getEventsFile(index: index))

        let allFiles = try? fileManager.contentsOfDirectory(
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

    internal func getEventsStorageDirectory(createDirectory: Bool = true) -> URL {
        // TODO: Update to use applicationSupportDirectory for all platforms (this will require a migration)
        // let searchPathDirectory = FileManager.SearchPathDirectory.applicationSupportDirectory
        // tvOS doesn't have access to document
        // macOS /Documents dir might be synced with iCloud
        #if os(tvOS) || os(macOS)
            let searchPathDirectory = FileManager.SearchPathDirectory.cachesDirectory
        #else
            let searchPathDirectory = FileManager.SearchPathDirectory.documentDirectory
        #endif

        let urls = fileManager.urls(for: searchPathDirectory, in: .userDomainMask)
        let docUrl = urls[0]
        let storageUrl = docUrl.appendingPathComponent("amplitude/\(appPath ?? "")\(eventsFileKey)/")
        if createDirectory {
            // try to create it, will fail if already exists.
            // tvOS, watchOS regularly clear out data.
            try? FileManager.default.createDirectory(at: storageUrl, withIntermediateDirectories: true, attributes: nil)
        }
        return storageUrl
    }

    private func storeEvent(toFile file: URL, event: BaseEvent) {
        var storeFile = file

        if fileManager.fileExists(atPath: storeFile.path) == false || outputStream == nil {
            // this can happen if an instance was terminated before finishing a file.
            open(file: storeFile)
        }

        // Verify file size isn't too large
        if let attributes = try? fileManager.attributesOfItem(atPath: storeFile.path),
            let fileSize = attributes[FileAttributeKey.size] as? UInt64,
            fileSize >= PersistentStorage.MAX_FILE_SIZE
        {
            finish(file: storeFile)
            // Set the new file path
            storeFile = getCurrentEventFile()
        }

        let jsonString = event.toString().replacingOccurrences(of: PersistentStorage.DELMITER, with: "")
        do {
            if outputStream == nil {
                amplitude?.logger?.error(message: "OutputStream is nil with file: \(storeFile)")
            }
            try outputStream?.write("\(jsonString)\(PersistentStorage.DELMITER)")
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
    }

    private func storeEventsInNewFile(toFile file: URL, events: [BaseEvent]) {
        let storeFile = file

        guard fileManager.fileExists(atPath: storeFile.path) != true else {
            return
        }

        let jsonString = events.map { $0.toString().replacingOccurrences(of: PersistentStorage.DELMITER, with: "")  }.joined(separator: PersistentStorage.DELMITER)
        do {
            if outputStream == nil {
                amplitude?.logger?.error(message: "OutputStream is nil with file: \(storeFile)")
            }
            try outputStream?.write("\(jsonString)\(PersistentStorage.DELMITER)")
        } catch {
            amplitude?.logger?.error(message: error.localizedDescription)
        }
        finish(file: storeFile)
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
        let fileWithoutTemp = file.deletingPathExtension()
        do {
            try fileManager.moveItem(at: file, to: fileWithoutTemp)
        } catch {
            amplitude?.logger?.error(message: "Unable to rename file: \(file.path)")
        }

        let currentFileIndex: Int = (getCurrentEventFileIndex() ?? 0) + 1
        userDefaults?.set(currentFileIndex, forKey: eventsFileKey)
    }

    private func handleV1Files() {
        syncQueue.sync {
            let allFiles = self.getEventFiles(includeUnfinished: true)
            for file in allFiles {
                do {
                    var content = try String(contentsOf: file, encoding: .utf8)
                    if (content.hasSuffix(PersistentStorage.DELMITER)) {
                        break // already handled and in v2 format
                    }
                    
                    let normalizedContent = "[\(content.trimmingCharacters(in: ["[", ",", "]"]))]"
                    let events = BaseEvent.fromArrayString(jsonString: normalizedContent)
                    if (events != nil) {
                        storeEventsInNewFile(toFile: file, events: events!)
                    }
                    if (file.pathExtension != "") {
                        finish(file: file)
                    }
                } catch(let error) {
                    amplitude?.diagonostics.addErrorLog("Error migrating file: \(file.path) for \(error.localizedDescription)")
                    amplitude?.logger?.error(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func readV2File(content: String) -> String {
        var events: [BaseEvent] = [BaseEvent]()
        if (content.hasSuffix(PersistentStorage.DELMITER)) {
            content.components(separatedBy: PersistentStorage.DELMITER).forEach{
                if let event = BaseEvent.fromString(jsonString: String($0)) {
                    events.append(event)
                }
            }
        }
        return BaseEvent.toJSONString(events: events)
    }
    
    private func readV1File(content: String) -> String {
        var result = ""
        do {
            let normalizedContent = "[\(content.trimmingCharacters(in: ["[", ",", "]"]))]"
            let events = BaseEvent.fromArrayString(jsonString: normalizedContent)
            if (events != nil) {
                result = normalizedContent;
            }
        } catch {
            amplitude?.diagonostics.addMalformedEvent(content);
            amplitude?.logger?.error(message: error.localizedDescription)
        }
        return result
    }
}
