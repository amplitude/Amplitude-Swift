//
//  InteractionsOptions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

import Foundation

@_spi(Frustration)
public class InteractionsOptions {
    public let rageClick: RageClickOptions
    public let deadClick: DeadClickOptions

    public init(rageClick: RageClickOptions = RageClickOptions(), deadClick: DeadClickOptions = DeadClickOptions()) {
        self.rageClick = rageClick
        self.deadClick = deadClick
    }
}

@_spi(Frustration)
public struct RageClickOptions {
    public let enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }
}

@_spi(Frustration)
public struct DeadClickOptions {
    public let enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }
}
