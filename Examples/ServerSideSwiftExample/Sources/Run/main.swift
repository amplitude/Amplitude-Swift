import App
import Vapor
import Amplitude_Swift

let amplitude = Amplitude(
    configuration: Configuration(
        apiKey: "TEST-API-KEY",
        runningOnServer: true
    )
)

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app, amplitude: amplitude)
try app.run()
