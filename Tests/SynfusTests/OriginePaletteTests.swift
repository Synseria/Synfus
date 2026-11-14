import Testing
@testable import Synfus

/// La cause d'une position inconnue dans l'en-tête de la palette.
struct OriginePaletteTests {
    @Test("La position connue prime ; sinon lecture éteinte, autorisation manquante, ou pas encore lue")
    func causes() {
        #expect(OriginePalette.de(positionConnue: true, lectureAllumee: false, autorise: false) == .connue)
        #expect(OriginePalette.de(positionConnue: false, lectureAllumee: false, autorise: true) == .lectureEteinte)
        #expect(OriginePalette.de(positionConnue: false, lectureAllumee: true, autorise: false) == .sansAutorisation)
        #expect(OriginePalette.de(positionConnue: false, lectureAllumee: true, autorise: true) == .inconnue)
    }
}
