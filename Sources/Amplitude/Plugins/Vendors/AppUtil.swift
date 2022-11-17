//
//  AppleUtils.swift
//
//  Created by Hao Yu on 11/16/22.
//

internal class iOSVendorSystem: VendorSystem {
    override var requiredPlugin: Plugin {
        return iOSLifecycleMonitor()
    }
}
