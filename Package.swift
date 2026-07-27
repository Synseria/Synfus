// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Synfus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Synfus",
            path: "Sources/Synfus",
            // Mode langage 5 : AppKit et l'API Accessibilité (CoreFoundation) ne sont
            // pas annotés pour la concurrence stricte de Swift 6. Tout le code de cette
            // app vit de toute façon sur le main thread.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
