import XCTest

@testable import AmplitudeSwift

// Placeholder macOS 27+ returns instead of a real MAC address. Kept independent of the SDK's
// literals, so a wrong value there fails these tests.
private let redactedMacAddress = "02:00:00:00:00:00"

final class ContextPluginDeviceIdTests: XCTestCase {

    private class StubVendorSystem: VendorSystem {
        let idfv: String?

        init(idfv: String?) {
            self.idfv = idfv
        }

        override var identifierForVendor: String? {
            return idfv
        }
    }

    private static let validIdfv = "11111111-2222-3333-4444-555555555555"

    private var originalDevice: VendorSystem!
    private var storage: FakeInMemoryStorage!
    private var instanceName: String!

    override func setUp() {
        super.setUp()
        originalDevice = ContextPlugin.device
        storage = FakeInMemoryStorage()
        instanceName = "context-plugin-device-id-\(UUID().uuidString)"
    }

    override func tearDown() {
        ContextPlugin.device = originalDevice
        super.tearDown()
    }

    // Each call is one app launch on the same storage.
    private func launch(idfv: String?,
                        persistedDeviceId: String? = nil,
                        configuredDeviceId: String? = nil,
                        trackingOptions: TrackingOptions = TrackingOptions()) -> Amplitude {
        ContextPlugin.device = StubVendorSystem(idfv: idfv)
        if let persistedDeviceId {
            try? storage.write(key: .DEVICE_ID, value: persistedDeviceId)
        }
        return Amplitude(configuration: Configuration(
            apiKey: "testApiKeyContextPluginDeviceId",
            instanceName: instanceName,
            storageProvider: storage,
            identifyStorageProvider: FakeInMemoryStorage(),
            trackingOptions: trackingOptions,
            migrateLegacyData: false,
            deviceId: configuredDeviceId
        ))
    }

    private func assertIsRandomUUID(_ deviceId: String?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(deviceId.flatMap(UUID.init(uuidString:)), "expected a random UUID, got \(String(describing: deviceId))",
                        file: file, line: line)
        XCTAssertNotEqual(deviceId, Self.validIdfv, file: file, line: line)
    }

