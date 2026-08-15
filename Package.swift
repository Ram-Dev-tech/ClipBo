// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipBo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ClipBo",
            targets: ["ClipBo"]
        ),
        .executable(
            name: "ClipBoApp",
            targets: ["ClipBoApp"]
        ),
        .executable(
            name: "ClipBoTests",
            targets: ["ClipBoTests"]
        ),
        .executable(
            name: "ClipBoPreview",
            targets: ["ClipBoPreview"]
        )
    ],
    targets: [
        .target(
            name: "ClipBo",
            path: "Sources/ClipBo"
        ),
        .executableTarget(
            name: "ClipBoApp",
            dependencies: ["ClipBo"],
            path: "Sources/ClipBoApp"
        ),
        .executableTarget(
            name: "ClipBoTests",
            dependencies: ["ClipBo"],
            path: "Tests/ClipBoTests"
        ),
        .executableTarget(
            name: "ClipBoPreview",
            dependencies: ["ClipBo"],
            path: "Sources/ClipBoPreview"
        )
    ]
)
