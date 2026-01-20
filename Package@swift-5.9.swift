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
        .package(url: "https://github.com/amplitude/analytics-connector-ios.git", from: "1.3.0"),
        .package(url: "https://github.com/amplitude/AmplitudeCore-Swift.git", from: "1.3.3"),
    ],
    targets: [
        .target(
            name: "AmplitudeSwift",
            dependencies: [
                .product(name: "AmplitudeCoreFramework", package: "AmplitudeCore-Swift"),
                .product(name: "AnalyticsConnector", package: "analytics-connector-ios"),
            ],
            path: "Sources/Amplitude",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "Amplitude-SwiftTests",
            dependencies: [
                .target(name: "AmplitudeSwift"),
            ],
            path: "Tests/AmplitudeTests",
            resources: [
                .process("Migration/legacy_v3.sqlite"),
                .process("Migration/legacy_v4.sqlite"),
            ])
    ]
)
