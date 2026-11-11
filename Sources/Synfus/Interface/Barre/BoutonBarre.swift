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
