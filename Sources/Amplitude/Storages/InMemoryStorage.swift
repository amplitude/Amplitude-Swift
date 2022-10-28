//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    func set(key: String, value: String) async {
        <#code#>
    }
    
    func get(key: String) async -> String? {
        <#code#>
    }
    
    func saveEvent(event: BaseEvent) async {
        <#code#>
    }
    
    func getEvents() async -> [Any]? {
        <#code#>
    }
    
    func reset() async {
        <#code#>
    }
    
}
