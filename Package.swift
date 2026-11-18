// swift-tools-version: 6.4
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls trois
// acteurs sans état partagé (captures, inventaire Accessibilité, OCR) en sortent.
let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Le socle commun des apps Synseria : la copie que pose `propager.sh` du SDS (privé),
        // versionnée ici, jamais retouchée.
        .package(path: "SynseriaKit"),
    ],
    targets: [
        .executableTarget(
            name: "Synfus",
            dependencies: [.product(name: "Telemetrie", package: "SynseriaKit")],
            path: "Sources/Synfus"
        ),
        .testTarget(
            name: "SynfusTests",
            dependencies: ["Synfus", .product(name: "Telemetrie", package: "SynseriaKit")],
            path: "Tests/SynfusTests"
        ),
    ]
)
