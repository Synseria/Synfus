/// Le numéro du tour de combat, par perso : le jeu ne le dit qu'à la frise,
/// l'aide le compte aux débuts de tour lus au bouton de combat
/// (`EtatCombat.nouveauTour`). Chaque perso joue une fois par tour : son
/// compte est le tour du combat. Un tour manqué (perso jamais devant) se
/// corrige à la main. Pur.
struct ToursCombat: Equatable, Sendable {
    private var tours: [String: Int] = [:]

    /// L'état de combat lu chez `perso`, et celui d'avant. Le placement ouvre
    /// un combat ; la sortie le ferme.
    mutating func combat(_ perso: String, avant: EtatCombat?, apres: EtatCombat) {
        switch apres {
        case .horsCombat: tours[perso] = nil
        case .placement: tours[perso] = 0
        case .monTour, .pasMonTour:
            if EtatCombat.nouveauTour(avant: avant, apres: apres) { tours[perso, default: 0] += 1 }
        }
    }

    /// Le tour en cours du perso ; `nil` hors combat ou avant son premier tour.
    func tour(_ perso: String) -> Int? {
        tours[perso].flatMap { $0 > 0 ? $0 : nil }
    }

    /// La parité dont dépendent le Comte et Kimbo : un seul endroit la décide.
    static func estImpair(_ tour: Int) -> Bool { tour % 2 == 1 }

    /// Un combat relancé sans placement lu : le décompte repart de zéro, comme
    /// au placement ; un perso hors combat n'a rien à remettre.
    mutating func recommencer(perso: String) {
        if tours[perso] != nil { tours[perso] = 0 }
    }

    /// Un tour de plus ou de moins, jamais sous le premier.
    mutating func corriger(_ pas: Int, perso: String) {
        tours[perso] = max((tours[perso] ?? 0) + pas, 1)
    }
}
