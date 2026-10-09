import Foundation
import Testing
@testable import Synfus

/// L'ordre le plus court des objectifs ouverts ensemble, et le coût d'un
/// trajet copié, zaap compris.
struct TourneeTests {
    private static func cases(_ liste: [(Int, Int, Int)]) -> [Int: (x: Int, y: Int)] {
        Dictionary(uniqueKeysWithValues: liste.map { ($0.0, (x: $0.1, y: $0.2)) })
    }

    private func ordre(depuis depart: (x: Int, y: Int), _ cases: [Int: (x: Int, y: Int)], ids: [Int]) -> [Int] {
        Tournee.ordre(ids, depuisLeDepart: { ItineraireZaap.distance(depart, cases[$0]!) },
                      entre: { ItineraireZaap.distance(cases[$0]!, cases[$1]!) })
    }

    @Test("Le plus court chemin, pas le plus proche d'abord")
    func plusCourt() {
        // Sur une ligne, depuis 0 : 1 en 1, 2 en -2, 3 en 4. Le plus proche
        // d'abord coûte 1 + 3 + 6 = 10 ; par 2 d'abord, 2 + 3 + 3 = 8.
        let cases = Self.cases([(1, 1, 0), (2, -2, 0), (3, 4, 0)])
        #expect(ordre(depuis: (0, 0), cases, ids: [1, 2, 3]) == [2, 1, 3])
        // Le lointain en dernier, sans aller-retour.
        let loin = Self.cases([(1, -10, 0), (2, 1, 0), (3, 2, 0)])
        #expect(ordre(depuis: (0, 0), loin, ids: [1, 2, 3]) == [2, 3, 1])
    }

    @Test("Le dernier calcul gardé : rendu tel quel sous la même clé, refait sous une autre")
    func dernierCalcul() {
        var gardee = DernierCalcul<[Int], [Int]>()
        var calculs = 0
        func ordre(_ cle: [Int]) -> [Int] { gardee.valeur(pour: cle) { calculs += 1; return cle.reversed() } }
        #expect(ordre([1, 2]) == [2, 1] && ordre([1, 2]) == [2, 1] && calculs == 1)
        #expect(ordre([1, 3]) == [3, 1] && calculs == 2)
        // Seul le dernier est gardé : revenir à une clé d'avant la refait.
        #expect(ordre([1, 2]) == [2, 1] && calculs == 3)
    }

    @Test("Un objectif : rien à ordonner ; à coût égal, l'ordre donné")
    func bords() {
        let cases = Self.cases([(1, 1, 0), (2, -1, 0)])
        #expect(ordre(depuis: (0, 0), cases, ids: [1]) == [1])
        #expect(ordre(depuis: (0, 0), cases, ids: [2, 1]) == [2, 1])
        #expect(ordre(depuis: (0, 0), cases, ids: [1, 2]) == [1, 2])
    }

    @Test("Au-delà des permutations, de proche en proche")
    func nombreux() {
        let liste = (1...9).map { ($0, $0 * 2, 0) }
        let cases = Self.cases(liste)
        #expect(ordre(depuis: (0, 0), cases, ids: Array((1...9).reversed())) == Array(1...9))
    }

    @Test("Le coût d'un trajet passe par le zaap quand il épargne assez de cartes")
    func coutZaap() {
        let zaap = Zaap(5, 7, noms: ["fr": "Coin des Bouftous"])
        #expect(ItineraireZaap.cartes(depuis: (-30, -40), vers: (6, 8), zaap: zaap, gainMinimal: 5) == 2)
        #expect(ItineraireZaap.cartes(depuis: (6, 4), vers: (6, 8), zaap: zaap, gainMinimal: 5) == 4)
        #expect(ItineraireZaap.cartes(depuis: (-30, -40), vers: (6, 8), zaap: nil, gainMinimal: 5) == 84)
        #expect(ItineraireZaap.zaapUtile(depuis: (6, 4), vers: (6, 8), zaap: zaap, gainMinimal: 2) == zaap)
        #expect(ItineraireZaap.zaapUtile(depuis: (6, 4), vers: (6, 8), zaap: zaap, gainMinimal: 3) == nil)
    }
}
