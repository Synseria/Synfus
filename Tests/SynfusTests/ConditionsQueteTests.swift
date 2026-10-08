import Testing
@testable import Synfus

/// Les conditions de départ des quêtes, sur des `startCriterion` de DofusDB.
struct ConditionsQueteTests {
    private typealias Metier = ConditionsQuete.Metier

    @Test("Classe, niveau, métier et alignement en ET de premier niveau", arguments: [
        ("Qf=2009&PG=13", ConditionsQuete(classe: 13)),
        ("Ps=1&Pa=78&PL>189&Qf=1889", ConditionsQuete(niveau: 190, camp: 1, alignement: 78)),
        ("Ps=2&Pr=18&Pa>19", ConditionsQuete(camp: 2, alignement: 20)),
        ("PL>19&PJ>26,39", ConditionsQuete(niveau: 20, metiers: [Metier(id: 26, niveau: 40)])),
        // Un métier sans identifiant lisible n'exige rien d'affichable.
        ("PL>179&PJ>a,199", ConditionsQuete(niveau: 180)),
    ])
    func conditions(critere: String, attendues: ConditionsQuete) {
        #expect(ConditionsQuete.lire(critere) == attendues)
    }

    @Test("Une alternative ou un groupe entre parenthèses n'exige rien", arguments: [
        "Qo>19250|Qf=2502",
        "(Qf=1841&PG=18&Pm=83886090)|(Qf=1677&PG=17&Pm=191106052)",
        "((Qf=934&Pm=76284416)|(Qf=935&Pm=76286989))&(Pj>26,99|Pj>2,99)&Qa!2458",
        "",
    ])
    func alternatives(critere: String) {
        #expect(ConditionsQuete.lire(critere) == ConditionsQuete())
    }

    @Test("Les conditions hors groupe restent, celles du groupe non")
    func horsGroupe() {
        let critere = "PL>49&((Pm=183764992&PG=1)|(Pm=183765004&PG=9))"
        #expect(ConditionsQuete.lire(critere) == ConditionsQuete(niveau: 50))
        #expect(ConditionsQuete.lire(nil) == ConditionsQuete())
    }
}
