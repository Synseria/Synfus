import AppKit
import Combine
import Observation
import SwiftUI

/// Le thème courant (réglage × clair ou sombre), fourni aux vues SwiftUI et aux panneaux AppKit :
/// le seul code de couleur hors de `Jetons`. Un jeton se lit par son chemin (`Color.jeton(\.surface)`),
/// jamais par une liste recopiée ici. La couleur est dynamique — clair ou sombre se décide au dessin —
/// et, lue dans un `body`, abonne la vue au réglage : un changement se redessine partout.
@MainActor
enum ThemeCourant {
    typealias Jeton = KeyPath<Jetons.Theme, Jetons.RVB>

    /// Ce qui détermine tous les jetons ; sans fonds choisis, ceux de l'Auto.
    struct Reglage: Hashable, Sendable {
        var couleur = Jetons.couleurParDefaut
        var fonds: Jetons.Fonds?
    }

    static var reglage: Reglage {
        _ = Suivi.partage.revision
        let prefs = Preferences.shared
        return Reglage(couleur: prefs.couleurDeLApp, fonds: prefs.fondsDeLApp)
    }

    static func theme(_ apparence: Jetons.Apparence, _ reglage: Reglage = ThemeCourant.reglage) -> Jetons.Theme {
        if let memoire, memoire.reglage == reglage { return apparence == .clair ? memoire.clair : memoire.sombre }
        let clair = Jetons.theme(reglage.couleur, fonds: reglage.fonds, .clair)
        let sombre = Jetons.theme(reglage.couleur, fonds: reglage.fonds, .sombre)
        memoire = (reglage, clair, sombre)
        return apparence == .clair ? clair : sombre
    }

    private static var memoire: (reglage: Reglage, clair: Jetons.Theme, sombre: Jetons.Theme)?

    /// Dynamique : la fermeture ne garde que les deux couleurs déjà calculées, jamais les préférences.
    fileprivate static func nsColor(_ jeton: Jeton) -> NSColor {
        let reglage = ThemeCourant.reglage
        let (clair, sombre) = (theme(.clair, reglage)[keyPath: jeton].nsColor, theme(.sombre, reglage)[keyPath: jeton].nsColor)
        return NSColor(name: nil) { dessin in
            dessin.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? sombre : clair
        }
    }
}

extension Color {
    /// Un jeton du thème courant.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton) -> Color { Color(nsColor: ThemeCourant.nsColor(jeton)) }
}

extension NSColor {
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton) -> NSColor { ThemeCourant.nsColor(jeton) }
}

extension Jetons.RVB {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: opacite)
    }
}

/// À poser sur la racine de chaque fenêtre : sans elle, un contrôle du système y prend l'accent
/// de l'utilisateur. Un `ViewModifier`, pour que la teinte suive la couleur choisie.
struct RacineSynfus: ViewModifier {
    func body(content: Content) -> some View { content.tint(Color.jeton(\.primaire)) }
}

extension View {
    func racineSynfus() -> some View { modifier(RacineSynfus()) }
}

/// Le témoin de changement : `Preferences` est un `ObservableObject`, que SwiftUI ne suit pas depuis
/// une lecture statique. Lire `revision` dans un `body` suffit à l'abonner.
@MainActor
@Observable
private final class Suivi {
    static let partage = Suivi()
    var revision = 0
    @ObservationIgnored private var abonnements: Set<AnyCancellable> = []

    private init() {
        let prefs = Preferences.shared
        // Émis avant l'écriture : la vue relit les préférences au redessin, qui vient après.
        prefs.$couleurDeLApp.dropFirst().sink { [weak self] _ in self?.revision += 1 }.store(in: &abonnements)
        prefs.$fondsDeLApp.dropFirst().sink { [weak self] _ in self?.revision += 1 }.store(in: &abonnements)
    }
}
