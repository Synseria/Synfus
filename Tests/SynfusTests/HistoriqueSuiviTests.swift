import Foundation
import Testing
@testable import Synfus

/// Les lectures du suivi par perso : les quêtes sorties du suivi, et où en
/// est chaque perso.
struct HistoriqueSuiviTests {
    /// Une lecture : chaque quête et ses lignes d'objectifs, l'en-tête.
    private func lu(_ quetes: [(id: Int, lignes: Int)], entete: Int = 1, etapes: [Int: Int] = [:]) -> SuiviQuetes.Lu {
        SuiviQuetes.Lu(reconnues: quetes.map { .init(id: $0.id, etape: etapes[$0.id]) },
                       lignes: quetes.map(\.lignes), entete: entete)
    }

    private func disparues(_ avant: SuiviQuetes.Lu, _ apres: SuiviQuetes.Lu) -> Set<Int> {
        HistoriqueSuivi.disparues(avant: avant, apres: apres)
    }

    @Test("Une quête qui manque entre deux quêtes encore lues est sortie du suivi")
    func entreDeux() {
        let avant = lu([(1, 2), (2, 2), (3, 1)])
        #expect(disparues(avant, lu([(1, 2), (3, 1)])) == [2])
        // Une nouvelle quête au-dessus n'y change rien : la suivante est lue.
        #expect(disparues(avant, lu([(9, 2), (1, 2), (3, 1)])) == [2])
    }

    @Test("La dernière quête manque : sortie seulement si rien n'a pu la pousser hors de la zone")
    func derniere() {
        let avant = lu([(1, 2), (2, 2)])
        #expect(disparues(avant, lu([(1, 2)])) == [2])
        #expect(disparues(avant, lu([(1, 1)])) == [2])
        // Une quête nouvelle, une voisine plus longue, un en-tête plus haut :
        // elle est peut-être juste sous la zone.
        #expect(disparues(avant, lu([(9, 1), (1, 2)])).isEmpty)
        #expect(disparues(avant, lu([(1, 4)])).isEmpty)
        #expect(disparues(avant, lu([(1, 2)], entete: 2)).isEmpty)
    }

    @Test("Un titre mal lu range ses objectifs sous la voisine, ou dans l'en-tête : rien n'est proposé")
    func titreMalLu() {
        #expect(disparues(lu([(1, 2), (2, 2), (3, 1)]), lu([(1, 4), (3, 1)])).isEmpty)
        #expect(disparues(lu([(1, 2), (3, 1)]), lu([(3, 1)], entete: 3)).isEmpty)
        #expect(disparues(lu([(1, 2), (3, 1)]), lu([(3, 1)])) == [1])
    }

    @Test("Rien de reconnu, ou les quêtes dans un autre ordre : la lecture ne dit rien des absentes")
    func illisible() {
        let avant = lu([(1, 2), (2, 2), (3, 1)])
        #expect(disparues(avant, lu([])).isEmpty)
        #expect(disparues(avant, lu([(3, 1), (1, 2)])).isEmpty)
    }

    @Test("Chaque perso a ses lectures : une quête absente du suivi d'un autre n'est pas sortie")
    func parPerso() {
        var historique = HistoriqueSuivi()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        #expect(historique.noter(lu([(1, 2), (2, 2)], etapes: [1: 3]), perso: "Aeryn", date: t0).isEmpty)
        #expect(historique.noter(lu([(1, 2)], etapes: [1: 3]), perso: "Nova", date: t0).isEmpty)
        #expect(historique.persos(1, etape: 3, seule: false, maintenant: t0).map(\.perso) == ["Aeryn", "Nova"])
        #expect(historique.persos(1, etape: 2, seule: false, maintenant: t0).isEmpty)
        // Quête d'une seule étape : le suivi ne la désigne pas, elle compte pour la première.
        #expect(historique.persos(2, etape: 0, seule: true, maintenant: t0).map(\.perso) == ["Aeryn"])
        #expect(historique.persos(2, etape: 0, seule: false, maintenant: t0).isEmpty)
        // Aeryn a fini la 2 : elle sort de son suivi et de ses étapes.
        #expect(historique.noter(lu([(1, 2)], etapes: [1: 4]), perso: "Aeryn", date: t0 + 60) == [2])
        #expect(historique.persos(2, etape: 0, seule: true, maintenant: t0 + 60).isEmpty)
        #expect(historique.persos(1, etape: 4, seule: false, maintenant: t0 + 60).map(\.perso) == ["Aeryn"])
        // Passé un jour, une lecture ne dit plus où en est le perso.
        #expect(historique.persos(1, etape: 3, seule: false, maintenant: t0 + HistoriqueSuivi.memoire).isEmpty)
    }

    @Test("Au survol : qui, et depuis quand")
    @MainActor
    func depuisQuand() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        func lu(il secondes: TimeInterval) -> String {
            QueteVue.lu(.init(perso: "Aeryn", etape: 0, date: t0), maintenant: t0 + secondes)
        }
        #expect(lu(il: 20) == L("quete.persos.luALInstant", "Aeryn"))
        #expect(lu(il: 5 * 60 + 10) == L("quete.persos.lu", "Aeryn", 5))
        #expect(lu(il: 3 * 3600 + 120) == L("quete.persos.luHeures", "Aeryn", 3))
    }
}
