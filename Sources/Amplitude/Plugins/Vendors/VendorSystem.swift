//
//  VendorSystem.swift
//
//
//  Created by Hao Yu on 11/11/22.
//

internal typealias BackgroundRequestCompletionCallback = (Result<Int, Error>) -> Void

internal class VendorSystem {
    var manufacturer: String {
        return "unknown"
    }

    var model: String {
        return "unknown"
    }

    var identifierForVendor: String? {
        return nil
    }

    var os_name: String {
        return "unknown"
    }

    var os_version: String {
        return ""
    }

    var platform: String {
        return "unknown"
    }

    static var current: VendorSystem = {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            return IOSVendorSystem()
        #elseif os(macOS)
            return MacOSVendorSystem()
        #elseif os(watchOS)
            return WatchOSVendorSystem()
        #else
            return VendorSystem()
        #endif
    }()

    var requiredPlugin: Plugin? {
        return nil
    }
  
    func beginBackgroundRequest() -> BackgroundRequestCompletionCallback? {
        return nil
    }
}
