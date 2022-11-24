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

    func testContext() {
        let amplitude = Amplitude(configuration: configuration)
        let outputReader = OutputReaderPlugin()
        amplitude.add(plugin: outputReader)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))

        let lastEvent = outputReader.lastEvent
        XCTAssertEqual(lastEvent?.library, "\(Constants.SDK_LIBRARY)/\(Constants.SDK_VERSION)")
        XCTAssertEqual(lastEvent?.deviceManufacturer, "Apple")
        XCTAssertEqual(lastEvent?.deviceModel!.isEmpty, false)
        XCTAssertEqual(lastEvent?.ip, "$remote")
        XCTAssertNil(lastEvent?.country)
        XCTAssertEqual(lastEvent?.platform!.isEmpty, false)
        XCTAssertEqual(lastEvent?.language!.isEmpty, false)
    }
}
