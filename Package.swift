// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Still",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Still",
            path: "Sources/Still"
        ),
        .testTarget(
            name: "StillTests",
            dependencies: ["Still"],
            path: "Tests/StillTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
