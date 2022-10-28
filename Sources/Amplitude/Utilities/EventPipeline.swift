//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class EventPipeline {
    var amplitude: Amplitude
    var httpClient: HttpClient = HttpClient()
    
    init(amplitude: Amplitude) {
        self.amplitude = amplitude
    }
    
    func put(event: BaseEvent) {
    }
    
    func flush() {
    }
    
    func start() {
    }
    
    func stop() {
    }
}
