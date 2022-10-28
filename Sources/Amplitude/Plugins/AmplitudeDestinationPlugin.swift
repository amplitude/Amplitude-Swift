//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class AmplitudeDestinationPlugin: Plugin {
    public var type: PluginType = PluginType.Destination
    
    public var amplitude: Amplitude?
    
    public func setup(amplitude: Amplitude) {
        <#code#>
    }
    
    public func execute(event: BaseEvent) -> BaseEvent? {
        <#code#>
    }
}
