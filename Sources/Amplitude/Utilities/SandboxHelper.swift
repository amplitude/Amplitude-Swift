//
//  SandboxHelper.swift
//  Amplitude-Swift
//
//  Created by Justin Fiedler on 2/1/24.
//

import Foundation

public class SandboxHelper {
    static public func isSandboxEnabled() -> Bool {
        #if os(macOS)
            // Check if macOS app has "App Sandbox" enabled
            let environment = ProcessInfo.processInfo.environment
            return environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #else
            // Other platforms (iOS, tvOS, watchOs) are sandboxed by default
            return true
        #endif
    }
}
