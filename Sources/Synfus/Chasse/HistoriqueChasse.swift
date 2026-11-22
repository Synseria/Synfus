import Foundation

/// Les étapes déjà conclues d'une chasse, pour revenir en arrière sans
/// ressaisir le départ. Pur : le modèle y note ce qu'il avait avant chaque étape.
struct HistoriqueChasse: Equatable {
    /// L'état d'une étape avant sa recherche : de quoi la rouvrir telle quelle.
    /// Une carte atteinte à une étape.
    struct Carte: Equatable, Sendable {
        let x: Int
        let y: Int
    }

    struct Reprise: Equatable {
        let departX: Int?
        let departY: Int?
        let direction: Direction
        let cible: EtapeChasse.Cible
        /// La carte atteinte à cette étape, si la recherche l'a trouvée.
        var cibleAtteinte: Carte? = nil
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
    /// Les indices du panneau de chasse en cours à l'écran : une étape affichée
    /// n'a de sens que si son indice y est — un autre panneau est une chasse neuve.
    private var ciblesDeLaChasse: [EtapeChasse.Cible] = []

    var vide: Bool { etapes.isEmpty }

    /// Toutes les étapes notées, de la première à la dernière — pour l'historique affiché.
    var toutes: [Reprise] { etapes }

    /// Les étapes notées **de la chasse en cours** : celles dont l'indice est
    /// dans le panneau lu à l'écran. Celles d'une chasse d'avant sont oubliées.
    var deLaChasseEnCours: [Reprise] { etapes.filter { ciblesDeLaChasse.contains($0.cible) } }

    /// Les indices lus à l'écran à ce scan. Un panneau qui ne contient aucun
    /// indice connu est une **chasse neuve** : l'historique repart à zéro,
    /// on n'y garde que la chasse en cours.
    mutating func lire(_ lues: [EtapeChasse.Cible]) {
        if !lues.isEmpty, !ciblesDeLaChasse.isEmpty, !lues.contains(where: { ciblesDeLaChasse.contains($0) }) {
            etapes = []
            ciblesDeLaChasse = []
        }
        for cible in lues where !ciblesDeLaChasse.contains(cible) { ciblesDeLaChasse.append(cible) }
    }

    mutating func noter(_ reprise: Reprise) { etapes.append(reprise) }

    /// L'étape conclue en dernier, retirée de l'historique.
    mutating func reprendre() -> Reprise? { etapes.popLast() }

    /// Garde les étapes jusqu'à l'index `i` inclus — pour rouvrir une étape
    /// passée choisie dans le menu horloge.
    mutating func tronquer(jusqua i: Int) {
        guard i < etapes.count - 1 else { return }
        etapes.removeLast(etapes.count - 1 - i)
    }
}
