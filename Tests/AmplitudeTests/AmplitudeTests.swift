import XCTest

@testable import Amplitude_Swift

final class AmplitudeTests: XCTestCase {
    private var configuration: Configuration!

    override func setUp() {
        super.setUp()
        configuration = Configuration(apiKey: "testApiKey")
    }

    func testAmplitudeInit() {
        XCTAssertEqual(
            Amplitude(configuration: configuration).instanceName,
            Constants.Configuration.DEFAULT_INSTANCE
        )
    }
}
