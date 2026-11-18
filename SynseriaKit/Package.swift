// swift-tools-version: 6.4
// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit ac80a4e0b47b7314 · contenu 87d2f823861a5444

import PackageDescription

let package = Package(
    name: "SynseriaKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Telemetrie", targets: ["Telemetrie"]),
    ],
    targets: [
        .target(name: "Telemetrie", path: "Sources/Telemetrie"),
    ],
    swiftLanguageModes: [.v6]
)
