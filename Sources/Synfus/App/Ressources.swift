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

    /// Les captures de la documentation se prennent (`SYNFUS_CAPTURES`, cf.
    /// `CapturesTests`).
    static let captureDocumentation = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES"] != nil

    /// Faux pendant une capture de la documentation : ni vue de carte, ni
    /// pictogramme, ni emblème — pas même l'icône posée par l'utilisateur.
    /// Une capture du dépôt ne porte aucun visuel du jeu (CGU Dofus, art.
    /// 13.2), quel que soit le cache de la machine qui la prend.
    static let visuelsDuJeu = !captureDocumentation

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
