import Foundation

/// Ce qui, dans l'installation elle-même, peut empêcher l'autorisation
/// Accessibilité de prendre effet.
///
/// Le cas qui motive ce fichier : une app téléchargée porte l'attribut
/// `com.apple.quarantine`, et le conserve en étant copiée depuis le DMG. Signée
/// ad-hoc, elle n'offre à macOS aucune identité stable — seulement l'empreinte
/// du binaire. La case se coche alors dans les Réglages sans que
/// `AXIsProcessTrusted()` ne passe jamais à vrai, et **rien ne le signale** :
/// l'app se lance normalement. Autant le détecter et le dire.
enum AppIntegrity {

    /// Vrai si ce chemin porte encore l'attribut de quarantaine.
    ///
    /// `XATTR_NOFOLLOW` : on interroge le bundle lui-même, pas la cible d'un
    /// lien symbolique qui le remplacerait.
    static func isQuarantined(path: String) -> Bool {
        getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    /// Vrai si l'app en cours d'exécution est en quarantaine.
    static var isQuarantined: Bool {
        isQuarantined(path: Bundle.main.bundlePath)
    }

    /// La commande qui lève la quarantaine, avec le chemin réel de l'app —
    /// copiable telle quelle, y compris si l'app n'est pas dans `/Applications`.
    static var quarantineFix: String {
        "xattr -dr com.apple.quarantine \(shellQuoted(Bundle.main.bundlePath))"
    }

    /// Réinitialise l'autorisation, nécessaire quand l'app a déjà été lancée en
    /// quarantaine : l'entrée enregistrée alors ne redeviendra jamais valide.
    static var resetCommand: String {
        let identifier = Bundle.main.bundleIdentifier ?? "fr.synseria.Synfus"
        return "tccutil reset Accessibility \(identifier)"
    }

    /// Échappe un chemin pour qu'il survive à un copier-coller dans un shell :
    /// « /Applications/Mon App.app » sans guillemets serait lu comme deux
    /// arguments.
    private static func shellQuoted(_ path: String) -> String {
        guard path.contains(where: { " '\"\\$`".contains($0) }) else { return path }
        return "'" + path.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
