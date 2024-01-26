//
//  NetworkConnectivityCheckerPlugin.swift
//  Amplitude-Swift
//
//  Created by Xinyi.Ye on 1/26/24.
//

import Foundation
import Network

open class NetworkConnectivityCheckerPlugin: BeforePlugin {
    public static let Disabled: Bool? = nil
    let monitor = NWPathMonitor()


    open override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        self.amplitude?.logger?.debug(message: "Installing AndroidNetworkConnectivityPlugin, offline feature should be supported.")

        // Define handler for network changes
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                self.amplitude?.logger?.debug(message: "Network connectivity changed to online.")
                self.amplitude?.configuration.offline = false
            } else {
                self.amplitude?.logger?.debug(message: "Network connectivity changed to offline.")
                self.amplitude?.configuration.offline = true
            }
        }

        // Start network monitor
        let queue = DispatchQueue(label: "networkConnectivityChecker.amplitude.com")
        monitor.start(queue: queue)
    }

    open override func teardown() {
        monitor.cancel()
    }

}
