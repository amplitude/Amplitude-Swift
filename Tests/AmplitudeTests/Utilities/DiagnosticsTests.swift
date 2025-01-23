//
//  DiagnosticsTests.swift
//  Amplitude-SwiftTests
//
//  Created by Qingzhuo Zhen on 3/4/24.
//

import XCTest

@testable import AmplitudeSwift

final class DiagnosticsTests: XCTestCase {

    func testAddMalformedEvent() {
        let diagnostics = Diagnostics()
        diagnostics.addMalformedEvent("event")
        XCTAssertEqual(diagnostics.extractDiagnosticsToString(), "{\"malformed_events\":[\"event\"]}")
    }

    func testAddErrorLog() {
        let diagnostics = Diagnostics()
        diagnostics.addErrorLog("log")
        XCTAssertEqual(diagnostics.extractDiagnosticsToString(), "{\"error_logs\":[\"log\"]}")
    }

    func testHasDiagonostics() {
        let diagnostics = Diagnostics()
        XCTAssertNil(diagnostics.extractDiagnosticsToString())
        diagnostics.addMalformedEvent("event")
        XCTAssertNotNil(diagnostics.extractDiagnosticsToString())
        diagnostics.addErrorLog("log")
        XCTAssertNotNil(diagnostics.extractDiagnosticsToString())
    }

    func testExtractDiagnostic() {
        let diagnostics = Diagnostics()
        XCTAssertNil(diagnostics.extractDiagnosticsToString())
        diagnostics.addMalformedEvent("event")
        diagnostics.addErrorLog("log")
        let result = convertToDictionary(text: diagnostics.extractDiagnosticsToString()!)
        XCTAssertEqual((result?["malformed_events"] as? [String]) ?? [], ["event"])
        XCTAssertEqual((result?["error_logs"] as? [String]) ?? [], ["log"])
        XCTAssertNil(diagnostics.extractDiagnosticsToString())
    }

    func testDedupsErrorLogs() {
        let diagnostics = Diagnostics()
        diagnostics.addErrorLog("dup")
        diagnostics.addErrorLog("dup")
        let result = convertToDictionary(text: diagnostics.extractDiagnosticsToString()!)
        XCTAssertEqual(result?["error_logs"] as? [String], ["dup"])
    }

    func testTrimsMaxErrorLogs() {
        let maxErrorLogs = 10
        let diagnostics = Diagnostics()
        (0..<maxErrorLogs + 1).forEach {
            diagnostics.addErrorLog("\($0)")
        }
        let result = convertToDictionary(text: diagnostics.extractDiagnosticsToString()!)
        guard let errorLogs = result?["error_logs"] as? [String] else {
            XCTFail("Unable to extract error logs")
            return
        }

        XCTAssertEqual(errorLogs.count, maxErrorLogs)
        (0..<maxErrorLogs).forEach {
            XCTAssertEqual(String(describing: $0 + 1), errorLogs[$0])
        }
    }

    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
