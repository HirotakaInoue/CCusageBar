// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCusageBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CCusageBar",
            path: "Sources/CCusageBar"
        )
    ]
)
