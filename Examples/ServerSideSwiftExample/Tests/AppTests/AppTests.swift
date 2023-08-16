@testable import App
import XCTVapor
@testable import Amplitude_Swift

final class AppTests: XCTestCase {
    func testHelloWorld() throws {
        let apiKey = "TEST-API-KEY"
        
        let storage = PersistentStorage(storagePrefix: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-\(apiKey)")
        
        let amplitude = Amplitude(
            configuration: Configuration(
                apiKey: apiKey,
                storageProvider: storage,
                logLevel: .DEBUG
            )
        )
        
        storage.reset()
        
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app, amplitude: amplitude)

        try app.test(.GET, "hello", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        })
        
        // Verify that the request event was logged in the persistent storage.
        let urls: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        let url = try XCTUnwrap(urls.first)
        let data = try Data(contentsOf: url)
        let events = try JSONDecoder().decode([BaseEvent].self, from: data)
        let request = try XCTUnwrap(events.last)
        XCTAssertEqual(request.eventType, "GET /hello")
    }
}
