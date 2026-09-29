// swift-tools-version: 6.0
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls deux
// acteurs sans état partagé (captures, inventaire Accessibilité) en sortent.

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
