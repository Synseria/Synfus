import Foundation
import Testing
@testable import Synfus

/// Ce que dit la palette quand elle n'a aucune ligne.
@MainActor
struct VidePaletteTests {

    private func vide(carte: EtatCarte = .prete, requeteVide: Bool = false, filtre: FiltrePalette = .tout,
                      positionConnue: Bool = true, lectureAllumee: Bool = true, quetes: Bool = false) -> VidePalette {
        VidePalette.de(carte: carte, requeteVide: requeteVide, filtre: filtre, positionConnue: positionConnue,
                       lectureAllumee: lectureAllumee, quetesEnChargement: quetes)
    }

    @Test("Sans carte, rien tapé : chargement, ou carte indisponible après un échec — ↵ réessaie")
    func carte() {
        #expect(vide(carte: .chargement, requeteVide: true) == .carteEnChargement)
        #expect(vide(carte: .indisponible, requeteVide: true) == .carteIndisponible)
        #expect(VidePalette.carteIndisponible.entree == .reessayer)
        #expect(VidePalette.carteEnChargement.entree == nil)
        // « Aucun résultat » est réservé à une recherche qui ne trouve rien.
        #expect(vide(carte: .chargement, requeteVide: false) == .aucun)
    }

    @Test("L'état de la carte vient de ce qui est en place et d'un éventuel échec")
    func etatCarte() {
        #expect(EtatCarte.de(vide: true, echec: false) == .chargement)
        #expect(EtatCarte.de(vide: true, echec: true) == .indisponible)
        #expect(EtatCarte.de(vide: false, echec: true) == .prete)
    }

    @Test("Sous « Ici » sans position : la cause dit si la lecture est éteinte ou pas encore faite")
    func ici() {
        #expect(vide(filtre: .ici, positionConnue: false, lectureAllumee: false) == .iciSansLecture)
        #expect(vide(filtre: .ici, positionConnue: false, lectureAllumee: true) == .iciPasEncoreLu)
        #expect(vide(filtre: .ici, positionConnue: true) == .aucun)
    }

    @Test("Le chargement des quêtes passe avant le reste")
    func quetes() {
        #expect(vide(filtre: .quetes, quetes: true) == .quetesEnChargement)
    }
}