    private func trackedEvent(_ amplitude: Amplitude) -> BaseEvent? {
        let outputReader = OutputReaderPlugin()
        amplitude.add(plugin: outputReader)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))
        amplitude.waitForTrackingQueue()
        return outputReader.lastEvent
    }

    func testUsesIdfvAsDeviceId() {
        let amplitude = launch(idfv: Self.validIdfv)
        XCTAssertEqual(amplitude.getDeviceId(), Self.validIdfv)
    }

    func testZeroIdfvFallsBackToRandomUUID() {
        let amplitude = launch(idfv: "00000000-0000-0000-0000-000000000000")
        assertIsRandomUUID(amplitude.getDeviceId())
    }

    // macOS 27 redacts MAC addresses to 02:00:00:00:00:00 on every device (#446).
    func testRedactedMacAddressIdfvFallsBackToRandomUUID() {
        let amplitude = launch(idfv: redactedMacAddress)
        assertIsRandomUUID(amplitude.getDeviceId())
    }

    func testValidIdfvIsSentAsIdfv() {
        let amplitude = launch(idfv: Self.validIdfv)
        XCTAssertEqual(trackedEvent(amplitude)?.idfv, Self.validIdfv)
    }

    func testResetWithRedactedMacAddressRotatesToRandomUUID() {
        let amplitude = launch(idfv: redactedMacAddress)
        let first = amplitude.getDeviceId()
        amplitude.reset()
        assertIsRandomUUID(amplitude.getDeviceId())
        XCTAssertNotEqual(amplitude.getDeviceId(), first)
    }

    // Pins existing behavior: with IDFV tracking on, reset() lands back on the same IDFV.
    func testResetWithValidIdfvReturnsToIdfv() {
        let amplitude = launch(idfv: Self.validIdfv)
        amplitude.setDeviceId(deviceId: "custom-device-id")
        amplitude.reset()
        XCTAssertEqual(amplitude.getDeviceId(), Self.validIdfv)
    }

    // Installs that already persisted the redacted MAC as their device id must be repaired once, then stay stable.
    func testPersistedRedactedMacAddressIsReplacedOnceThenStable() {
        let repaired = launch(idfv: redactedMacAddress,
                              persistedDeviceId: redactedMacAddress).getDeviceId()
        assertIsRandomUUID(repaired)

        let relaunched = launch(idfv: redactedMacAddress).getDeviceId()
        XCTAssertEqual(relaunched, repaired)
    }

    // Legacy Amplitude-iOS formats the MAC without separators; RemnantDataMigration carries it over as-is.
    func testPersistedLegacyRedactedMacAddressIsReplaced() {
        let amplitude = launch(idfv: nil, persistedDeviceId: "020000000000")
        assertIsRandomUUID(amplitude.getDeviceId())
    }

    func testPersistedInvalidDeviceIdIsReplaced() {
        let amplitude = launch(idfv: nil, persistedDeviceId: "e3f5536a141811db40efd6400f1d0a4e")
        assertIsRandomUUID(amplitude.getDeviceId())
    }

    func testPersistedInvalidDeviceIdIsReplacedWithRandomUUIDWhenIdfvDisabled() {
        let amplitude = launch(idfv: Self.validIdfv,
                               persistedDeviceId: redactedMacAddress,
                               trackingOptions: TrackingOptions().disableTrackIDFV())
        assertIsRandomUUID(amplitude.getDeviceId())
    }

    func testPersistedValidDeviceIdIsKept() {
        let amplitude = launch(idfv: redactedMacAddress, persistedDeviceId: "a0:b1:c2:d3:e4:f5")
        XCTAssertEqual(amplitude.getDeviceId(), "a0:b1:c2:d3:e4:f5")
    }

    // Amplitude.init re-applies a configured id on every launch; replacing it would mint a new device each launch.
    func testConfiguredInvalidDeviceIdIsKeptAcrossLaunches() {
        let configured = "00000000-0000-0000-0000-000000000000"
        let first = launch(idfv: nil, configuredDeviceId: configured).getDeviceId()
        let second = launch(idfv: nil, configuredDeviceId: configured).getDeviceId()
        XCTAssertEqual(first, configured)
        XCTAssertEqual(second, configured)
    }

    func testConfiguredValidDeviceIdWinsOverIdfv() {
        let amplitude = launch(idfv: Self.validIdfv, configuredDeviceId: "configured-device-id")
        XCTAssertEqual(amplitude.getDeviceId(), "configured-device-id")
    }
}

#if os(macOS)
// Runs against the real MacOSVendorSystem (no stub), so on a macOS 27 machine it exercises the actual redaction.
final class MacOSVendorSystemDeviceIdTests: XCTestCase {

    func testIdentifierForVendorIsNeverRedactedMacAddress() {
        let vendorSystem = MacOSVendorSystem()
        let rawMacAddress = vendorSystem.macAddress(bsd: "en0")
        let identifierForVendor = vendorSystem.identifierForVendor
        print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString): "
              + "en0 MAC = \(rawMacAddress ?? "nil"), identifierForVendor = \(identifierForVendor ?? "nil")")

        XCTAssertNotEqual(identifierForVendor, redactedMacAddress)
        if rawMacAddress == redactedMacAddress {
            XCTAssertNil(identifierForVendor)
        } else {
            XCTAssertEqual(identifierForVendor, rawMacAddress)
        }
    }

    func testFreshInstallDeviceIdIsNotRedactedMacAddress() {
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "testApiKeyMacOSVendorSystemDeviceId",
            instanceName: "macos-vendor-system-device-id-\(UUID().uuidString)",
            storageProvider: FakeInMemoryStorage(),
            identifyStorageProvider: FakeInMemoryStorage(),
            migrateLegacyData: false
        ))
        print("fresh install deviceId = \(amplitude.getDeviceId() ?? "nil")")

        XCTAssertNotNil(amplitude.getDeviceId())
        XCTAssertNotEqual(amplitude.getDeviceId(), redactedMacAddress)
    }
}
#endif
