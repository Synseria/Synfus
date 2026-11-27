import Foundation
import Testing
@testable import Synfus

@Suite("Forgemagie")
struct ForgemagieTests {
    /// Les effets des runes, tels que DofusDB les rend (relevés le 26/11/2026).
    static let releves: [(id: Int, poids: Double, gabarit: String)] = [
        (111, 100, "#1{{~1~2 à }}#2 PA"),
        (112, 20, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}}"),
        (115, 10, "#1{{~1~2 à }}#2% Critique"),
        (117, 51, "#1{{~1~2 à }}#2 Portée"),
        (118, 1, "#1{{~1~2 à }}#2 Force"),
        (119, 1, "#1{{~1~2 à }}#2 Agilité"),
        (123, 1, "#1{{~1~2 à }}#2 Chance"),
        (124, 3, "#1{{~1~2 à }}#2 Sagesse"),
        (125, 0.20000000298023224, "#1{{~1~2 à }}#2 Vitalité"),
        (126, 1, "#1{{~1~2 à }}#2 Intelligence"),
        (128, 90, "#1{{~1~2 à }}#2 PM"),
        (138, 2, "#1{{~1~2 à }}#2 Puissance"),
        (158, 0.25, "#1{{~1~2 à }}#2 Pod{{~ps}}{{~zs}}"),
        (160, 7, "#1{{~1~2 à }}#2 Esquive PA"),
        (161, 7, "#1{{~1~2 à }}#2 Esquive PM"),
        (174, 0.10000000149011612, "#1{{~1~2 à }}#2 Initiative"),
        (176, 3, "#1{{~1~2 à }}#2 Prospection"),
        (178, 10, "#1{{~1~2 à }}#2 Soin{{~ps}}{{~zs}}"),
        (182, 30, "#1{{~1~2 à }}#2 Invocation{{~ps}}{{~zs}}"),
        (210, 6, "#1{{~1~2 à }}#2% Résistance Terre"),
        (211, 6, "#1{{~1~2 à }}#2% Résistance Eau"),
        (212, 6, "#1{{~1~2 à }}#2% Résistance Air"),
        (213, 6, "#1{{~1~2 à }}#2% Résistance Feu"),
        (214, 6, "#1{{~1~2 à }}#2% Résistance Neutre"),
        (220, 5, "#1{{~1~2 à }}#2 Dommages Renvoyés"),
        (225, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Pièges"),
        (226, 2, "#1{{~1~2 à }}#2 Puissance Pièges"),
        (240, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Terre"),
        (241, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Eau"),
        (242, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Air"),
        (243, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Feu"),
        (244, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Neutre"),
        (410, 7, "#1{{~1~2 à }}#2 Retrait PA"),
        (412, 7, "#1{{~1~2 à }}#2 Retrait PM"),
        (414, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Poussée"),
        (416, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Poussée"),
        (418, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Critique{{~ps}}{{~zs}}"),
        (420, 2, "#1{{~1~2 à }}#2 Résistance{{~ps}}{{~zs}} Critiques"),
        (422, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Terre"),
        (424, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Feu"),
        (426, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Eau"),
        (428, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Air"),
        (430, 5, "#1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Neutre"),
        (752, 4, "#1{{~1~2 à }}#2 Fuite"),
        (753, 4, "#1{{~1~2 à }}#2 Tacle"),
        (795, 5, "Arme de chasse"),
        (2800, 15, "#1{{~1~2 à }}#2% Dommages mêlée"),
        (2803, 10, "#1{{~1~2 à }}#2% Résistance mêlée"),
        (2804, 15, "#1{{~1~2 à }}#2% Dommages distance"),
        (2807, 10, "#1{{~1~2 à }}#2% Résistance distance"),
        (2808, 15, "#1{{~1~2 à }}#2% Dommages d'armes"),
        (2812, 15, "#1{{~1~2 à }}#2% Dommages aux sorts"),
    ]

    static let catalogue: CatalogueFM = {
        typealias O = CatalogueFM.ObjetDofusDB
        let effets = releves.map { CatalogueFM.EffetDofusDB(id: $0.id, effectPowerRate: $0.poids, description: ["fr": $0.gabarit]) }
        func rune(_: Int, _ nom: String, _ effet: Int, _ puissance: Int) -> O {
            O(name: ["fr": nom], effects: [.init(effectId: effet, from: puissance)])
        }
        let runes = [
            rune(1551, "Rune Ra Fo", 118, 10), rune(1519, "Rune Fo", 118, 1), rune(1545, "Rune Pa Fo", 118, 3),
            rune(1525, "Rune Cha", 123, 1), rune(1550, "Rune Pa Cha", 123, 3), rune(1556, "Rune Ra Cha", 123, 10),
            rune(1523, "Rune Vi", 125, 5), rune(1548, "Rune Pa Vi", 125, 15), rune(1554, "Rune Ra Vi", 125, 50),
            rune(1557, "Rune Ga Pa", 111, 1), rune(7448, "Rune Ini", 174, 10), rune(7449, "Rune Pa Ini", 174, 30),
            rune(7450, "Rune Ra Ini", 174, 100), rune(1524, "Rune Age", 119, 1), rune(1549, "Rune Pa Age", 119, 3),
            rune(1555, "Rune Ra Age", 119, 10), rune(1521, "Rune Sa", 124, 1), rune(1546, "Rune Pa Sa", 124, 3),
            rune(1552, "Rune Ra Sa", 124, 10), rune(1522, "Rune Ine", 126, 1), rune(1547, "Rune Pa Ine", 126, 3),
            rune(1553, "Rune Ra Ine", 126, 10), rune(7451, "Rune Prospe", 176, 1), rune(10662, "Rune Pa Prospe", 176, 3),
            rune(10057, "Rune de chasse", 795, 0),
            O(name: ["fr": "Rune de Signature"], effects: []),
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
        #expect(catalogue.effets[115]?.pourcent == true)
        #expect(catalogue.effets[240]?.nom == "Résistances Terre")
        #expect(catalogue.effets[240]?.pourcent == false)
        #expect(catalogue.effets[125]?.poids == 0.2)
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
        #expect(catalogue.runes.values.joined().count == 24)
    }

    @Test("Le nom lu retrouve son effet, à une faute près, jamais à égalité")
    func effetNomme() {
        #expect(catalogue.effet(nomme: "Chance", pourcent: false)?.id == 123)
        #expect(catalogue.effet(nomme: "Vitalite", pourcent: false)?.id == 125)
        #expect(catalogue.effet(nomme: "Domages Terre", pourcent: false)?.id == 422)
        // Fixe ou en pourcentage : deux effets.
        #expect(catalogue.effet(nomme: "Résistance Terre", pourcent: true)?.id == 210)
        #expect(catalogue.effet(nomme: "Résistance Terre", pourcent: false)?.id == 240)
        // « PO » est à une faute de « PA » comme de « PM » : rien plutôt que faux.
        #expect(catalogue.effet(nomme: "PO", pourcent: false) == nil)
        #expect(catalogue.effet(nomme: "Bouclier", pourcent: false) == nil)
    }

    @Test("Chaque effet relevé se retrouve par son propre nom")
    func tousLesNoms() {
        #expect(catalogue.effets.count == Self.releves.count)
        for effet in catalogue.effets.values {
            #expect(catalogue.effet(nomme: effet.nom, pourcent: effet.pourcent)?.id == effet.id, "\(effet.nom)")
        }
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
        #expect(ObjetFM(lignes: [.init(effet: 111, valeur: 1, max: nil, exo: true)])
            .depasseraitPlafond(try rune(111, .simple), catalogue))
        // La dernière rune légale passe, au poids flottant près : 505 Vitalité, 1010 Initiative.
        let vi = try rune(125, .simple)
        #expect(!ObjetFM(lignes: [.init(effet: 125, valeur: 750, max: 250)]).depasseraitPlafond(vi, catalogue))
        #expect(ObjetFM(lignes: [.init(effet: 125, valeur: 755, max: 250)]).depasseraitPlafond(vi, catalogue))
        let ini = try rune(174, .simple)
        #expect(!ObjetFM(lignes: [.init(effet: 174, valeur: 1000, max: nil, exo: true)]).depasseraitPlafond(ini, catalogue))
        #expect(ObjetFM(lignes: [.init(effet: 174, valeur: 1010, max: nil, exo: true)]).depasseraitPlafond(ini, catalogue))
    }

    // MARK: - Issue d'une fusion

    @Test("L'issue se lit dans la différence de deux tables")
    func issues() throws {
        func objet(_ valeurs: [Int: Int], exo: Set<Int> = []) -> ObjetFM {
            ObjetFM(lignes: valeurs.sorted { $0.key < $1.key }.map {
                .init(effet: $0.key, valeur: $0.value, max: exo.contains($0.key) ? nil : 300, exo: exo.contains($0.key))
            })
        }
        let avant = objet([123: 13, 125: 224])
        func constat(_ apres: ObjetFM, _ ra: Double? = nil, _ rb: Double? = nil) -> FusionFM? {
            FusionFM.constater(avant: avant, apres: apres, catalogue: catalogue, reliquatAvant: ra, reliquatApres: rb)
        }
        let sc = try #require(constat(objet([123: 16, 125: 224])))
        #expect(sc.issue == .succesCritique && sc.gains == [123: 3] && sc.pertes.isEmpty)
        let sn = try #require(constat(objet([123: 16, 125: 209])))
        #expect(sn.issue == .succesNeutre && sn.pertes == [125: 15])
        #expect(abs(sn.poidsPerdu - 3) < 0.01)
        #expect(try #require(constat(objet([123: 3, 125: 224]))).issue == .echec)
        // Le puits a payé : aucune ligne ne baisse, le reliquat si.
        #expect(try #require(constat(objet([123: 16, 125: 224]), 12, 9)).issue == .succesNeutre)
        #expect(try #require(constat(objet([123: 13, 125: 224]), 12, 9)).issue == .echec)
        #expect(constat(objet([123: 13, 125: 224])) == nil)
        // Une exo : une ligne sans min ni max apparaît, de la puissance d'une rune.
        let exo = try #require(constat(objet([123: 13, 125: 224, 111: 1], exo: [111])))
        #expect(exo.issue == .succesCritique && exo.gains == [111: 1])
        // Une ligne revenue dans la vue (elle a ses min et max, ou une valeur qu'aucune rune ne donne) n'est pas un gain.
        #expect(constat(objet([123: 13, 125: 224, 118: 40])) == nil)
        #expect(constat(objet([123: 13, 125: 224, 118: 40], exo: [118])) == nil)
        // La table a défilé : une ligne sortie de la vue n'est pas une perte.
        #expect(constat(objet([125: 224, 111: 1], exo: [111])) == nil)
        // Deux lignes qui montent : pas une fusion.
        #expect(constat(objet([123: 16, 125: 239])) == nil)
    }

    // MARK: - Texte lu

    @Test("L'historique et le reliquat, tels que les écrit Dofus 3")
    func texte() {
        #expect(TexteFM.entree("Échec") == .echec)
        #expect(TexteFM.entree("Echec") == .echec)
        #expect(TexteFM.entree("3 Chance") == .ligne(points: 3, nom: "Chance", pourcent: false))
        #expect(TexteFM.entree("-10 Chance") == .ligne(points: -10, nom: "Chance", pourcent: false))
        #expect(TexteFM.entree("−3 Dommages Terre") == .ligne(points: -3, nom: "Dommages Terre", pourcent: false))
        #expect(TexteFM.entree("+1 PA") == .ligne(points: 1, nom: "PA", pourcent: false))
        #expect(TexteFM.entree("+ reliquat") == .reliquat(gagne: true))
        #expect(TexteFM.entree("- reliquat") == .reliquat(gagne: false))
        // Ce que l'OCR rend vraiment de l'atelier (captures du 26/11/2026) : icônes parasites.
        #expect(TexteFM.entree("≥ -18 Initiative") == .ligne(points: -18, nom: "Initiative", pourcent: false))
        #expect(TexteFM.entree("> -1 Vitalité") == .ligne(points: -1, nom: "Vitalité", pourcent: false))
        #expect(TexteFM.entree("3 46 Sagesse") == .ligne(points: 46, nom: "Sagesse", pourcent: false))
        #expect(TexteFM.entree("- 7% Critique") == .ligne(points: 7, nom: "Critique", pourcent: true))
        #expect(TexteFM.entree("• 12 Résistances Eau") == .ligne(points: 12, nom: "Résistances Eau", pourcent: false))
        #expect(TexteFM.entree("49 Initi1tive") == .ligne(points: 49, nom: "Initi1tive", pourcent: false))
        #expect(TexteFM.entree("1U InITIaTIVe") == nil)
        #expect(TexteFM.entree("• VIDER L'HISTORIQUE") == nil)
        #expect(TexteFM.entree("3% Critique") == .ligne(points: 3, nom: "Critique", pourcent: true))
        #expect(TexteFM.entree("-2 % Résistance Feu") == .ligne(points: -2, nom: "Résistance Feu", pourcent: true))
        #expect(TexteFM.entree("Il n'y a pas d'historique actuellement.") == nil)
        #expect(TexteFM.entree("VIDER L'HISTORIQUE") == nil)
        #expect(TexteFM.historique(["Échec", "1 Chance", "VIDER L'HISTORIQUE"]) == [.echec, .ligne(points: 1, nom: "Chance", pourcent: false)])
        #expect(TexteFM.reliquat(["Syl-Ami", "reliquat : 0"]) == 0)
        #expect(TexteFM.reliquat(["Reliquat: 12,5"]) == 12.5)
        #expect(TexteFM.reliquat(["reliquat : 0.1"]) == 0.1)
        #expect(TexteFM.reliquat(["FUSIONNER TOUT"]) == nil)
    }
}
