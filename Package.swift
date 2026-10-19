// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClipboardTyper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClipboardTyper", targets: ["ClipboardTyper"])],
    targets: [
        .target(name: "TypingCore"),
        .executableTarget(name: "ClipboardTyper", dependencies: ["TypingCore"]),
        .testTarget(name: "TypingCoreTests", dependencies: ["TypingCore"])
    ]
)
