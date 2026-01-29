//
//  GzipTests.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 1/27/26.
//

@testable import AmplitudeSwift
import XCTest

final class GzipTests: XCTestCase {

    // MARK: - Helpers

    private func normalizedGzip(_ data: Data) -> Data {
        XCTAssertGreaterThan(data.count, 10)

        var result = data

        // gzip header layout:
        // 0-1: magic
        // 2: compression method
        // 3: flags
        // 4-7: mtime  (variable)
        // 8: xfl
        // 9: os      (variable)
        //
        // Zero out mtime + os to make output deterministic
        result.replaceSubrange(4..<8, with: repeatElement(0, count: 4))
        result[9] = 0

        return result
    }

    private func assertRoundTrip(_ input: Data, file: StaticString = #filePath, line: UInt = #line) {
        guard let gz = try? input.gzipped() else {
            XCTFail("gzipped returned nil", file: file, line: line)
            return
        }
        guard let out = gz.gunzipped() else {
            XCTFail("gunzip failed", file: file, line: line)
            return
        }
        XCTAssertEqual(out, input, "round-trip mismatch", file: file, line: line)
    }

    // MARK: - Tests

    func testEmptyDataReturnsEmptyData() {
        let input = Data()
        let gz = try? input.gzipped()
        XCTAssertNotNil(gz)
        XCTAssertEqual(gz, Data())
    }

    func testSmallAsciiRoundTrip_DefaultLevel() {
        let input = Data("hello gzip\n".utf8)
        assertRoundTrip(input)
    }

    func testBinaryDataRoundTrip() {
        let bytes = (0..<256).map { UInt8($0) }
        let input = Data(bytes + bytes + bytes) // some repetition
        assertRoundTrip(input)
    }

    func testLargeDataRoundTrip() {
        // > 64KB to force multiple chunks and multiple deflate iterations
        var input = Data(count: 512 * 1024)
        input.withUnsafeMutableBytes { raw in
            guard let p = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<raw.count {
                // deterministic pseudo-pattern (compresses somewhat, but not trivially)
                p[i] = UInt8((i &* 31 &+ (i >> 3)) & 0xFF)
            }
        }
        assertRoundTrip(input)
    }

    func testGzipMagicHeader() {
        let input = Data("header check".utf8)
        guard let gz = try? input.gzipped() else {
            return XCTFail("gzipped returned nil")
        }
        // gzip magic bytes: 0x1f, 0x8b
        XCTAssertGreaterThanOrEqual(gz.count, 2)
        XCTAssertEqual(gz[gz.startIndex], 0x1f)
        XCTAssertEqual(gz[gz.startIndex + 1], 0x8b)
    }

    func testCompressedOutputUsuallySmallerForHighlyRedundantData() {
        // Not a guaranteed property for arbitrary data, so choose a very compressible payload.
        let input = Data(repeating: 0x41, count: 256 * 1024) // "AAAA..."
        guard let gz = try? input.gzipped() else {
            return XCTFail("gzipped returned nil")
        }
        XCTAssertLessThan(gz.count, input.count)
        // Also ensure round-trip correctness
        XCTAssertEqual(gz.gunzipped(), input)
    }

    func testFixedVector_hello() {
        let input = Data("hello".utf8)

        guard let gz = try? input.gzipped() else {
            return XCTFail("compression failed")
        }

        let normalized = normalizedGzip(gz)

        let expected: [UInt8] = [
            0x1f, 0x8b, 0x08, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, // xfl, os (normalized)
            0xcb, 0x48, 0xcd, 0xc9,
            0xc9, 0x07, 0x00,
            0x86, 0xa6, 0x10, 0x36,
            0x05, 0x00, 0x00, 0x00
        ]

        XCTAssertEqual(Array(normalized), expected)
    }

    func testFixedVector_emptyString() throws {
        let input = Data()

        let gz = try input.gzipped()
        XCTAssertEqual(gz, Data())
    }

    func testFixedVector_repeatedA() throws {
        let input = Data(repeating: 0x41, count: 32)

        let gz = try input.gzipped()
        let normalized = normalizedGzip(gz)

        let expected: [UInt8] = [
            0x1f, 0x8b, 0x08, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00,
            0x73, 0x74, 0xc4, 0x0f,
            0x00,
            0x1e, 0x6f, 0x31, 0xad,
            0x20, 0x00, 0x00, 0x00
        ]

        XCTAssertEqual(Array(normalized), expected)
    }
}
