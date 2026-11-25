import Testing
@testable import Synfus

/// Les combinaisons élémentaires de l'Huppermage et la règle qui montre leur aide.
struct CombinaisonsHuppermageTests {
    @Test("Chaque paire d'éléments différents a sa combinaison, dans les deux ordres")
    func paires() {
        let elements = CombinaisonsHuppermage.elements
        for a in elements {
            for b in elements where a != b {
                #expect(CombinaisonsHuppermage.combinaison(a, b) != nil)
                #expect(CombinaisonsHuppermage.combinaison(a, b) == CombinaisonsHuppermage.combinaison(b, a))
            }
            #expect(CombinaisonsHuppermage.combinaison(a, a) == nil)
        }
        #expect(CombinaisonsHuppermage.combinaison(.terre, .feu) == .eruption)
        #expect(CombinaisonsHuppermage.combinaison(.air, .terre) == .assechement)
        #expect(Set(CombinaisonsHuppermage.Combinaison.allCases.map(\.paire)).count == 6)
    }

    @Test("Montrée seulement devant un Huppermage en combat, Dofus devant, réglage allumé")
    func montree() {
        #expect(CombinaisonsHuppermage.montree(reglage: true, classe: "huppermage", enCombat: true, dofusDevant: true))
        #expect(!CombinaisonsHuppermage.montree(reglage: true, classe: "huppermage", enCombat: false, dofusDevant: true))
        #expect(!CombinaisonsHuppermage.montree(reglage: true, classe: "iop", enCombat: true, dofusDevant: true))
        #expect(!CombinaisonsHuppermage.montree(reglage: false, classe: "huppermage", enCombat: true, dofusDevant: true))
        #expect(!CombinaisonsHuppermage.montree(reglage: true, classe: "huppermage", enCombat: true, dofusDevant: false))
    }
}
