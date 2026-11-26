import CoreGraphics
import Testing
@testable import Synfus

@Suite("Atelier de forgemagie lu")
struct AtelierFMTests {
    private let catalogue = ForgemagieTests.catalogue

    private func lu(_ textes: [DetectionZones.TexteVu]) throws -> AtelierFM {
        try #require(AtelierFM.lire(textes, catalogue: catalogue))
    }

    private func ligne(_ atelier: AtelierFM, _ effet: Int) -> ObjetFM.Ligne? { atelier.objet.ligne(effet) }

    @Test("La table qui défile : chaque ligne vue, son jet max à côté")
    func tableQuiDefile() throws {
        let atelier = try lu(FixturesAtelierFM.tableQuiDefile)
        #expect(atelier.reliquat == 0)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 224, max: 150))
        #expect(ligne(atelier, 126) == .init(effet: 126, valeur: 57, max: 60))
        // « 3 46 Sagesse » : l'icône lue « 3 ».
        #expect(ligne(atelier, 124) == .init(effet: 124, valeur: 46, max: 50))
        // « - 7% Critique » : l'icône lue « - ».
        #expect(ligne(atelier, 115) == .init(effet: 115, valeur: 7, max: 7))
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 499, max: 500))
        #expect(ligne(atelier, 210) == .init(effet: 210, valeur: 8, max: 8))
        #expect(ligne(atelier, 241) == .init(effet: 241, valeur: 12, max: 12))
        // Son max mal lu n'en fait pas une exo.
        #expect(ligne(atelier, 178) == .init(effet: 178, valeur: 4, max: nil, exo: false))
        #expect(atelier.objet.lignes.count >= 13)
        // L'historique, la plus récente en bas.
        #expect(atelier.historique.last == .reliquat(gagne: false))
        #expect(atelier.historique.contains(.ligne(points: -18, nom: "Initiative", pourcent: false)))
    }

    @Test("Une exo n'a ni min ni max ; un effet inconnu reste affiché")
    func exo() throws {
        let atelier = try lu(FixturesAtelierFM.exoDommagesAuxSorts)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 341, max: 350))
        // « Dommages aux sorts » n'est pas dans l'extrait du catalogue des tests.
        #expect(atelier.inconnues == ["1% Dommages aux sorts"])
    }

    @Test("« Маx » en lettres cyrilliques, le reliquat à une décimale")
    func maxCyrillique() throws {
        let atelier = try lu(FixturesAtelierFM.apresTroisRunes)
        #expect(atelier.reliquat == 0.1)
        #expect(ligne(atelier, 125) == .init(effet: 125, valeur: 34, max: 45))
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 49, max: 200))
        #expect(ligne(atelier, 158) == .init(effet: 158, valeur: 237, max: 200))
        #expect(atelier.objet.lignes.count == 3)
    }

    @Test("L'écran entier : suivi de quêtes, infobulle et tchat n'entrent pas dans l'atelier")
    func ecranEntier() throws {
        let atelier = try lu(FixturesAtelierFM.ecranEntier)
        #expect(atelier.objet.lignes.map(\.effet) == [125, 158, 174])
        #expect(ligne(atelier, 174) == .init(effet: 174, valeur: 208, max: 200))
        // « 9 190 Pods » : l'icône lue « 9 ».
        #expect(ligne(atelier, 158) == .init(effet: 158, valeur: 190, max: 200))
        #expect(atelier.inconnues.isEmpty)
        #expect(atelier.historique.first == .ligne(points: 9, nom: "Initiative", pourcent: false))
        #expect(atelier.historique.last == .reliquat(gagne: true))
        // Le cadre couvre l'atelier, pas le suivi de quêtes à gauche ni l'inventaire à droite.
        #expect(atelier.cadre.minX > 0.12 && atelier.cadre.maxX < 0.62)
    }

    @Test("Une séance : chaque fusion comptée, un autre objet repart de zéro")
    func seance() {
        func atelier(_ lignes: [ObjetFM.Ligne], _ reliquat: Double = 0) -> AtelierFM {
            AtelierFM(objet: ObjetFM(lignes: lignes), inconnues: [], reliquat: reliquat, historique: [], cadre: .zero)
        }
        var suivi = SuiviFM()
        #expect(suivi.lu(atelier([.init(effet: 174, valeur: 39, max: 200), .init(effet: 158, valeur: 255, max: 200)]),
                         catalogue: catalogue) == nil)
        let sn = suivi.lu(atelier([.init(effet: 174, valeur: 49, max: 200), .init(effet: 158, valeur: 251, max: 200)]),
                          catalogue: catalogue)
        #expect(sn?.issue == .succesNeutre)
        suivi.lu(atelier([.init(effet: 174, valeur: 59, max: 200), .init(effet: 158, valeur: 251, max: 200)]), catalogue: catalogue)
        #expect(suivi.comptes == [.succesNeutre: 1, .succesCritique: 1])
        // Rien de changé : pas de fusion.
        suivi.lu(atelier([.init(effet: 174, valeur: 59, max: 200), .init(effet: 158, valeur: 251, max: 200)]), catalogue: catalogue)
        #expect(suivi.comptes.values.reduce(0, +) == 2)
        // Un autre objet : un jet max différent.
        suivi.lu(atelier([.init(effet: 174, valeur: 400, max: 500)]), catalogue: catalogue)
        #expect(suivi.comptes.isEmpty && suivi.derniere == nil)
    }

    @Test("La région suivante entoure l'atelier lu, bornée au contenu")
    @MainActor func region() {
        let zone = ForgemagieModele.autour(CGRect(x: 0.02, y: 0.3, width: 0.5, height: 0.6))
        #expect(zone.x == 0 && abs(zone.y - 0.22) < 1e-9 && abs(zone.largeur - 0.6) < 1e-9 && abs(zone.hauteur - 0.76) < 1e-9)
    }

    @Test("Sans en-tête de table, pas d'atelier")
    func absent() {
        #expect(AtelierFM.lire([DetectionZones.TexteVu(texte: "Inventaire", cadre: CGRect(x: 0.5, y: 0.1, width: 0.1, height: 0.02))],
                               catalogue: catalogue) == nil)
    }
}
