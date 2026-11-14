import Foundation

/// Les étapes déjà conclues d'une chasse, pour revenir en arrière sans
/// ressaisir le départ. Pur : le modèle y note ce qu'il avait avant chaque étape.
struct HistoriqueChasse: Equatable {
    /// L'état d'une étape avant sa recherche : de quoi la rouvrir telle quelle.
    struct Reprise: Equatable {
        let departX: Int?
        let departY: Int?
        let direction: Direction
        let cible: EtapeChasse.Cible
        /// Sa place parmi les indices lus à l'écran, s'il y en avait un : conclure l'en retire.
        var rangLu: Int?

        /// Ce que la reprise remet : jamais un départ connu remplacé par du vide
        /// (une étape sans départ, le Phorreur, a pu être suivie d'un départ tapé),
        /// et l'indice lu retrouve sa pastille.
        func rouverture(departX courantX: Int?, departY courantY: Int?, lues: [EtapeChasse.Cible]) -> Rouverture {
            var lues = lues
            if let rangLu, !lues.contains(cible) { lues.insert(cible, at: min(rangLu, lues.count)) }
            return Rouverture(departX: departX ?? courantX, departY: departY ?? courantY, lues: lues)
        }
    }

    struct Rouverture: Equatable {
        let departX: Int?
        let departY: Int?
        let lues: [EtapeChasse.Cible]
    }

    private var etapes: [Reprise] = []

    var vide: Bool { etapes.isEmpty }

    mutating func noter(_ reprise: Reprise) { etapes.append(reprise) }

    /// L'étape conclue en dernier, retirée de l'historique.
    mutating func reprendre() -> Reprise? { etapes.popLast() }
}
