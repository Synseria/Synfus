import Foundation
import Testing
@testable import Synfus

/// Le suivi de quêtes du jeu, tel que l'OCR le rend : titres écorchés,
/// icônes lues comme des lettres, objectifs sur deux lignes.
struct SuiviQuetesTests {
    private static func objectif(_ id: Int, _ texte: String) -> ObjectifQuete {
        ObjectifQuete(id: id, textes: ["fr": texte], x: nil, y: nil, carte: nil, objet: nil, quantite: nil)
    }

    private static func quete(_ id: Int, _ noms: [String: String], etapes: [[ObjectifQuete]] = [[]]) -> Quete {
        Quete(id: id, noms: noms, niveau: 1, groupe: false, donjon: false, prerequis: [],
              etapes: etapes.map { EtapeQuete(noms: [:], descriptions: [:], objectifs: $0, recompenses: .aucune) })
    }

    private static func quetes(_ liste: [Quete]) -> Quetes {
        Quetes(format: Quetes.formatActuel, date: .now, quetes: liste, pnjs: [],
               objets: ["20": ["fr": "Âme de Gelée Royale Bleuet"]], monstres: [:],
               nomsPNJ: ["10": ["fr": "Meuh Sieurchance"], "11": ["fr": "Assistante d'Otomaï"]],
               sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:], titres: [:])
    }

    /// Les quêtes de la capture de l'utilisateur ; « L'éternelle moisson » a
    /// deux étapes, la seconde ramène l'âme à l'assistante.
    private static let jeu = quetes([
        quete(1, ["fr": "Pense-bête", "en": "Reminder"]),
        quete(2, ["fr": "La raison du plus fort"]),
        quete(3, ["fr": "L'éternelle moisson"], etapes: [
            [objectif(31, "Aller voir {npc,10}")],
            [objectif(32, "Ramener à {npc,11} : x1 {item,20}")],
        ]),
        quete(4, ["fr": "Naissance d'une vocation"]),
        quete(5, ["fr": "La voie du guerrier"]),
        quete(6, ["fr": "La voie"]),
        quete(8, ["fr": "Ogre"]),
    ])

    @Test("Les titres du suivi, dans l'ordre de l'écran, malgré les fautes et les icônes")
    func titres() {
        let lignes = [
            "Suivi de quêtes",
            "Pense-bete",
            "? Retrouver Meuh Sieurchance chez lui, au village des éleveurs",
            "La raison du plus fort 8",
            "• Entrer dans l'Akadémie des Gobs",
            "L'eternele moisson",
            "Rapporter 1 âme de Gelée Royale Bleuet à",
            "Assistante d'Otomaï.",
            "Naissance dune vocation",
            "VOIR PLUS…",
            "La voie du guerrier",
        ]
        #expect(SuiviQuetes.reconnaitre(lignes, dans: Self.jeu).map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test("Un titre court se lit sans faute admise, le plus long l'emporte")
    func courts() {
        #expect(SuiviQuetes.reconnaitre(["La voie"], dans: Self.jeu).map(\.id) == [6])
        #expect(SuiviQuetes.reconnaitre(["Ogre"], dans: Self.jeu).map(\.id) == [8])
        #expect(SuiviQuetes.reconnaitre(["Ogro"], dans: Self.jeu).isEmpty)
        #expect(SuiviQuetes.reconnaitre(["La voie du guerier"], dans: Self.jeu).map(\.id) == [5])
    }

    @Test("Un objectif qui cite une quête n'en est pas le titre")
    func objectifCitant() {
        let lignes = ["Pense-bête", "Demander conseil à propos de La raison du plus fort au maître"]
        #expect(SuiviQuetes.reconnaitre(lignes, dans: Self.jeu).map(\.id) == [1])
    }

    @Test("Le titre dans une autre langue que celle de l'interface")
    func langue() {
        #expect(SuiviQuetes.reconnaitre(["Reminder"], dans: Self.jeu).map(\.id) == [1])
    }

    @Test("Sans doublon, dix au plus")
    func limite() {
        let liste = (1...12).map { Self.quete($0, ["fr": "Quête numéro \($0) du suivi"]) }
        let lignes = ["Quête numéro 1 du suivi"] + liste.map { $0.noms["fr"]! }
        let reconnues = SuiviQuetes.reconnaitre(lignes, dans: Self.quetes(liste))
        #expect(reconnues.map(\.id) == Array(1...SuiviQuetes.limite))
    }

    @Test("Les objectifs lus sous un titre désignent son étape, sinon rien")
    func etape() {
        let lignes = ["L'éternelle moisson", "Rapporter 1 âme de Gelée Royale Bleuet à", "Assistante d'Otomaï.",
                      "La raison du plus fort", "Retrouver Meuh Sieurchance chez lui"]
        let reconnues = SuiviQuetes.reconnaitre(lignes, dans: Self.jeu)
        // Meuh Sieurchance est sous une autre quête : il ne désigne pas la
        // première étape de la moisson.
        #expect(reconnues == [.init(id: 3, etape: 1), .init(id: 2, etape: nil)])
        let premiere = SuiviQuetes.reconnaitre(["L'éternelle moisson", "Retrouver Meuh Sieurchance chez lui"],
                                               dans: Self.jeu)
        #expect(premiere == [.init(id: 3, etape: 0)])
    }

    @Test("Deux étapes qui citent le même PNJ ne désignent rien")
    func etapeAmbigue() {
        let jeu = Self.quetes([Self.quete(7, ["fr": "Le retour de la bergère"], etapes: [
            [Self.objectif(71, "Aller voir {npc,10}")],
            [Self.objectif(72, "Ramener à {npc,10} : x1 {item,20}")],
        ])])
        let reconnues = SuiviQuetes.reconnaitre(["Le retour de la bergere", "Aller voir Meuh Sieurchance"], dans: jeu)
        #expect(reconnues == [.init(id: 7, etape: 0)])
        let ambigue = SuiviQuetes.reconnaitre(["Le retour de la bergere", "Meuh Sieurchance"], dans: jeu)
        #expect(ambigue == [.init(id: 7, etape: nil)])
    }
}
