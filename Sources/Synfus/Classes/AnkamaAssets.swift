import Foundation

/// Où sont les emblèmes de classes du jeu, et dans quel ordre on les cherche.
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
    /// `SYNFUS_ANKAMA_DIR` dans l'environnement le remplace — hors bundle
    /// (`swift run`), il n'y a pas d'autre moyen de pointer vers les visuels.
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

    private static func firstExisting(_ candidates: URL?...) -> URL? {
        candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
