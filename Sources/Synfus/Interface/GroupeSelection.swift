import SwiftUI

// Au clavier, la sélection suit : le seul dessin de ce comportement, pour tout groupe à choix unique.

/// Les flèches qu'un groupe écoute.
enum FlecheGroupe: Equatable, Sendable { case haut, bas, gauche, droite }

/// Comment un groupe est rangé, donc quelles flèches le parcourent.
enum DispositionGroupe: Equatable, Sendable {
    case horizontale, verticale
    /// `colonnes` éléments par ligne, rangés de gauche à droite puis de haut en bas.
    case grille(colonnes: Int)

    /// Le rang où mène la flèche depuis `rang`, sans sortir du groupe ; `nil` si cette disposition n'écoute
    /// pas cette flèche. Sans rang courant, toute flèche écoutée choisit le premier élément.
    func voisin(depuis rang: Int?, parmi total: Int, _ fleche: FlecheGroupe) -> Int? {
        guard total > 0, let pas = pas(fleche) else { return nil }
        guard let rang else { return 0 }
        let vise = rang + pas
        // En grille, borner à la première ou dernière case ferait changer de colonne : on reste sur place.
        return (0..<total).contains(vise) ? vise : rang
    }

    private func pas(_ fleche: FlecheGroupe) -> Int? {
        switch (self, fleche) {
        case (.horizontale, .gauche), (.verticale, .haut), (.grille, .gauche): -1
        case (.horizontale, .droite), (.verticale, .bas), (.grille, .droite): 1
        case (.grille(let colonnes), .haut): -max(colonnes, 1)
        case (.grille(let colonnes), .bas): max(colonnes, 1)
        default: nil
        }
    }
}

private struct GroupeSelection<Id: Hashable>: ViewModifier {
    let titre: String
    @Binding var selection: Id
    let ordre: [Id]
    let disposition: DispositionGroupe
    let parent: Bool
    @FocusState private var auClavier: Bool
    @FocusedValue(\.groupeEnfantAuClavier) private var enfantAuClavier

    /// Un niveau parent garde sa voix tant qu'aucun groupe de la page n'a pris le clavier.
    private var aLaVoix: Bool { auClavier || (parent && enfantAuClavier != true) }

    func body(content: Content) -> some View {
        content
            .environment(\.groupeAuClavier, aLaVoix)
            .focusable()
            .focused($auClavier)
            .focusedValue(\.groupeEnfantAuClavier, parent ? nil : true)
            // Un clic sur un élément ne donne pas le focus (ils ne le prennent pas) : le groupe le prend.
            .simultaneousGesture(TapGesture().onEnded { auClavier = true })
            .focusEffectDisabled()
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow], phases: [.down, .repeat]) { touche in
                // ⌘ + flèche, ⌥ + flèche : aux gestes du système, pas au groupe. Une flèche porte
                // `.numericPad` : le test ne vise que les vrais modificateurs.
                guard touche.modifiers.isDisjoint(with: [.command, .option, .control, .shift]), let fleche = Self.fleche(touche.key),
                      let rang = disposition.voisin(depuis: ordre.firstIndex(of: selection), parmi: ordre.count, fleche)
                else { return .ignored }
                selection = ordre[rang]
                return .handled
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(titre)
    }

    private static func fleche(_ touche: KeyEquivalent) -> FlecheGroupe? {
        switch touche {
        case .leftArrow: .gauche
        case .rightArrow: .droite
        case .upArrow: .haut
        case .downArrow: .bas
        default: nil
        }
    }
}

extension View {
    /// Un groupe à choix unique (segment, barre latérale, tuiles) : Tab y entre et en sort une seule fois, les
    /// flèches déplacent la sélection elle-même, aucun anneau sur ses éléments (leur bordure est celle du
    /// choisi). Ses éléments se déclarent `elementDeGroupe()`. Un choix multiple n'en est pas un : ses
    /// éléments gardent leur anneau et Espace les coche.
    /// `parent` : le niveau au-dessus des autres groupes de la fenêtre (la barre latérale des réglages).
    func groupeSelection<Id: Hashable>(_ titre: String, selection: Binding<Id>, parmi ordre: [Id],
                                       disposition: DispositionGroupe = .horizontale, parent: Bool = false) -> some View {
        modifier(GroupeSelection(titre: titre, selection: selection, ordre: ordre, disposition: disposition,
                                 parent: parent))
    }

    /// Un élément d'un groupe à sélection qui suit : le groupe prend le focus, pas lui.
    func elementDeGroupe() -> some View { focusable(false) }
}

extension EnvironmentValues {
    /// Vrai hors de tout groupe, et dans le groupe qui a le clavier : son choix garde alors sa voix.
    @Entry var groupeAuClavier = true
}

extension FocusedValues {
    /// Un groupe de la page a le clavier : le niveau parent passe en gris.
    @Entry var groupeEnfantAuClavier: Bool?
}
