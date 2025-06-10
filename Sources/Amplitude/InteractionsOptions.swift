//
//  InteractionsOptions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

import Foundation

public class InteractionsOptions {
    public var rageClick: RageClickOptions
    
    public init(rageClick: RageClickOptions = RageClickOptions()) {
        self.rageClick = rageClick
    }
}

public class RageClickOptions {
    /// Number of clicks to trigger rage click (3 or more)
    public var threshold: Int
    /// Maximum time to wait for any response, measure in milliseconds (1000 or more)
    public var timeout: Int
    
    public init(threshold: Int = 3, timeout: Int = 1000) {
        self.threshold = max(3, threshold)
        self.timeout = max(1000, timeout)
    }
} 