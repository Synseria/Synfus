import Foundation

/// Les ressources embarquées : dans `Contents/Resources` du bundle (copiées par
/// `build.sh`), sinon dans `Resources/` du dépôt — pour `swift run` et les
/// tests, où il n'y a pas de bundle.
enum Ressources {
    /// `~/Library/Application Support/Synfus` : ce que Synfus garde d'un
    /// lancement à l'autre (listes de DofusDB, icônes de l'utilisateur).
    static let dossierUtilisateur: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus", directoryHint: .isDirectory)

    static func url(_ chemin: String) -> URL? {
        if let bundle = Bundle.main.resourceURL?.appending(path: chemin),
           FileManager.default.fileExists(atPath: bundle.path) {
            return bundle
        }
        let depot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App/
            .deletingLastPathComponent()   // Synfus/
            .deletingLastPathComponent()   // Sources/
            .deletingLastPathComponent()   // racine du dépôt
            .appending(path: "Resources").appending(path: chemin)
        return FileManager.default.fileExists(atPath: depot.path) ? depot : nil
    }
}
