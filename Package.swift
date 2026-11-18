// swift-tools-version: 6.4
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls trois
// acteurs sans état partagé (captures, inventaire Accessibilité, OCR) en sortent.
let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Le socle commun des apps Synseria, épinglé par révision, jamais par branche.
        .package(url: "git@github.com:Synseria/Synseria-Design.git", revision: "f926d5becc53e49f1c885690a9ac2126c2d31662"),
    ],
    targets: [
        .executableTarget(
            name: "Synfus",
            dependencies: [.product(name: "Telemetrie", package: "Synseria-Design")],
            path: "Sources/Synfus"
        ),
        .testTarget(
            name: "SynfusTests",
            dependencies: ["Synfus", .product(name: "Telemetrie", package: "Synseria-Design")],
            path: "Tests/SynfusTests"
        ),
    ]
)
