import AppKit
import Combine
import Observation
import SwiftUI

/// Le thème courant (thème × nuance), fourni aux vues SwiftUI et aux panneaux AppKit : le seul code
/// de couleur hors de `Jetons`. Un rôle se lit par son chemin (`Color.jeton(\.plaque)`), jamais par
/// une liste recopiée ici. Sans nuance choisie, la couleur est dynamique — Jour ou Pénombre se décide
/// au dessin — et, lue dans un `body`, abonne la vue au réglage : un changement se redessine partout.
@MainActor
enum ThemeCourant {
    typealias Jeton = KeyPath<Jetons.Couleurs, Jetons.RVB>

    /// Ce qui détermine toutes les couleurs.
    struct Reglage: Hashable, Sendable {
        var theme = Jetons.themeParDefaut
        /// nil : l'app suit le système, Jour en clair, Pénombre en sombre.
        var nuance = Jetons.nuanceParDefaut

        func nuance(sombre: Bool) -> Jetons.Nuance { nuance ?? .duSysteme(sombre: sombre) }
    }

    /// À l'ouverture : pose l'apparence de la nuance choisie, puis la suit.
    static func demarrer() {
        NSApp.appearance = apparence(Preferences.shared.nuanceDeLApp)
        _ = Suivi.partage
    }

    /// Une nuance choisie impose son apparence à toute l'app (menus, champs et curseurs du système
    /// suivent) ; sans nuance, celle de macOS.
    static func apparence(_ nuance: Jetons.Nuance?) -> NSAppearance? {
        nuance.flatMap { NSAppearance(named: $0.sombre ? .darkAqua : .aqua) }
    }

    static var reglage: Reglage {
        _ = Suivi.partage.revision
        let prefs = Preferences.shared
        return Reglage(theme: prefs.themeDeLApp, nuance: prefs.nuanceDeLApp)
    }

    /// Les couleurs d'un thème dans une nuance, calculées une fois : l'app comme les pastilles de
    /// Réglages ▸ Thème (refaites à chaque pas du curseur de teinte) les lisent ici.
    static func couleurs(_ theme: Jetons.Theme, _ nuance: Jetons.Nuance) -> Jetons.Couleurs {
        let cle = Cle(theme: theme, nuance: nuance)
        if let connues = calculees[cle] { return connues }
        // Les coloris restent (44 au plus) ; d'une couleur à soi, seule la dernière.
        if case .personnalise = theme {
            calculees = calculees.filter { if case .personnalise = $0.key.theme { $0.key.theme == theme } else { true } }
        }
        let neuves = Jetons.Nuancier.couleurs(theme, nuance)
        calculees[cle] = neuves
        return neuves
    }

    private struct Cle: Hashable {
        let theme: Jetons.Theme
        // periphery:ignore - lue par le Hashable synthétisé : c'est la moitié de la clé
        let nuance: Jetons.Nuance
    }

    private static var calculees: [Cle: Jetons.Couleurs] = [:]

    /// Dynamique : la fermeture ne garde que les deux couleurs déjà calculées, jamais les préférences.
    fileprivate static func nsColor(_ valeur: (Jetons.Couleurs, Jetons.Nuance) -> Jetons.RVB) -> NSColor {
        let reglage = ThemeCourant.reglage
        let (jour, sombre) = (reglage.nuance(sombre: false), reglage.nuance(sombre: true))
        let clair = NSColor(valeur(couleurs(reglage.theme, jour), jour).couleur)
        let fonce = NSColor(valeur(couleurs(reglage.theme, sombre), sombre).couleur)
        return NSColor(name: nil) { dessin in
            dessin.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? fonce : clair
        }
    }
}

extension Color {
    /// Un rôle du thème courant.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton) -> Color {
        Color(nsColor: ThemeCourant.nsColor { couleurs, _ in couleurs[keyPath: jeton] })
    }

    /// Un rôle lu dans une nuance fixe : ce qui se pose sur l'image d'une carte du jeu s'écrit
    /// comme en Nuit, que la fenêtre soit claire ou sombre.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton, en nuance: Jetons.Nuance) -> Color {
        ThemeCourant.couleurs(ThemeCourant.reglage.theme, nuance)[keyPath: jeton].couleur
    }

    /// Un rôle écrit sur l'image d'une carte du jeu (`surImage`, sous son voile sombre) : en Nuit ;
    /// ailleurs, celui du thème courant.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton, surImage: Bool) -> Color {
        surImage ? Color.jeton(jeton, en: .nuit) : Color.jeton(jeton)
    }

    /// Le violet des positions suggérées : une couleur propre à Synfus (`Jetons.Propres`).
    @MainActor static var suggestionSynfus: Color {
        Color(nsColor: ThemeCourant.nsColor { _, nuance in Jetons.Propres.suggestionSynfus(nuance) })
    }
}

/// À poser sur la racine de chaque fenêtre, panneau, feuille et popover : les couleurs du thème
/// pour la trousse (`couleursSynseria`), et la teinte des contrôles du système, sans laquelle ils
/// prendraient l'accent de l'utilisateur. Un `ViewModifier`, pour que l'une et l'autre suivent le réglage.
struct RacineSynfus: ViewModifier {
    func body(content: Content) -> some View {
        let reglage = ThemeCourant.reglage
        content.tint(Color.jeton(\.accent)).themeSynseria(reglage.theme, nuance: reglage.nuance)
    }
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
        prefs.$themeDeLApp.dropFirst().sink { [weak self] _ in self?.revision += 1 }.store(in: &abonnements)
        prefs.$nuanceDeLApp.dropFirst().sink { [weak self] nuance in
            self?.revision += 1
            // Sous les tests, pas d'application : les captures posent l'apparence de leurs fenêtres.
            NSApp?.appearance = ThemeCourant.apparence(nuance)
        }.store(in: &abonnements)
    }
}
