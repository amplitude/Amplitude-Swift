//
//  File.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class InMemoryStorage: Storage {
    func write(key: StorageKey, value: Any?) async {

    }

    func read<T>(key: StorageKey) async -> T? {
        return nil
    }

    func reset() async {

    }
}

extension InMemoryStorage {
    enum StorageKey: String, CaseIterable {
        case LAST_EVENT_ID = "last_event_id"
        case PREVIOUS_SESSION_ID = "previous_session_id"
        case LAST_EVENT_TIME = "last_event_time"
        case OPT_OUT = "opt_out"
        case EVENTS = "events"
    }
}
