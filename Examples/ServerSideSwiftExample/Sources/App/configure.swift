import Vapor
import Amplitude_Swift

// configures your application
public func configure(_ app: Application, amplitude: Amplitude) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // register routes
    try routes(app, amplitude: amplitude)
}
