import AppKit

/// L'unique accès au presse-papiers. Synfus n'émet aucun évènement : il pose
/// du texte, et c'est le joueur qui colle. Un seul foyer, pour que la règle se
/// lise à un seul endroit.
enum PressePapiers {
    @MainActor
    static func copier(_ texte: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texte, forType: .string)
    }

    /// Le texte copié — sauf celui qu'un gestionnaire de mots de passe marque
    /// comme secret (convention nspasteboard.org) : il ne regarde pas Synfus.
    @MainActor
    static func lire() -> String? {
        let presse = NSPasteboard.general
        let secrets = [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
                       NSPasteboard.PasteboardType("org.nspasteboard.TransientType")]
        guard presse.types?.contains(where: secrets.contains) != true else { return nil }
        return presse.string(forType: .string)
    }

    /// Change à chaque copie, de n'importe quelle app. Le lire ne lit pas le
    /// contenu : macOS ne demande rien.
    @MainActor
    static var generation: Int { NSPasteboard.general.changeCount }
}
