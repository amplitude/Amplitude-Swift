//
//  FilterPlugin.swift
//  AmplitudeSwiftUIExample
//
//  Created by Alyssa.Yu on 2/22/24.
//

import Foundation
import AmplitudeSwift

class FilterPlugin: EnrichmentPlugin {
    public override func execute(event: BaseEvent) -> BaseEvent? {
        guard event.eventType != "Filtered Event" else {
            return nil
        }
        return event
    }
}
