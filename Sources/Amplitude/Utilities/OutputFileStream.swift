//
//  OutputFileStream.swift
//
//
//  Created by Marvin Liu on 11/22/22.
//
//  Originally from Segment: https://github.com/segmentio/analytics-swift, under MIT license.
//  Use C library file operations to avoid Swift API deprecation and related bugs.

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

internal class OutputFileStream {
    enum OutputStreamError: Error {
        case invalidPath(String)
        case unableToOpen(String)
        case unableToWrite(String)
        case unableToCreate(String)
    }

    var filePointer: UnsafeMutablePointer<FILE>?
    let fileURL: URL

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        let path = fileURL.path
        guard path.isEmpty == false else { throw OutputStreamError.invalidPath(path) }
    }

    func create() throws {
        let path = fileURL.path
        if FileManager.default.fileExists(atPath: path) {
            throw OutputStreamError.unableToCreate(path)
        } else {
            let created = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            if created == false {
                throw OutputStreamError.unableToCreate(path)
            } else {
                try open()
            }
        }
    }

    func open() throws {
        if filePointer != nil { return }
        let path = fileURL.path
        path.withCString { file in
            filePointer = fopen(file, "w")
        }
        guard filePointer != nil else { throw OutputStreamError.unableToOpen(path) }
    }

    func write(_ data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else { return }
        try write(string)
    }

    func write(_ string: String) throws {
        guard string.isEmpty == false else { return }
        _ = try string.utf8.withContiguousStorageIfAvailable { str in
            if let baseAddr = str.baseAddress {
                fwrite(baseAddr, 1, str.count, filePointer)
            } else {
                throw OutputStreamError.unableToWrite(fileURL.path)
            }
            if ferror(filePointer) != 0 {
                throw OutputStreamError.unableToWrite(fileURL.path)
            }
        }
    }

    func close() {
        fclose(filePointer)
        filePointer = nil
    }
}
