//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    typealias EventBlock = Any

    func write(key: StorageKey, value: Any?) async {

    }

    func read<T>(key: StorageKey) async -> T? {
        return nil
    }

    func reset() async {

    }

    func rollover() async {

    }

    func getEventsString(eventBlock: EventBlock) async -> String? {
        return nil
    }

    func remove(eventBlock: EventBlock) async {

    }

    func splitBlock(eventBlock: EventBlock, events: [BaseEvent]) async {

    }

    func getResponseHandler(
        configuration: Configuration,
        eventPipeline: EventPipeline,
        eventBlock: EventBlock,
        eventsString: String
    ) -> ResponseHandler {
        return (Any).self as! ResponseHandler
    }
}
