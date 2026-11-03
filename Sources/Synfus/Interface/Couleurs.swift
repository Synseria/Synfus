import AppKit
import SwiftUI

/// Les couleurs de Synfus, en un seul endroit : le vert d'eau des zaaps (et
/// de toute sélection), l'ambre des étiquettes, le violet de ce que Synfus
/// suggère (« tu y es »), l'orange de ce qui demande un geste, le vert de ce
/// qui va bien. `Color.accentColor` n'en est pas : il rend l'accent système de
/// l'utilisateur (`JetonsTests`).
enum Couleurs {
    static let accent = Color(red: 0.19, green: 0.65, blue: 0.53)
    /// L'accent en aplat sous du texte blanc : `accent` n'y tient pas 4,5:1.
    static let accentPlein = Color(red: 0.12, green: 0.50, blue: 0.41)
    /// L'accent d'un texte : `accent` ne tient pas 4,5:1 sur un fond clair.
    static let accentTexte = Color(nsColor: NSColor(name: nil) { apparence in
        let sombre = apparence.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return sombre ? NSColor(srgbRed: 0.19, green: 0.65, blue: 0.53, alpha: 1)
                      : NSColor(srgbRed: 0.12, green: 0.50, blue: 0.41, alpha: 1)
    })
    static let ambre = Color(red: 0.89, green: 0.71, blue: 0.35)
    static let suggestion = Color(red: 0.62, green: 0.45, blue: 0.95)
    static let alerte = Color.orange
    static let succes = Color.green
}
