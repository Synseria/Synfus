import Foundation

/// L'ordre le plus court pour passer par plusieurs cases quand l'ordre ne
/// compte pas — des objectifs ouverts ensemble. Pur : le coût de chaque
/// trajet est donné (`ItineraireZaap.cartes`, zaaps compris), d'où l'on part
/// comme d'une case à l'autre ; on ne revient pas au départ.
enum Tournee {
    /// Jusque-là, toutes les permutations (5 040 à sept) ; au-delà, le plus
    /// proche, de proche en proche.
    static let exhaustifJusqua = 7

    /// `etapes` : des identifiants ; `depuisLeDepart(e)` et `entre(a, b)` : le
    /// coût d'y aller. À coût égal, l'ordre donné.
    static func ordre(_ etapes: [Int], depuisLeDepart: (Int) -> Int, entre: (Int, Int) -> Int) -> [Int] {
        guard etapes.count > 1 else { return etapes }
        guard etapes.count <= exhaustifJusqua else { return auPlusProche(etapes, depuisLeDepart, entre) }
        var meilleur: (cout: Int, ordre: [Int])?
        var chemin: [Int] = []
        func explorer(_ restantes: [Int], cout: Int) {
            if let meilleur, cout >= meilleur.cout { return }
            guard !restantes.isEmpty else { meilleur = (cout, chemin); return }
            for (rang, suivante) in restantes.enumerated() {
                let pas = chemin.last.map { entre($0, suivante) } ?? depuisLeDepart(suivante)
                chemin.append(suivante)
                var reste = restantes
                reste.remove(at: rang)
                explorer(reste, cout: cout + pas)
                chemin.removeLast()
            }
        }
        explorer(etapes, cout: 0)
        return meilleur?.ordre ?? etapes
    }

    private static func auPlusProche(_ etapes: [Int], _ depuisLeDepart: (Int) -> Int,
                                     _ entre: (Int, Int) -> Int) -> [Int] {
        var restantes = etapes
        var ordre: [Int] = []
        while !restantes.isEmpty {
            let couts = restantes.map { e in ordre.last.map { entre($0, e) } ?? depuisLeDepart(e) }
            let rang = couts.indices.min { couts[$0] < couts[$1] }!
            ordre.append(restantes.remove(at: rang))
        }
        return ordre
    }
}
