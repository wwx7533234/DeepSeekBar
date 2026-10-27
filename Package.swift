// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeepSeekBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeepSeekBar",
            path: "Sources/DeepSeekBar"
        )
    ]
)
