//
//  AppleUtils.swift
//
//  Created by Hao Yu on 11/16/22.
//

import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    import SystemConfiguration
    import UIKit
    #if !os(tvOS)
        import WebKit
    #endif

    internal class IOSVendorSystem: VendorSystem {
        private let device = UIDevice.current
        override var manufacturer: String {
            return "Apple"
        }

        override var model: String {
            return deviceModel()
        }

        override var identifierForVendor: String? {
            return device.identifierForVendor?.uuidString
        }

        override var os_name: String {
            return device.systemName
        }

        override var os_version: String {
            return device.systemVersion
        }

        override var platform: String {
            var name: [Int32] = [CTL_HW, HW_MACHINE]
            var size: Int = 2
            sysctl(&name, 2, nil, &size, nil, 0)
            var hw_machine = [CChar](repeating: 0, count: Int(size))
            sysctl(&name, 2, &hw_machine, &size, nil, 0)
            let platform = String(cString: hw_machine)
            return platform
        }

        private func deviceModel() -> String {
            let platform = self.platform
            return getDeviceModel(platform: platform)
        }

        override var requiredPlugin: Plugin {
            return IOSLifecycleMonitor()
        }
    }
#endif

#if os(macOS)

    import Cocoa
    import WebKit

    internal class MacOSVendorSystem: VendorSystem {
        private let device = ProcessInfo.processInfo

        override var manufacturer: String {
            return "Apple"
        }

        override var model: String {
            return deviceModel()
        }

        override var identifierForVendor: String? {
            // apple suggested to use this for receipt validation
            // in MAS, works for this too.
            return macAddress(bsd: "en0")
        }

        override var os_name: String {
            return "macOS"
        }

        override var os_version: String {
            return String(format: "%ld.%ld.%ld",
                          device.operatingSystemVersion.majorVersion,
                          device.operatingSystemVersion.minorVersion,
                          device.operatingSystemVersion.patchVersion)
        }

        override var requiredPlugin: Plugin {
            return MacOSLifecycleMonitor()
        }

        override var platform: String {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            return identifier
        }

        private func deviceModel() -> String {
            let platform = self.platform
            return getDeviceModel(platform: platform)
        }

        private func macAddress(bsd : String) -> String? {
            let MAC_ADDRESS_LENGTH = 6
            let separator = ":"

            var length : size_t = 0
            var buffer : [CChar]

            let bsdIndex = Int32(if_nametoindex(bsd))
            if bsdIndex == 0 {
                return nil
            }
            let bsdData = Data(bsd.utf8)
            var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]

            if sysctl(&managementInfoBase, 6, nil, &length, nil, 0) < 0 {
                return nil;
            }

            buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: {buffer, initializedCount in
                for x in 0..<length { buffer[x] = 0 }
                initializedCount = length
            })

            if sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) < 0 {
                return nil;
            }

            let infoData = Data(bytes: buffer, count: length)
            let indexAfterMsghdr = MemoryLayout<if_msghdr>.stride + 1
            let rangeOfToken = infoData[indexAfterMsghdr...].range(of: bsdData)!
            let lower = rangeOfToken.upperBound
            let upper = lower + MAC_ADDRESS_LENGTH
            let macAddressData = infoData[lower..<upper]
            let addressBytes = macAddressData.map { String(format:"%02x", $0) }
            return addressBytes.joined(separator: separator)
        }
    }
#endif

#if os(watchOS)
    import WatchKit

    internal class WatchOSVendorSystem: VendorSystem {
        private let device = WKInterfaceDevice.V()

        override var manufacturer: String {
            return "Apple"
        }

        override var model: String {
            return deviceModel()
        }

        override var identifierForVendor: String? {
            // apple suggested to use this for receipt validation
            // in MAS, works for this too.
            return device.identifierForVendor?.uuidString
        }

        override var os_name: String {
            return device.systemName
        }

        override var os_version: String {
            return device.systemVersion
        }

        override var platform: String {
            var name: [Int32] = [CTL_HW, HW_MACHINE]
            var size: Int = 2
            sysctl(&name, 2, nil, &size, nil, 0)
            var hw_machine = [CChar](repeating: 0, count: Int(size))
            sysctl(&name, 2, &hw_machine, &size, nil, 0)
            let platform = String(cString: hw_machine)
            return platform
        }

        private func deviceModel() -> String {
            let platform = self.platform
            getDeviceModel(platform: platform)
        }

        override var requiredPlugin: Plugin {
            return WatchOSLifecycleMonitor()
        }
    }
#endif

private func getDeviceModel(platform: String) -> String {
    // use server device mapping except for the following exceptions

    if platform == "i386" || platform == "x86_64" {
        return "Simulator"
    }

    if platform.hasPrefix("MacBookAir") {
        return "MacBook Air"
    }

    if platform.hasPrefix("MacBookPro") {
        return "MacBook Pro"
    }

    if platform.hasPrefix("MacBook") {
        return "MacBook"
    }

    if platform.hasPrefix("MacPro") {
        return "Mac Pro"
    }

    if platform.hasPrefix("Macmini") {
        return "Mac Mini"
    }

    if platform.hasPrefix("iMac") {
        return "iMac"
    }

    if platform.hasPrefix("Xserve") {
        return "Xserve"
    }

    return platform
}
