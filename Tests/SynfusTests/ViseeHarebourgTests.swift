import CoreGraphics
import Testing
@testable import Synfus

@Suite("Visée contre le Comte Harebourg")
struct ViseeHarebourgTests {
    private typealias Case = GrilleIso.Case
    private typealias Confusion = Harebourg.Confusion

    private func estimation(_ confusion: Confusion, voisine: Confusion? = nil) -> SuiviConfusion.Estimation {
        SuiviConfusion.Estimation(confusion: confusion, source: .vie(pourcentage: 50), voisine: voisine,
                                  coups: 0, enTour: true)
    }

    @Test("Un quart horaire : visée en haut à droite du lanceur, le sort tombe en bas à droite")
    func unQuart() {
        let lanceur = Case(4, 7)
        let arrivees = ViseeHarebourg.arrivees(survolee: Case(4, 5), lanceur: lanceur, estimation: estimation(.horaire))
        #expect(arrivees == [.init(position: Case(6, 7), principale: true)])
    }

    @Test("Le demi-tour renvoie la case symétrique ; sans confusion, la case survolée")
    func demiTourEtAucune() {
        let lanceur = Case(0, 0)
        #expect(ViseeHarebourg.arrivees(survolee: Case(3, -1), lanceur: lanceur, estimation: estimation(.demiTour))
                == [.init(position: Case(-3, 1), principale: true)])
        #expect(ViseeHarebourg.arrivees(survolee: Case(3, -1), lanceur: lanceur, estimation: estimation(.aucune))
                == [.init(position: Case(3, -1), principale: true)])
    }

    @Test("À une limite de tranche, la voisine s'ajoute — si elle tombe ailleurs")
    func voisine() {
        let lanceur = Case(1, 1)
        let deux = ViseeHarebourg.arrivees(survolee: Case(1, -1), lanceur: lanceur,
                                           estimation: estimation(.horaire, voisine: .contreHoraire))
        #expect(deux == [.init(position: Case(3, 1), principale: true), .init(position: Case(-1, 1), principale: false)])
        // Survoler le lanceur : toute rotation y retombe, une seule arrivée.
        #expect(ViseeHarebourg.arrivees(survolee: lanceur, lanceur: lanceur,
                                        estimation: estimation(.horaire, voisine: .demiTour)).count == 1)
    }

    @Test("Le pivot ne bouge jamais, quelle que soit la confusion")
    func pivotImmobile() {
        let lanceur = Case(-2, 5)
        for quarts in 0..<4 {
            #expect(ViseeHarebourg.arrivees(survolee: lanceur, lanceur: lanceur,
                                            estimation: estimation(Confusion(quarts: quarts))).first?.position == lanceur)
        }
    }

    @Test("Marquer et relire, perso par perso")
    func marques() {
        var visee = ViseeHarebourg()
        visee.marquer(Case(2, 3), perso: "Syl-Ami")
        visee.marquer(Case(0, 0), perso: "Cob")
        visee.marquer(Case(1, 3), perso: "Syl-Ami")
        #expect(visee.lanceur("Syl-Ami") == Case(1, 3))
        #expect(visee.lanceur("Cob") == Case(0, 0))
        #expect(visee.lanceur("Bram") == nil)
    }

    // MARK: - Quand dessiner

    private var grille: GrilleIso {
        GrilleIso(origine: CGPoint(x: 0.5, y: 0.5), demiLargeur: 0.043, rapport: 2000.0 / 1234)
    }

    private var active: ViseeHarebourg.Entrees {
        ViseeHarebourg.Entrees(reglage: true, harebourg: true, panneauMontre: true, sonTour: true, grille: grille,
                               contenu: CGSize(width: 2000, height: 1234), lanceur: Case(0, 0), confusion: true,
                               pointeurSurLeJeu: true)
    }

    @Test("Tout réuni : le calque dessine")
    func toutReuni() {
        #expect(ViseeHarebourg.inactive(active) == nil)
    }

    @Test("Chaque cause d'inactivité, dans l'ordre", arguments: ViseeHarebourg.Inactive.allCases)
    func causes(cause: ViseeHarebourg.Inactive) {
        var e = active
        switch cause {
        case .reglage: e.reglage = false
        case .pasHarebourg: e.harebourg = false
        case .panneauCache: e.panneauMontre = false
        case .pasSonTour: e.sonTour = false
        case .grilleAbsente: e.grille = nil
        case .grilleInvalide: e.contenu = CGSize(width: 1728, height: 1084)
        case .sansLanceur: e.lanceur = nil
        case .sansConfusion: e.confusion = false
        case .horsDuJeu: e.pointeurSurLeJeu = false
        }
        #expect(ViseeHarebourg.inactive(e) == cause)
    }

    @Test("Dofus derrière : hors du jeu, sans juger la grille")
    func dofusDerriere() {
        var e = active
        e.contenu = nil
        #expect(ViseeHarebourg.inactive(e) == .horsDuJeu)
        // Une cause plus haute dans la chaîne passe devant.
        e.lanceur = nil
        #expect(ViseeHarebourg.inactive(e) == .sansLanceur)
    }

    @Test("Le Diagnostic garde la raison vue en jeu quand Dofus passe derrière")
    func raisonAffichee() {
        // Réglages devant : « hors du jeu » ne remplace pas « pivot à marquer ».
        #expect(ViseeHarebourg.raisonAffichee(.horsDuJeu, avant: .sansLanceur, dofusDevant: false) == .sansLanceur)
        #expect(ViseeHarebourg.raisonAffichee(.panneauCache, avant: nil, dofusDevant: false) == nil)
        // Ce qui se juge hors du jeu se dit tout de suite.
        #expect(ViseeHarebourg.raisonAffichee(.reglage, avant: .sansLanceur, dofusDevant: false) == .reglage)
        #expect(ViseeHarebourg.raisonAffichee(.grilleAbsente, avant: nil, dofusDevant: false) == .grilleAbsente)
        // Dofus devant : la raison d'à l'instant.
        #expect(ViseeHarebourg.raisonAffichee(.pasSonTour, avant: .sansLanceur, dofusDevant: true) == .pasSonTour)
    }
}
