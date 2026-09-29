// swift-tools-version: 6.4
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls trois
// acteurs sans état partagé (captures, inventaire Accessibilité, OCR) en sortent.
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
