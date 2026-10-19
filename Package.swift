// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Yetda",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "YetdaCore"),
        .executableTarget(
            name: "Yetda",
            dependencies: ["YetdaCore"]
        ),
        .testTarget(
            name: "YetdaCoreTests",
            dependencies: ["YetdaCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
