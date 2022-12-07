//
//  UrlExtensionTests.swift
//  
//
//  Created by Marvin Liu on 12/7/22.
//

import XCTest

@testable import Amplitude_Swift

final class UrlExtensionTests: XCTestCase {
    func testAppendFileNameSuffix() {
        let url = URL(string: "abc/def/hello.txt")
        let newUrl = url?.appendFileNameSuffix(suffix: "-world")
        XCTAssertEqual(newUrl?.lastPathComponent, "hello-world.txt")
    }
}
