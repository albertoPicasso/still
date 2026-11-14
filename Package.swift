// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PipelinesDrop",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "PipelinesDrop",
            path: "Sources/PipelinesDrop"
        ),
        .testTarget(
            name: "PipelinesDropTests",
            dependencies: ["PipelinesDrop"],
            path: "Tests/PipelinesDropTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
