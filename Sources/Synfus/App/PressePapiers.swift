import AppKit

/// L'unique écriture dans le presse-papiers. Synfus n'émet aucun évènement :
/// il pose du texte, et c'est le joueur qui colle. Un seul foyer, pour que la
/// règle se lise à un seul endroit.
enum PressePapiers {
    @MainActor
    static func copier(_ texte: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texte, forType: .string)
    }
}
