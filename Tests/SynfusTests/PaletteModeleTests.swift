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
}
