import Foundation

/// Les fichiers Swift de l'app, pour les tests qui gardent une règle dans le code.
enum SourcesDuDepot {
    static let dossier = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/Synfus")

    static func fichiers() -> [URL] {
        FileManager.default.enumerator(at: dossier, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
    }
}
