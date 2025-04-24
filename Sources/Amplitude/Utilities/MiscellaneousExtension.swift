//
//  MiscellaneousExtension.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 3/18/25.
//

import Foundation

extension Date {
    func amp_timestamp() -> Int64 {
        return Int64(NSDate().timeIntervalSince1970 * 1000)
    }
}
