// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Weeklight",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Weeklight", targets: ["Weeklight"])
    ],
    targets: [
        .executableTarget(
            name: "Weeklight",
            path: "Sources/Weeklight"
        ),
        .testTarget(
            name: "WeeklightTests",
            dependencies: ["Weeklight"],
            path: "Tests/WeeklightTests"
        )
    ]
)
