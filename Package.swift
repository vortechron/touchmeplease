// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "touchmeplease",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "touchmeplease",
            path: "Sources/touchmeplease"
        )
    ]
)
