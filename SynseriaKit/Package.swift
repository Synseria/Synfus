// swift-tools-version: 6.4
// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 832ae65487891069 · contenu 824b28ea4e81e2e3

import PackageDescription

let package = Package(
    name: "SynseriaKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Telemetrie", targets: ["Telemetrie"]),
    ],
    targets: [
        .target(name: "Telemetrie", path: "Sources/Telemetrie"),
    ],
    swiftLanguageModes: [.v6]
)
