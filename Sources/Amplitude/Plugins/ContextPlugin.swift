//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class ContextPlugin: Plugin {
    var type: PluginType = PluginType.Before
    
    var amplitude: Amplitude?
    
    func setup(amplitude: Amplitude) {
        <#code#>
    }
    
    func execute(event: BaseEvent) -> BaseEvent? {
        <#code#>
    }
}
