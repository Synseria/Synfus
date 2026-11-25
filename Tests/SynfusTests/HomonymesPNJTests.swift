import Testing
@testable import Synfus

/// Les PNJ homonymes de la même sous-zone : une seule ligne de la palette.
struct HomonymesPNJTests {
    private func passage(_ x: Int, _ y: Int, _ quetes: [Int], sousZone: Int? = 1, carte: Int? = nil) -> PNJ.Passage {
        PNJ.Passage(position: .init(x: x, y: y), carte: carte, sousZone: sousZone, quetes: quetes)
    }

    @Test("Même nom, même sous-zone : un seul PNJ, toutes ses positions, une case commune réunie")
    func fusion() throws {
        let pnjs = [PNJ(id: 11, noms: ["fr": "Roi Nidas"], passages: [passage(-4, -5, [2]), passage(-5, -5, [3])]),
                    PNJ(id: 10, noms: ["fr": "roi nidas"], passages: [passage(-5, -5, [1], carte: 7)]),
                    PNJ(id: 12, noms: ["fr": "Léonard"], passages: [passage(-5, -5, [4])])]
        let fusionnes = HomonymesPNJ.fusionner(pnjs, langue: .fr)
        #expect(fusionnes.map(\.ids) == [[10, 11], [12]])
        let roi = try #require(fusionnes.first)
        #expect(roi.pnj.id == 10 && roi.cles == ["pnj:10", "pnj:11"])
        // La case citée deux fois passe devant, ses quêtes réunies, sa carte gardée.
        #expect(roi.pnj.passages.map(\.position) == [.init(x: -5, y: -5), .init(x: -4, y: -5)])
        #expect(roi.pnj.passages[0].quetes == [1, 3] && roi.pnj.passages[0].carte == 7)
        #expect(HomonymesPNJ.fusionne(de: 11, parmi: pnjs, langue: .fr) == roi)
    }

    @Test("Une autre sous-zone, ou aucune : chacun reste seul")
    func pasDeFusion() {
        let pnjs = [PNJ(id: 1, noms: ["fr": "Garde"], passages: [passage(0, 0, [1], sousZone: 1)]),
                    PNJ(id: 2, noms: ["fr": "Garde"], passages: [passage(5, 5, [2], sousZone: 2)]),
                    PNJ(id: 3, noms: ["fr": "Garde"], passages: [passage(0, 0, [3], sousZone: nil)]),
                    PNJ(id: 4, noms: ["fr": "Garde"], passages: [passage(0, 0, [4], sousZone: nil)])]
        #expect(HomonymesPNJ.fusionner(pnjs, langue: .fr).map(\.ids) == [[1], [2], [3], [4]])
    }

    @Test("Dans la palette : une ligne « Roi Nidas » à trois positions, qui se déplient toutes")
    func palette() throws {
        var contexte = try ContexteNidas.contexte()
        let rois = RecherchePalette.entrees("roi nidas", contexte, filtre: .pnj).filter { $0.titre == "Roi Nidas" }
        #expect(rois.count == 1)
        let roi = try #require(rois.first)
        #expect(roi.compte == L("palette.pnj.positions", nombre: 3, 3) && roi.effet == .positions(10))
        #expect(RecherchePalette.positions(de: 10, contexte).count == 3)
        // Le favori posé sur le PNJ absorbé vaut pour la ligne, et la garde sur l'Accueil.
        contexte.favoris = ["pnj:11"]
        contexte.etiquettes = ["pnj:11": "Roi"]
        let accueil = RecherchePalette.entrees("", contexte)
        #expect(accueil.contains { $0.id == "pnj:10" && $0.favori && $0.etiquette == "Roi" && $0.cle == "pnj:11" })
    }
}
