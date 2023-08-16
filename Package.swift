// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Amplitude-Swift",
    platforms: [
        .macOS("10.15"),
        .iOS("13.0"),
        .tvOS("13.0"),
        .watchOS("7.0"),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AmplitudeSwift",
            targets: ["AmplitudeSwift"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .apt(["sqlite3", "libsqlite3-dev"])
            ]
        ),
        .target(
            name: "AmplitudeSwift",
            dependencies: [
                .target(name: "CSQLite", condition: .when(platforms: [.linux]))
            ],
            path: "Sources/Amplitude",
            exclude: ["../../Examples/", "../../Tests/"]
        ),
        .testTarget(
            name: "AmplitudeSwiftTests",
            dependencies: ["AmplitudeSwift"],
            path: "Tests/AmplitudeTests",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
