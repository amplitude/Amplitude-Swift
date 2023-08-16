import Vapor
import Amplitude_Swift

func routes(_ app: Application, amplitude: Amplitude) throws {
    app.get { req async in
        amplitude.track(eventType: "GET /")
        return "It works!"
    }

    app.get("hello") { req async -> String in
        amplitude.track(eventType: "GET /hello")
        return "Hello, world!"
    }
}
