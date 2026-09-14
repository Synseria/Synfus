import Foundation

/// Où sont les visuels du jeu — emblèmes de classes, icônes de sorts — et
/// dans quel ordre on les cherche.
///
/// Deux emplacements, un seul ordre : **Application Support d'abord**, le
/// bundle ensuite. Application Support est ce que l'utilisateur alimente lui-
/// même (Réglages → Classes, dépôt de fichiers) : il garde la priorité. Le
/// bundle ne contient les visuels que si `Resources/Ankama/` existait au
/// moment du `build.sh` — un dossier ignoré par Git, rempli par
/// `Tools/fetch-ankama-assets.sh` pour cette machine ; les releases de la CI
/// n'en ont pas. Rien du jeu n'est jamais dans le dépôt (CGU Dofus, art. 13.2).
enum AnkamaAssets {

    /// `~/Library/Application Support/Synfus`
    static let supportDirectory: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus", directoryHint: .isDirectory)

    /// `Contents/Resources/Ankama` du bundle, s'il a été embarqué.
    ///
    /// `SYNFUS_ANKAMA_DIR` dans l'environnement le remplace — pour les tests de
    /// calibrage sur captures réelles, qui tournent hors bundle.
    static let bundledDirectory: URL? = {
        if let override = ProcessInfo.processInfo.environment["SYNFUS_ANKAMA_DIR"] {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        let url = Bundle.main.resourceURL?.appending(path: "Ankama", directoryHint: .isDirectory)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }()

    /// Le dossier des emblèmes de classes que l'utilisateur alimente.
    static var classIconsDirectory: URL {
        supportDirectory.appending(path: "Classes", directoryHint: .isDirectory)
    }

    /// L'emblème d'une classe, par clé `DofusClass` : la copie de l'utilisateur
    /// si elle existe, sinon celle du bundle, sinon rien.
    static func classIconURL(key: String) -> URL? {
        firstExisting(
            classIconsDirectory.appending(path: "\(key).png"),
            bundledDirectory?.appending(path: "Classes/\(key).png")
        )
    }

    /// L'icône d'un sort, par le chemin relatif que donne `sorts.json`
    /// (`Sorts/<classe>/<Nom>.png`).
    static func spellIconURL(fichier: String) -> URL? {
        firstExisting(
            supportDirectory.appending(path: fichier),
            bundledDirectory?.appending(path: fichier)
        )
    }

    /// L'index `sorts.json` écrit par le script, s'il y en a un.
    static var spellIndexURL: URL? {
        firstExisting(
            supportDirectory.appending(path: "sorts.json"),
            bundledDirectory?.appending(path: "sorts.json")
        )
    }

    private static func firstExisting(_ candidates: URL?...) -> URL? {
        candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
