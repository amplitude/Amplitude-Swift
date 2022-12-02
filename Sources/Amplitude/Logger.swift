//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

public class ConsoleLogger: Logger {
    public typealias LogLevel = LogLevelEnum

    public var logLevel: Int?
    
    public init() {}
    
    public func error(message: String) {
    }

    public func warn(message: String) {
    }

    public func log(message: String) {
    }

    public func debug(message: String) {
    }
}
