//
//  Diagonostics.swift
//  Amplitude-Swift
//
//  Created by Qingzhuo Zhen on 3/4/24.
//

import Foundation

public class Diagnostics {

    private static let MAX_ERROR_LOGS = 10

    private var malformedEvents: [String]?
    private var errorLogs = NSMutableOrderedSet(capacity: 10)

    init(){}

    func addMalformedEvent(_ event: String) {
        if malformedEvents == nil {
            malformedEvents = [String]()
        }
        malformedEvents?.append(event)
    }

    func addErrorLog(_ log: String) {
        errorLogs.add(log)

        // trim to MAX_ERROR_LOGS elements
        while errorLogs.count > Self.MAX_ERROR_LOGS {
            errorLogs.removeObject(at: 0)
        }
    }

    func hasDiagnostics() -> Bool {
        return (malformedEvents != nil && malformedEvents!.count > 0) || errorLogs.count > 0
    }

    /**
     * Extracts the diagnostics as a JSON string.
     * Warning: This will clear stored diagnostics.
     * @return JSON string of diagnostics or empty if no diagnostics are present.
     */
     func extractDiagonosticsToString() -> String {
        if !hasDiagnostics() {
            return ""
        }
        var diagnostics = [String: [String]]()
        if malformedEvents != nil && malformedEvents!.count > 0 {
            diagnostics["malformed_events"] = malformedEvents
        }
         if errorLogs.count > 0, let errorStrings = errorLogs.array as? [String] {
             diagnostics["error_logs"] = errorStrings
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [])
            malformedEvents?.removeAll()
            errorLogs.removeAllObjects()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
     }
}
