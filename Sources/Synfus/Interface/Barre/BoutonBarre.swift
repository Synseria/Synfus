// Les boutons de la barre flottante après les persos, dans leur ordre d'affichage (pur).

/// Un bouton masquable de la barre. L'engrenage n'en est pas : c'est quand
/// rien ne marche qu'on cherche les réglages.
///
/// La valeur brute est celle de la sauvegarde (`boutonsMasques`) : à ne jamais
/// renommer.
enum BoutonBarre: String, CaseIterable, Sendable {
    // Les panneaux de jeu d'abord, du plus servi au plus rare, puis les
    // fenêtres ; le même ordre que le menu de la barre de menus.
    case quetes, boss, chasse, rangement, palette, passageAuto

    /// Les boutons montrés, dans l'ordre de la barre.
    static func affiches(sauf masques: Set<BoutonBarre>) -> [BoutonBarre] {
        allCases.filter { !masques.contains($0) }
    }

    /// Le dessin de l'outil, le même dans la barre, le menu, les réglages et
    /// l'en-tête de son panneau. Le passage automatique, lui, change de dessin
    /// éteint : voir `BarView`.
    var symbole: String {
        switch self {
        case .quetes: "scroll"
        case .boss: "scope"
        case .chasse: "flag.checkered"
        case .rangement: "rectangle.3.group"
        case .palette: "command"
        case .passageAuto: "bolt.fill"
        }
    }

    /// Le raccourci qui ouvre l'outil, s'il en a un.
    @MainActor
    func raccourci(_ prefs: Preferences) -> HotKey? {
        switch self {
        case .quetes: prefs.quetesHotKey
        case .boss: prefs.bossHotKey
        case .chasse: prefs.chasseHotKey
        case .rangement: prefs.arrangeHotKey
        case .palette: prefs.paletteHotKey
        case .passageAuto: prefs.toggleAutoFocus
        }
    }

    /// Une forme pour les six infobulles : le nom, puis la touche au bout quand elle existe.
    /// `nom` remplace le libellé quand l'outil dit son état (passage automatique).
    func infobulle(touche: String?, nom: String? = nil) -> String {
        let titre = nom ?? libelle
        return touche.map { "\(titre)  \($0)" } ?? titre
    }

    var libelle: String {
        switch self {
        case .quetes: L("barre.bouton.quetes")
        case .boss: L("barre.bouton.boss")
        case .chasse: L("barre.bouton.chasse")
        case .rangement: L("barre.bouton.rangement")
        case .palette: L("barre.bouton.palette")
        case .passageAuto: L("barre.bouton.passageAuto")
        }
    }
}
