//
//  VendorSystem.swift
//
//
//  Created by Hao Yu on 11/11/22.
//

internal class VendorSystem {
    static var current: VendorSystem = {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            return IOSVendorSystem()
        #elseif os(macOS)
            return MacOSVendorSystem()
        #elseif os(watchOS)
            return WatchOSVendorSystem()
        #elseif os(Linux)
            return LinuxVendorSystem()
        #else
            return VendorSystem()
        #endif
    }()

    var requiredPlugin: Plugin? {
        return nil
    }
}
