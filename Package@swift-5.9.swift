// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Amplitude-Swift",
    platforms: [
        .macOS("10.15"),
        .iOS("13.0"),
        .tvOS("13.0"),
        .watchOS("7.0"),
        .visionOS("1.0"),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AmplitudeSwift",
            targets: ["AmplitudeSwift"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/amplitude/analytics-connector-ios.git", from: "1.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "AmplitudeSwift",
            dependencies: [
                .product(name: "AnalyticsConnector", package: "analytics-connector-ios")
            ],
            path: "Sources/Amplitude",
            exclude: ["../../Examples/", "../../Tests/"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "Amplitude-SwiftTests",
            dependencies: ["AmplitudeSwift"],
            path: "Tests/AmplitudeTests"
        ),
    ]
)
