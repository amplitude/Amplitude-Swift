//
//  AppleUtils.swift
//
//  Created by Hao Yu on 11/16/22.
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    internal class IOSVendorSystem: VendorSystem {
        override var requiredPlugin: Plugin {
            return IOSLifecycleMonitor()
        }
    }
#endif

#if os(watchOS)
    internal class MacOSVendorSystem: VendorSystem {
        override var requiredPlugin: Plugin {
            return MacOSLifecycleMonitor()
        }
    }
#endif

#if os(watchOS)
    internal class WatchOSVendorSystem: VendorSystem {
        override var requiredPlugin: Plugin {
            return WatchOSLifecycleMonitor()
        }
    }
#endif
