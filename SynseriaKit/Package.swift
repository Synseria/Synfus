// swift-tools-version: 6.4
// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu 004a0e60045df933

import PackageDescription

let package = Package(
    name: "SynseriaKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Telemetrie", targets: ["Telemetrie"]),
        .library(name: "MiseAJour", targets: ["MiseAJour", "Versions"]),
    ],
    targets: [
        .target(name: "Versions", path: "Sources/Versions"),
        .target(name: "Telemetrie", dependencies: ["Versions"], path: "Sources/Telemetrie"),
        .target(name: "MiseAJour", dependencies: ["Versions"], path: "Sources/MiseAJour"),
    ],
    swiftLanguageModes: [.v6]
)
