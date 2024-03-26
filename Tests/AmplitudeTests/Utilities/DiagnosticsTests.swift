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
        XCTAssertTrue(diagnostics.hasDiagnostics())
        XCTAssertEqual(diagnostics.extractDiagonosticsToString(), "{\"malformed_events\":[\"event\"]}")
    }

    func testAddErrorLog() {
        let diagnostics = Diagnostics()
        diagnostics.addErrorLog("log")
        XCTAssertTrue(diagnostics.hasDiagnostics())
        XCTAssertEqual(diagnostics.extractDiagonosticsToString(), "{\"error_logs\":[\"log\"]}")
    }

    func testHasDiagonostics() {
        let diagnostics = Diagnostics()
        XCTAssertFalse(diagnostics.hasDiagnostics())
        diagnostics.addMalformedEvent("event")
        XCTAssertTrue(diagnostics.hasDiagnostics())
        diagnostics.addErrorLog("log")
        XCTAssertTrue(diagnostics.hasDiagnostics())
    }

    func testExtractDiagnostic() {
        let diagnostics = Diagnostics()
        XCTAssertEqual(diagnostics.extractDiagonosticsToString(), "")
        diagnostics.addMalformedEvent("event")
        diagnostics.addErrorLog("log")
        let result = convertToDictionary(text: diagnostics.extractDiagonosticsToString())
        XCTAssertEqual((result?["malformed_events"] as? [String]) ?? [], ["event"])
        XCTAssertEqual((result?["error_logs"] as? [String]) ?? [], ["log"])
    }

    func testDedupsErrorLogs() {
        let diagnostics = Diagnostics()
        diagnostics.addErrorLog("dup")
        diagnostics.addErrorLog("dup")
        let result = convertToDictionary(text: diagnostics.extractDiagonosticsToString())
        XCTAssertEqual(result?["error_logs"] as? [String], ["dup"])
    }

    func testTrimsMaxErrorLogs() {
        let maxErrorLogs = 10
        let diagnostics = Diagnostics()
        (0..<maxErrorLogs + 1).forEach {
            diagnostics.addErrorLog("\($0)")
        }
        let result = convertToDictionary(text: diagnostics.extractDiagonosticsToString())
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
