import Testing
@testable import Synfus

/// Les gestes du modèle de la palette, hors de l'app (contexte imposé).
@MainActor
struct PaletteModeleTests {
    @Test("Le tri se choisit dans le menu ou passe au suivant (⌘T), en boucle")
    func tri() {
        let modele = PaletteModele(contexte: ContextePalette())
        #expect(modele.tri == .auto)
        modele.choisirTri(.alphabetique)
        #expect(modele.tri == .alphabetique)
        modele.triSuivant()
        #expect(modele.tri == .type)
        modele.triSuivant()
        #expect(modele.tri == .auto)
    }

    @Test("Le pied montre le texte que ↵ copie, trajet compris ; rien pour ce qui ne copie pas")
    func texteDeLaSelection() {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -30, y: -40, zone: nil)
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        let trajet = PaletteModele(contexte: contexte, requete: "6,8")
        #expect(trajet.texteDeLaSelection == "/zaap 5,7 ; /travel 6,8")
        let geste = PaletteModele(contexte: contexte, requete: "ranger les fenetres")
        #expect(geste.entrees.first?.effet == .action(.rangerFenetres))
        #expect(geste.texteDeLaSelection == nil)
        #expect(PaletteModele(contexte: contexte, requete: "zzzzzz").texteDeLaSelection == nil)
    }
}
