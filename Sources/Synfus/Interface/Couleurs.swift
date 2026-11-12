import AppKit
import Combine
import Observation
import SwiftUI

/// Les couleurs de Synfus : le seul point de passage vers les jetons du design system (`Jetons`).
/// L'utilisateur ne choisit que la couleur de l'app et la teinte des fonds (Réglages ▸ Apparence) ;
/// chaque nom ci-dessous est un jeton du thème qui en résulte. Une couleur est dynamique : clair ou
/// sombre se décide au dessin, dans une vue SwiftUI comme dans un panneau. Lue dans un `body`, elle
/// abonne la vue au réglage : un changement de couleur se redessine partout, sans rebâtir les vues.
/// `Color.accentColor` n'en est pas : il rend l'accent système de l'utilisateur (`JetonsTests`).
@MainActor
enum Couleurs {
    /// Ce qui détermine tous les jetons.
    struct Reglage: Hashable, Sendable {
        var couleur = Jetons.couleurParDefaut
        var fonds = Jetons.fondsParDefaut
    }

    static var reglage: Reglage {
        _ = Suivi.partage.revision
        let prefs = Preferences.shared
        return Reglage(couleur: prefs.couleurDeLApp, fonds: prefs.fondsDeLApp)
    }

    static func theme(_ apparence: Jetons.Apparence, _ reglage: Reglage = Couleurs.reglage) -> Jetons.Theme {
        if let memoire, memoire.reglage == reglage { return apparence == .clair ? memoire.clair : memoire.sombre }
        let clair = Jetons.theme(reglage.couleur, fonds: reglage.fonds, .clair)
        let sombre = Jetons.theme(reglage.couleur, fonds: reglage.fonds, .sombre)
        memoire = (reglage, clair, sombre)
        return apparence == .clair ? clair : sombre
    }

    private static var memoire: (reglage: Reglage, clair: Jetons.Theme, sombre: Jetons.Theme)?

    /// Un jeton du réglage courant, dynamique : la fermeture ne garde que les deux couleurs déjà
    /// calculées, jamais les préférences.
    static func nsColor(_ jeton: KeyPath<Jetons.Theme, Jetons.RVB>) -> NSColor {
        let reglage = Couleurs.reglage
        let (clair, sombre) = (theme(.clair, reglage)[keyPath: jeton].nsColor, theme(.sombre, reglage)[keyPath: jeton].nsColor)
        return NSColor(name: nil) { dessin in
            dessin.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? sombre : clair
        }
    }

    static func couleur(_ jeton: KeyPath<Jetons.Theme, Jetons.RVB>) -> Color { Color(nsColor: nsColor(jeton)) }

    // MARK: - La couleur de l'app

    /// Trait, voile, aplat de ce qui est choisi : le texte posé dessus est `encreSurPrimaire`.
    static var primaire: Color { couleur(\.primaire) }
    /// Aplat de ce qui est choisi (voix teintée) : le texte posé dessus est `primaireEncre`.
    static var primaireFond: Color { couleur(\.primaireFond) }
    /// La couleur de l'app quand elle s'écrit : lisible sur le fond de la fenêtre.
    static var primaireEncre: Color { couleur(\.primaireEncre) }
    static var encreSurPrimaire: Color { couleur(\.encreSurPrimaire) }

    // MARK: - La secondaire et les états

    /// « Regarde ici » : étiquette, favori, surlignage. Jamais un état.
    static var safran: Color { couleur(\.safran) }
    static var safranTexte: Color { couleur(\.safranTexte) }
    static var safranFond: Color { couleur(\.safranFond) }
    /// Ce que Synfus suggère (« tu y es »), propre à l'app.
    static var suggestionSynfus: Color { couleur(\.suggestionSynfus) }
    static var alerte: Color { couleur(\.alerte) }
    static var succes: Color { couleur(\.succes) }
    static var danger: Color { couleur(\.danger) }

    // MARK: - Les neutres

    static var fenetre: Color { couleur(\.fenetre) }
    static var surface: Color { couleur(\.surface) }
    static var creux: Color { couleur(\.creux) }
    static var filet: Color { couleur(\.filet) }
    static var encre: Color { couleur(\.encre) }
    static var encreSecondaire: Color { couleur(\.encreSecondaire) }
    static var encreTertiaire: Color { couleur(\.encreTertiaire) }
    /// Contour d'un champ ou d'un bouton secondaire (≥ 3:1 sur `surface`).
    static var contourControle: Color { couleur(\.contourControle) }
    /// Voile d'un élément survolé, puis pressé.
    static var survol: Color { couleur(\.survol) }
    static var pression: Color { couleur(\.pression) }
    /// Le texte posé sur `safran` : le bleu nuit du thème, lisible en clair comme en sombre.
    static var encreSurSafran: Color { couleur(\.nuitProfond) }
}

/// Le témoin de changement des couleurs : `Preferences` est un `ObservableObject`, que SwiftUI ne
/// suit pas depuis une lecture statique. Lire `revision` dans un `body` suffit à l'abonner.
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

extension Jetons.RVB {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: opacite)
    }
}

// MARK: - Ce qui s'enregistre

extension Jetons.Couleur {
    /// `jade`, ou `teinte:123` pour « Autre… ».
    var ecrit: String {
        switch self {
        case .prereglage(let p): p.rawValue
        case .teinte(let t): "teinte:\(t)"
        }
    }

    /// Une valeur illisible, ou une teinte que « Autre… » refuserait, n'est pas une couleur.
    init?(ecrit: String) {
        if let p = Jetons.Prereglage(rawValue: ecrit) {
            self = .prereglage(p)
        } else if ecrit.hasPrefix("teinte:"), let t = Int(ecrit.dropFirst(7)), Jetons.teinteAcceptee(t) {
            self = .teinte(((t % 360) + 360) % 360)
        } else {
            return nil
        }
    }
}

extension Jetons.Fonds {
    /// `primaire`, `nuit`, `neutre`, ou `teinte:123`.
    var ecrit: String {
        switch self {
        case .primaire: "primaire"
        case .nuit: "nuit"
        case .neutre: "neutre"
        case .teinte(let t): "teinte:\(t)"
        }
    }

    init?(ecrit: String) {
        switch ecrit {
        case "primaire": self = .primaire
        case "nuit": self = .nuit
        case "neutre": self = .neutre
        default:
            guard ecrit.hasPrefix("teinte:"), let t = Int(ecrit.dropFirst(7)) else { return nil }
            self = .teinte(((t % 360) + 360) % 360)
        }
    }
}
