import Foundation
import Testing
@testable import Synfus

@Suite("Forgemagie")
struct ForgemagieTests {
    /// Un extrait des réponses de DofusDB (relevées le 26/11/2026).
    static let catalogue: CatalogueFM = {
        typealias E = CatalogueFM.EffetDofusDB
        typealias O = CatalogueFM.ObjetDofusDB
        let effets = [
            E(id: 118, effectPowerRate: 1, description: ["fr": "#1{{~1~2 à }}#2 Force"]),
            E(id: 123, effectPowerRate: 1, description: ["fr": "#1{{~1~2 à }}#2 Chance"]),
            E(id: 125, effectPowerRate: 0.20000000298023224, description: ["fr": "#1{{~1~2 à }}#2 Vitalité"]),
            E(id: 111, effectPowerRate: 100, description: ["fr": "#1{{~1~2 à }}#2 PA"]),
            E(id: 422, effectPowerRate: 5, description: ["fr": "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Terre"]),
            E(id: 115, effectPowerRate: 10, description: ["fr": "#1{{~1~2 à }}#2% Critique"]),
            E(id: 795, effectPowerRate: 5, description: ["fr": "Arme de chasse"]),
        ]
        func rune(_: Int, _: String, _ effet: Int, _ puissance: Int) -> O {
            O(effects: [.init(effectId: effet, from: puissance)])
        }
        let runes = [
            rune(1551, "Rune Ra Fo", 118, 10), rune(1519, "Rune Fo", 118, 1), rune(1545, "Rune Pa Fo", 118, 3),
            rune(1525, "Rune Cha", 123, 1), rune(1550, "Rune Pa Cha", 123, 3), rune(1556, "Rune Ra Cha", 123, 10),
            rune(1523, "Rune Vi", 125, 5), rune(1548, "Rune Pa Vi", 125, 15), rune(1554, "Rune Ra Vi", 125, 50),
            rune(1557, "Rune Ga Pa", 111, 1),
            rune(10057, "Rune de chasse", 795, 0),
            O(effects: []),
        ]
        return CatalogueFM(effets: effets, runes: runes)
    }()

    private var catalogue: CatalogueFM { Self.catalogue }

    private func rune(_ effet: Int, _ rang: CatalogueFM.Rang) throws -> CatalogueFM.Rune {
        try #require(catalogue.runes[effet]?.first { $0.rang == rang })
    }

    // MARK: - Catalogue

    @Test("Les noms des effets, tels que le jeu les écrit")
    func noms() {
        #expect(catalogue.effets[422]?.nom == "Dommages Terre")
        #expect(catalogue.effets[115]?.nom == "Critique")
        #expect(catalogue.effets[125]?.nom == "Vitalité")
        #expect(CatalogueFM.nom(gabarit: "#1{{~1~2 à }}#2 Pod{{~ps}}{{~zs}}") == "Pods")
    }

    @Test("Rangs et poids des runes : simple, Pa ×3, Ra ×10")
    func runes() throws {
        #expect(catalogue.runes[118]?.map(\.rang) == [.simple, .pa, .ra])
        #expect(try rune(118, .ra).poids == 10)
        #expect(abs(try rune(125, .pa).poids - 3) < 0.001)
        #expect(try rune(111, .simple).poids == 100)
        // Chasse (puissance nulle) et signature (sans effet) n'en sont pas.
        #expect(catalogue.runes[795] == nil)
        #expect(catalogue.runes.values.joined().count == 10)
    }

    @Test("Le nom lu retrouve son effet, à une faute près")
    func effetNomme() {
        #expect(catalogue.effet(nomme: "Chance")?.id == 123)
        #expect(catalogue.effet(nomme: "Vitalite")?.id == 125)
        #expect(catalogue.effet(nomme: "Domages Terre")?.id == 422)
        #expect(catalogue.effet(nomme: "Sagesse") == nil)
    }

    // MARK: - Objet

