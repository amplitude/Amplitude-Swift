//
//  VendorSystem.swift
//
//
//  Created by Hao Yu on 11/11/22.
//

internal typealias BackgroundTaskCompletionCallback = () -> Void

internal class VendorSystem {
    // Placeholder Apple returns instead of a real MAC address (iOS 7+, macOS 27+).
    // Lives on the base class because ContextPlugin's cross-platform invalid-id set uses it too.
    static let redactedMacAddress = "02:00:00:00:00:00"

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
        #if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
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

    var networkConnectivityCheckingEnabled: Bool {
        return true
    }

    func beginBackgroundTask() -> BackgroundTaskCompletionCallback? {
        return nil
    }
}
