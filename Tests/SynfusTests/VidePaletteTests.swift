import Foundation
import Testing
@testable import Synfus

/// Ce que dit la palette quand elle n'a aucune ligne.
@MainActor
struct VidePaletteTests {

    private func vide(carte: EtatCarte = .prete, requeteVide: Bool = false, filtre: FiltrePalette = .tout,
                      positionConnue: Bool = true, lectureAllumee: Bool = true, quetes: Bool = false,
                      ailleurs: Int = 0) -> VidePalette {
        VidePalette.de(carte: carte, requeteVide: requeteVide, filtre: filtre, positionConnue: positionConnue,
                       lectureAllumee: lectureAllumee, quetesEnChargement: quetes, ailleurs: ailleurs)
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

    @Test("Vide sous un filtre alors que « Tout » répond : la rangée y mène, ↵ aussi")
    func ailleurs() {
        let attendu = VidePalette.rienDansLeFiltre(.lieux, ailleurs: 12)
        #expect(vide(filtre: .lieux, ailleurs: 12) == attendu)
        #expect(attendu.entree == .toutVoir)
        #expect(vide(filtre: .lieux, ailleurs: 0) == .aucun)
        #expect(vide(filtre: .tout, ailleurs: 12) == .aucun)
    }

    @Test("Le chargement des quêtes passe avant le reste")
    func quetes() {
        #expect(vide(filtre: .quetes, quetes: true, ailleurs: 3) == .quetesEnChargement)
    }

    @Test("Le modèle compte les réponses de « Tout » quand le filtre est vide, et ↵ y passe")
    func modele() {
        var contexte = ContextePalette()
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        contexte.lieux = Carte.integree.lieux
        let modele = PaletteModele(contexte: contexte, requete: "lancer la session", filtre: .lieux)
        #expect(modele.entrees.isEmpty)
        guard case .rienDansLeFiltre(.lieux, let ailleurs)? = modele.vide else {
            Issue.record("pas de rangée « Tout »")
            return
        }
        #expect(ailleurs > 0)
        modele.valider()
        #expect(modele.filtre == .tout && !modele.entrees.isEmpty && modele.vide == nil)
    }
}
