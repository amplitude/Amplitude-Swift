# Amplitude Server-Side Swift Example

Example swift project which emulates a _server-side_ Swift implementation using [Vapor](https://vapor.codes).

## Running the example

This project was generated using the 'Getting Started' example from the [Vapor Docs](https://docs.vapor.codes).
The REST API project that it creates can be run in several ways:

* Opening the `Package.swift` file in Xcode and running the project on your mac.
* Executing `swift run` in the terminal from this examples directory.
* Using the `Dockerfile` / `docker-compose` script to create a virtual container that runs the application.

## Configuring the example

Configure the **Amplitude** instance in `./Sources/Run/main.swift`.
At a minimum you will need to specify your API Key.

```swift
let amplitude = Amplitude(
    configuration: Configuration(
        apiKey: "TEST-API-KEY",
        runningOnServer: true
    )
)
```

Note the `runningOnServer` parameter. This is required for systems that run in a windowless/headless state.
_There are explicit references to `DispatchQueue.main` in the library. This flag will use a `.global()` queue
instead to account for a GCD event loop not executing._

## Testing events

The Vapor example project comes with two endpoints preconfigured:

* `/`
* `/hello`

Each will track an event of type "GET {path}". These can be triggered right from the web browser. For instance:

`http://127.0.0.1:8080/hello`
