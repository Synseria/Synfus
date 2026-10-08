import Testing
@testable import Synfus

/// Les listes des onglets de données : triées une fois par source, filtrées
/// selon la règle de la palette.
@MainActor
struct ListeCherchableTests {
    private let noms = ["Hôtel de vente des ressources", "Banque", "Atelier des forgerons"]

    @Test("Le tri ne repasse qu'à une nouvelle source, les champs qu'au premier filtre")
    func calculsUniques() {
        let liste = ListeCherchable<String>()
        var tris = 0
        var champs = 0
        func lire(_ source: Int, _ filtre: String) -> [String] {
            liste.elements(source: source, filtre: filtre,
                           trier: { tris += 1; return noms.sorted() },
                           champs: { champs += 1; return RecherchePalette.Champs(titre: $0) })
        }
        #expect(lire(1, "") == noms.sorted())
        #expect(lire(1, "") == noms.sorted())
        #expect(tris == 1 && champs == 0)
        #expect(lire(1, "ban") == ["Banque"])
        #expect(lire(1, "atel") == ["Atelier des forgerons"])
        #expect(tris == 1 && champs == noms.count)
        _ = lire(2, "ban")
        #expect(tris == 2 && champs == 2 * noms.count)
    }

    @Test("Le filtre suit la palette : début de mot, accents ignorés, surnoms des joueurs")
    func regleDeLaPalette() {
        let liste = ListeCherchable<String>()
        func filtrer(_ filtre: String) -> [String] {
            liste.elements(source: 0, filtre: filtre, trier: { noms }, champs: { RecherchePalette.Champs(titre: $0) })
        }
        #expect(filtrer("hotel") == ["Hôtel de vente des ressources"])
        #expect(filtrer("hdv") == ["Hôtel de vente des ressources"])
        #expect(filtrer("forge banque").isEmpty)
        #expect(filtrer("  ") == noms)
    }
}
