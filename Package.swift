// swift-tools-version: 6.0
import PackageDescription

// Concurrence stricte de Swift 6 : l'état vit sur le main actor ; seuls deux
// acteurs sans état partagé (captures, inventaire Accessibilité) en sortent.
//
// SynfusDeck est le plugin Stream Deck : un binaire séparé, lancé par le
// logiciel Elgato, qui parle à Synfus par le socket décrit dans
// Sources/Synfus/StreamDeck/Liaison/DeckProtocol.swift. Il ne partage aucun
// code avec l'app — le protocole JSON est le contrat.
let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Synfus",
            path: "Sources/Synfus"
        ),
        .executableTarget(
            name: "SynfusDeck",
            path: "Sources/SynfusDeck"
        ),
        .testTarget(
            name: "SynfusTests",
            dependencies: ["Synfus"],
            path: "Tests/SynfusTests"
        ),
    ]
)