    @Test("Poids, poids max et plafond over + exo")
    func objet() throws {
        let objet = ObjetFM(lignes: [
            .init(effet: 125, valeur: 224, max: 250),
            .init(effet: 118, valeur: 150, max: 60),
        ])
        #expect(abs(objet.poids(catalogue) - (224 * 0.2 + 150)) < 0.01)
        #expect(abs(objet.poidsMax(catalogue) - (250 * 0.2 + 60)) < 0.01)
        // Force à 150 pour un max de 60 : 90 d'over ; une Ra Fo passerait à 100 ≤ 101.
        #expect(!objet.depasseraitPlafond(try rune(118, .ra), catalogue))
        let plein = ObjetFM(lignes: [.init(effet: 118, valeur: 155, max: 60)])
        #expect(plein.depasseraitPlafond(try rune(118, .ra), catalogue))
        // Une exo PA pèse 100 : une seconde la dépasserait.
        #expect(!ObjetFM(lignes: []).depasseraitPlafond(try rune(111, .simple), catalogue))
        #expect(ObjetFM(lignes: [.init(effet: 111, valeur: 1, max: nil)])
            .depasseraitPlafond(try rune(111, .simple), catalogue))
    }

    // MARK: - Issue et puits

    @Test("L'issue se lit dans la différence de deux tables")
    func issues() throws {
        let paCha = try rune(123, .pa)
        let avant = [123: 13, 125: 224]
        let sc = FusionFM.constater(avant: avant, apres: [123: 16, 125: 224], rune: paCha, catalogue: catalogue)
        #expect(sc.issue == .succesCritique && sc.gain == 3 && sc.pertes.isEmpty)
        let sn = FusionFM.constater(avant: avant, apres: [123: 16, 125: 209], rune: paCha, catalogue: catalogue)
        #expect(sn.issue == .succesNeutre && sn.pertes == [125: 15])
        #expect(abs(sn.poidsPerdu - 3) < 0.01)
        let ec = FusionFM.constater(avant: avant, apres: [123: 3, 125: 224], rune: paCha, catalogue: catalogue)
        #expect(ec.issue == .echec && ec.pertes == [123: 10])
        // Le puits a payé : aucune ligne ne baisse, le reliquat si.
        let payeParLePuits = FusionFM.constater(avant: avant, apres: [123: 16, 125: 224], rune: paCha, catalogue: catalogue,
                                                reliquatAvant: 12, reliquatApres: 9)
        #expect(payeParLePuits.issue == .succesNeutre)
        // Une exo : la ligne apparaît.
        let exo = FusionFM.constater(avant: avant, apres: [123: 13, 125: 224, 111: 1], rune: try rune(111, .simple),
                                     catalogue: catalogue)
        #expect(exo.issue == .succesCritique && exo.gain == 1)
    }

    @Test("Le puits se recompte au fil des fusions, jamais sous zéro")
    func puits() throws {
        let fo = try rune(118, .simple)
        let raVi = try rune(125, .ra)
        var puits = 0.0
        // Une Ra Vi (poids 10) qui arrache 30 Force : 20 de puits.
        var fusion = FusionFM.constater(avant: [125: 100, 118: 60], apres: [125: 150, 118: 30], rune: raVi, catalogue: catalogue)
        puits = fusion.puits(apres: puits, rune: raVi)
        #expect(abs(puits - 20) < 0.001)
        // Un succès critique n'y touche pas.
        fusion = FusionFM.constater(avant: [118: 30], apres: [118: 31], rune: fo, catalogue: catalogue)
        puits = fusion.puits(apres: puits, rune: fo)
        #expect(abs(puits - 20) < 0.001)
        // Un échec sans perte de ligne : le puits paie le poids de la rune.
        fusion = FusionFM.constater(avant: [118: 31], apres: [118: 31], rune: fo, catalogue: catalogue)
        puits = fusion.puits(apres: puits, rune: fo)
        #expect(abs(puits - 19) < 0.001)
        // Plus de rune que de puits : zéro, pas moins.
        #expect(FusionFM(issue: .succesNeutre, gain: 1, pertes: [:], poidsPerdu: 0).puits(apres: 4, rune: raVi) == 0)
        // Les décimales sont gardées : une Rune Fo (1) qui coûte 4 Vitalité (0,8).
        fusion = FusionFM.constater(avant: [125: 100, 118: 30], apres: [125: 96, 118: 31], rune: fo, catalogue: catalogue)
        #expect(abs(fusion.puits(apres: 5.5, rune: fo) - 5.3) < 0.001)
    }

    // MARK: - Texte lu

    @Test("L'historique et le reliquat, tels que les écrit Dofus 3")
    func texte() {
        #expect(TexteFM.entree("Échec") == .echec)
        #expect(TexteFM.entree("Echec") == .echec)
        #expect(TexteFM.entree("3 Chance") == .ligne(points: 3, nom: "Chance"))
        #expect(TexteFM.entree("-10 Chance") == .ligne(points: -10, nom: "Chance"))
        #expect(TexteFM.entree("− 3 Dommages Terre") == .ligne(points: -3, nom: "Dommages Terre"))
        #expect(TexteFM.entree("+1 PA") == .ligne(points: 1, nom: "PA"))
        #expect(TexteFM.entree("-2,5 reliquat") == .reliquat(-2.5))
        #expect(TexteFM.entree("Il n'y a pas d'historique actuellement.") == nil)
        #expect(TexteFM.entree("VIDER L'HISTORIQUE") == nil)
        #expect(TexteFM.historique(["Échec", "1 Chance", "VIDER L'HISTORIQUE"]) == [.echec, .ligne(points: 1, nom: "Chance")])
        #expect(TexteFM.reliquat(["Syl-Ami", "reliquat : 0"]) == 0)
        #expect(TexteFM.reliquat(["Reliquat: 12,5"]) == 12.5)
        #expect(TexteFM.reliquat(["FUSIONNER TOUT"]) == nil)
    }
}
