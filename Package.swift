// swift-tools-version: 6.0
import PackageDescription

// Concurrence stricte de Swift 6 : tout ce qui touche AppKit ou l'API
// Accessibilité est isolé au main actor, ce qui est la réalité de cette app —
// elle ne quitte jamais le thread principal.
let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Synfus",
            path: "Sources/Synfus"
        ),
        .testTarget(
            name: "SynfusTests",
            dependencies: ["Synfus"],
            path: "Tests/SynfusTests"
        ),
    ]
)
