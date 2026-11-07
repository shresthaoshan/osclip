// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "osclip",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "OSClip"),
        .testTarget(name: "OSClipTests", dependencies: ["OSClip"]),
    ]
)
