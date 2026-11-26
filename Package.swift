// swift-tools-version: 6.4
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls trois
// acteurs sans état partagé (captures, inventaire Accessibilité, OCR) en sortent.
let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Le socle commun des apps Synseria (jetons, trousse, télémétrie, mises à jour) : le dépôt
        // public engendré par le SDS, épinglé à une version.
        .package(url: "https://github.com/Synseria/SynseriaKit", exact: "2.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "Synfus",
            dependencies: [.product(name: "SynseriaDesign", package: "SynseriaKit"), .product(name: "Telemetrie", package: "SynseriaKit"), .product(name: "MiseAJour", package: "SynseriaKit")],
            path: "Sources/Synfus"
        ),
        .testTarget(
            name: "SynfusTests",
            dependencies: ["Synfus", .product(name: "SynseriaDesign", package: "SynseriaKit"), .product(name: "Telemetrie", package: "SynseriaKit"), .product(name: "MiseAJour", package: "SynseriaKit")],
            path: "Tests/SynfusTests"
        ),
    ]
)
