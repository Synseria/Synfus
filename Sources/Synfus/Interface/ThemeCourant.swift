import AppKit
import Combine
import Observation
import SwiftUI
import SynseriaDesign

/// Le thème courant, fourni aux vues SwiftUI et aux panneaux AppKit : le seul code de couleur hors de
/// `Jetons`. Un rôle se lit par son chemin (`Color.jeton(\.plaque)`), jamais par une liste recopiée ici.
/// Avec le système, la couleur est dynamique — sa clarté claire ou sombre se décide au dessin — et, lue
/// dans un `body`, abonne la vue au réglage : un changement se redessine partout.
@MainActor
enum ThemeCourant {
    typealias Jeton = KeyPath<Jetons.Couleurs, Jetons.RVB>

    /// À l'ouverture : pose l'apparence qu'impose le thème, puis la suit.
    static func demarrer() {
        NSApp.appearance = apparence(Preferences.shared.themeDeLApp)
        _ = Suivi.partage
    }

    /// Une clarté choisie hors du système impose son apparence à toute l'app (menus, champs et curseurs
    /// du système suivent) ; avec le système, celle de macOS.
    static func apparence(_ theme: Jetons.Theme) -> NSAppearance? {
        theme.sombreImpose.flatMap { NSAppearance(named: $0 ? .darkAqua : .aqua) }
    }

    static var theme: Jetons.Theme {
        _ = Suivi.partage.revision
        return Preferences.shared.themeDeLApp
    }

    /// Le thème courant à une clarté fixe : ce qui se pose sur l'image d'une carte du jeu s'écrit en Nuit,
    /// que la fenêtre soit claire ou sombre.
    static func theme(en cran: Jetons.CranDeClarte) -> Jetons.Theme {
        var fixe = theme
        (fixe.suivreLeSysteme, fixe.clarte) = (false, cran.position)
        return fixe
    }

    /// Les couleurs d'un thème quand le système est clair ou sombre, calculées une fois. Seul le dernier
    /// thème et sa version en Nuit sont gardés : le continu est infini, et un curseur en fait un nouveau
    /// à chaque pas.
    static func couleurs(_ theme: Jetons.Theme, systemeSombre: Bool) -> Jetons.Couleurs {
        let cle = Cle(theme: theme, sombre: systemeSombre)
        if let connues = calculees[cle] { return connues }
        if calculees.count > 8 { calculees = [:] }
        let neuves = Jetons.Nuancier.couleurs(theme, systemeSombre: systemeSombre)
        calculees[cle] = neuves
        return neuves
    }

    /// La teinte sous le verre d'une fenêtre qui prend le clavier (`UsageDuVerre.clavier`), claire ou
    /// sombre au dessin ; pleine quand le Mac refuse le verre.
    static var teinteDuVerre: NSColor {
        nsColor(theme) { couleurs, _ in UsageDuVerre.clavier.teinte(couleurs, verreRefuse: LisibiliteDuSysteme.shared.verreRefuse) }
    }

    private struct Cle: Hashable {
        let theme: Jetons.Theme
        // periphery:ignore - lue par le Hashable synthétisé : c'est la moitié de la clé
        let sombre: Bool
    }

    private static var calculees: [Cle: Jetons.Couleurs] = [:]

    /// Dynamique : la fermeture ne garde que les deux couleurs déjà calculées, jamais les préférences.
    fileprivate static func nsColor(_ theme: Jetons.Theme, _ valeur: (Jetons.Couleurs, Bool) -> Jetons.RVB) -> NSColor {
        let clair = NSColor(valeur(couleurs(theme, systemeSombre: false), false).couleur)
        let fonce = NSColor(valeur(couleurs(theme, systemeSombre: true), true).couleur)
        return NSColor(name: nil) { dessin in
            dessin.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? fonce : clair
        }
    }
}

extension Color {
    /// Un rôle du thème courant.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton) -> Color {
        Color(nsColor: ThemeCourant.nsColor(ThemeCourant.theme) { couleurs, _ in couleurs[keyPath: jeton] })
    }

    /// Un rôle lu à une clarté fixe : ce qui se pose sur l'image d'une carte du jeu s'écrit en Nuit.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton, en cran: Jetons.CranDeClarte) -> Color {
        ThemeCourant.couleurs(ThemeCourant.theme(en: cran), systemeSombre: false)[keyPath: jeton].couleur
    }

    /// Un rôle écrit sur l'image d'une carte du jeu (`surImage`, sous son voile sombre) : en Nuit ;
    /// ailleurs, celui du thème courant.
    @MainActor static func jeton(_ jeton: ThemeCourant.Jeton, surImage: Bool) -> Color {
        surImage ? Color.jeton(jeton, en: .nuit) : Color.jeton(jeton)
    }

    /// Le violet des positions suggérées : une couleur propre à Synfus (`Jetons.Propres`), claire ou
    /// sombre selon la clarté dessinée.
    @MainActor static var suggestionSynfus: Color {
        let theme = ThemeCourant.theme
        return Color(nsColor: ThemeCourant.nsColor(theme) { _, systemeSombre in
            Jetons.Propres.suggestionSynfus(sombre: Jetons.Nuancier.estSombre(theme.clarte(systemeSombre: systemeSombre)))
        })
    }
}

/// À poser sur la racine de chaque fenêtre, panneau, feuille et popover : les couleurs du thème
/// pour la trousse (`couleursSynseria`), et la teinte des contrôles du système, sans laquelle ils
/// prendraient l'accent de l'utilisateur. Un `ViewModifier`, pour que l'une et l'autre suivent le réglage.
struct RacineSynfus: ViewModifier {
    func body(content: Content) -> some View {
        // L'hôte sous les couleurs : la liste d'un sélecteur s'y ouvre, au-dessus de tout, avec elles.
        content.hoteDesSuggestions().tint(Color.jeton(\.accent)).themeSynseria(ThemeCourant.theme)
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
        // Émis avant l'écriture : la vue relit les préférences au redessin, qui vient après.
        Preferences.shared.$themeDeLApp.dropFirst().sink { [weak self] theme in
            self?.revision += 1
            // Sous les tests, pas d'application : les captures posent l'apparence de leurs fenêtres.
            let voulue = ThemeCourant.apparence(theme)
            if NSApp?.appearance?.name != voulue?.name { NSApp?.appearance = voulue }
        }.store(in: &abonnements)
    }
}
