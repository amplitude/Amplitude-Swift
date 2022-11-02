import XCTest

@testable import Amplitude_Swift

final class AmplitudeTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(
            Amplitude(configuration: Configuration(apiKey: "testApiKey")).instanceName,
            Constants.Configuration.DEFAULT_INSTANCE
        )
    }
}
