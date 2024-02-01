//
//  SandboxHelper.swift
//  Amplitude-Swift
//
//  Created by Justin Fiedler on 2/1/24.
//

import Foundation

public class SandboxHelper {
    static public func isSandboxEnabled() -> Bool {
        #if os(iOS)
            // iOS is always sandboxed
            return true
        #else
            // this works on macOS (not iOS), need to test on tvOS
            let environment = ProcessInfo.processInfo.environment
            return environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #endif
    }
}
