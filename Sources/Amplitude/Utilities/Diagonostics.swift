//
//  Diagonostics.swift
//  Amplitude-Swift
//
//  Created by Qingzhuo Zhen on 3/4/24.
//

import Foundation

public class Diagnostics {
    private var malformedEvents: [String]?
    private var errorLogs: [String]?

    init(){}

    func addMalformedEvent(_ event: String) {
        if malformedEvents == nil {
            malformedEvents = [String]()
        }
        malformedEvents?.append(event)
    }

    func addErrorLog(_ log: String) {
        if errorLogs == nil {
            errorLogs = [String]()
        }
        errorLogs?.append(log)
    }

    func hasDiagnostics() -> Bool {
        return (malformedEvents != nil && malformedEvents!.count > 0) || (errorLogs != nil && errorLogs!.count > 0)
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
        if errorLogs != nil && errorLogs!.count > 0 {
            diagnostics["error_logs"] = errorLogs
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [])
            malformedEvents?.removeAll()
            errorLogs?.removeAll()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
     }
}
