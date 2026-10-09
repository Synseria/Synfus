import Foundation
import Testing
@testable import Synfus

/// Le suivi de quêtes du jeu, tel que l'OCR le rend : titres écorchés,
/// icônes lues comme des lettres, objectifs sur deux lignes.
struct SuiviQuetesTests {
    private static func objectif(_ id: Int, _ texte: String) -> ObjectifQuete {
        ObjectifQuete(id: id, textes: ["fr": texte], x: nil, y: nil, carte: nil, objet: nil, quantite: nil, type: nil)
    }

    private static func quete(_ id: Int, _ noms: [String: String], etapes: [[ObjectifQuete]] = [[]]) -> Quete {
        Quete(id: id, noms: noms, niveau: 1, groupe: false, donjon: false, prerequis: [], critere: nil,
              etapes: etapes.map { EtapeQuete(noms: [:], descriptions: [:], objectifs: $0, recompenses: .aucune) })
    }

    private static func quetes(_ liste: [Quete]) -> Quetes {
        Quetes(format: Quetes.formatActuel, date: .now, quetes: liste, pnjs: [],
               objets: ["20": ["fr": "Âme de Gelée Royale Bleuet"]], monstres: [:],
               nomsPNJ: ["10": ["fr": "Meuh Sieurchance"], "11": ["fr": "Assistante d'Otomaï"]],
               sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:], titres: [:],
               metiers: [:], camps: [:])
    }

    /// Les quêtes de la capture de l'utilisateur ; « L'éternelle moisson » a
    /// deux étapes, la seconde ramène l'âme à l'assistante.
    private static let jeu = SuiviQuetes.Index(quetes([
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
    ]))

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
        #expect(SuiviQuetes.reconnaitre(lignes, dans: Self.jeu).reconnues.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test("Un titre court se lit sans faute admise, le plus long l'emporte")
    func courts() {
        #expect(SuiviQuetes.reconnaitre(["La voie"], dans: Self.jeu).reconnues.map(\.id) == [6])
        #expect(SuiviQuetes.reconnaitre(["Ogre"], dans: Self.jeu).reconnues.map(\.id) == [8])
        #expect(SuiviQuetes.reconnaitre(["Ogro"], dans: Self.jeu).reconnues.isEmpty)
        #expect(SuiviQuetes.reconnaitre(["La voie du guerier"], dans: Self.jeu).reconnues.map(\.id) == [5])
    }

    @Test("Un objectif qui cite une quête n'en est pas le titre")
    func objectifCitant() {
        let lignes = ["Pense-bête", "Demander conseil à propos de La raison du plus fort au maître"]
        #expect(SuiviQuetes.reconnaitre(lignes, dans: Self.jeu).reconnues.map(\.id) == [1])
    }

    @Test("La fin d'un objectif replié n'est pas le titre court d'une autre quête")
    func finDObjectif() {
        let jeu = SuiviQuetes.Index(Self.quetes([
            Self.quete(10, ["fr": "Qui a la plus grosse ?"], etapes: [[
                Self.objectif(101, "Aller voir Assistant de Deks"),
                Self.objectif(102, "Ramener à Assistant de Deks : x1 Caisse de pièces de rechange"),
            ]]),
            Self.quete(11, ["fr": "Chargez !", "en": "Charge!"]),
        ]))
        let lu = SuiviQuetes.reconnaitre(["Qui a la plus grosse ?", "Ramener à Assistant de Deks : x1 Caisse de pièces",
                                          "de rechange"], dans: jeu)
        #expect(lu.reconnues == [.init(id: 10, etape: nil, aFaire: [102], faits: [101])])
        #expect(SuiviQuetes.reconnaitre(["Charge! 8"], dans: jeu).reconnues.map(\.id) == [11])
    }

    @Test("Un objectif replié qui finit par le nom d'une quête : sa fin, pas un titre ; après un objectif entier, un titre")
    func finEnNomDeQuete() {
        let jeu = SuiviQuetes.Index(Self.quetes([
            Self.quete(12, ["fr": "Le marché"], etapes: [[
                Self.objectif(121, "Aller voir Meuh Sieurchance"),
                Self.objectif(122, "Parler au marchand du village pour récupérer l'équipement"),
            ]]),
            Self.quete(13, ["fr": "L'équipe ment"]),
        ]))
        let replie = SuiviQuetes.reconnaitre(["Le marché", "Parler au marchand du village pour récupérer",
                                              "l'équipement"], dans: jeu)
        #expect(replie.reconnues == [.init(id: 12, etape: nil, aFaire: [122], faits: [121])])
        let entier = SuiviQuetes.reconnaitre(["Le marché", "Parler au marchand du village pour récupérer l'équipement",
                                              "L'équipe ment"], dans: jeu)
        #expect(entier.reconnues.map(\.id) == [12, 13])
    }

    @Test("Le titre dans une autre langue que celle de l'interface")
    func langue() {
        #expect(SuiviQuetes.reconnaitre(["Reminder"], dans: Self.jeu).reconnues.map(\.id) == [1])
    }

    @Test("Sans doublon, dix au plus")
    func limite() {
        let liste = (1...12).map { Self.quete($0, ["fr": "Quête numéro \($0) du suivi"]) }
        let lignes = ["Quête numéro 1 du suivi"] + liste.map { $0.noms["fr"]! }
        let reconnues = SuiviQuetes.reconnaitre(lignes, dans: .init(Self.quetes(liste))).reconnues
        #expect(reconnues.map(\.id) == Array(1...SuiviQuetes.limite))
    }

    @Test("Les objectifs lus sous un titre désignent son étape, sinon rien")
    func etape() {
        let lignes = ["L'éternelle moisson", "Rapporter 1 âme de Gelée Royale Bleuet à", "Assistante d'Otomaï.",
                      "La raison du plus fort", "Retrouver Meuh Sieurchance chez lui"]
        let reconnues = SuiviQuetes.reconnaitre(lignes, dans: Self.jeu).reconnues
        // Meuh Sieurchance est sous une autre quête : il ne désigne pas la
        // première étape de la moisson.
        #expect(reconnues == [.init(id: 3, etape: 1), .init(id: 2, etape: nil)])
        let premiere = SuiviQuetes.reconnaitre(["L'éternelle moisson", "Retrouver Meuh Sieurchance chez lui"],
                                               dans: Self.jeu).reconnues
        #expect(premiere == [.init(id: 3, etape: 0)])
    }

    @Test("Des quêtes homonymes : les objectifs désignent la bonne, sinon aucune n'est cochée")
    func homonymes() {
        let nowel = { (id: Int, monstre: String) in
            Self.quete(id, ["fr": "Joyeux Nowel"], etapes: [[
                Self.objectif(id * 10, "Vaincre x1 \(monstre) en un seul combat"), Self.objectif(id * 10 + 1, "Aller voir {npc,10}"),
            ]])
        }
        let jeu = SuiviQuetes.Index(Self.quetes([nowel(20, "Tofu Royal"), nowel(21, "Bouftou Royal")]))
        let vaincre = SuiviQuetes.reconnaitre(["Joyeux Nowel", "Vaincre x1 Bouftou Royal en un seul combat"], dans: jeu)
        #expect(vaincre.reconnues == [.init(id: 21, etape: nil, aFaire: [210], nonMontres: [211])])
        // « Aller voir » est le même partout : le combat de l'une ne se coche pas pour l'autre.
        let allerVoir = SuiviQuetes.reconnaitre(["Joyeux Nowel", "Aller voir Meuh Sieurchance"], dans: jeu)
        #expect(allerVoir.reconnues == [.init(id: 20, etape: nil)])
        // Deux à l'écran : deux quêtes, pas une vue deux fois.
        let deux = SuiviQuetes.reconnaitre(["Joyeux Nowel", "Aller voir Meuh Sieurchance",
                                            "Joyeux Nowel", "Vaincre x1 Tofu Royal en un seul combat"], dans: jeu)
        #expect(deux.reconnues == [.init(id: 21, etape: nil), .init(id: 20, etape: nil, aFaire: [200], nonMontres: [201])])
    }

    @Test("Un titre à une faute de plusieurs noms : les objectifs départagent, sinon rien n'est coché")
    func offrandes() {
        let offrande = { (id: Int, dieu: String) in
            Self.quete(id, ["fr": "Offrande à \(dieu)"], etapes: [[
                Self.objectif(id * 10, "Aller voir \(dieu)"), Self.objectif(id * 10 + 1, "Prier devant l'autel de l'automne"),
            ]])
        }
        let jeu = SuiviQuetes.Index(Self.quetes([offrande(30, "Bii"), offrande(31, "Blid")]))
        // « Bli » : « Bii » ou « Blid » à une faute ; « Aller voir Bii » tranche.
        #expect(SuiviQuetes.reconnaitre(["Offrande à Bli", "Aller voir Bii"], dans: jeu).reconnues
                == [.init(id: 30, etape: nil, aFaire: [300], nonMontres: [301])])
        #expect(SuiviQuetes.reconnaitre(["Offrande à Bli", "Prier devant l'autel de l'automne"], dans: jeu).reconnues
                == [.init(id: 31, etape: nil)])
        // Lu sans faute, « Blid » est à deux fautes : le nom seul désigne.
        #expect(SuiviQuetes.reconnaitre(["Offrande à Bii", "Prier devant l'autel de l'automne"], dans: jeu).reconnues
                == [.init(id: 30, etape: nil, aFaire: [301], faits: [300])])
        // « Bix » à une faute : le nom le mieux lu montre, sans rien cocher.
        let voisins = SuiviQuetes.Index(Self.quetes([offrande(30, "Bii"), offrande(32, "Bix")]))
        #expect(SuiviQuetes.reconnaitre(["Offrande à Bii", "Prier devant l'autel de l'automne"], dans: voisins).reconnues
                == [.init(id: 30, etape: nil, aFaire: [301])])
    }

    @Test("Un objectif qui porte le nom d'une autre quête n'en est le titre que si elle explique la suite")
    func objectifNommeCommeUneQuete() {
        let jeu = SuiviQuetes.Index(Self.quetes([
            Self.quete(14, ["fr": "Une affaire de gaz"], etapes: [[
                Self.objectif(141, "Aller voir Meuh Sieurchance"), Self.objectif(142, "Lâcher les gaz"),
                Self.objectif(143, "Retourner voir Meuh Sieurchance"),
            ]]),
            Self.quete(15, ["fr": "Lâcher les gaz"], etapes: [[Self.objectif(151, "Aller voir Assistante d'Otomaï")]]),
        ]))
        let objectif = SuiviQuetes.reconnaitre(["Une affaire de gaz", "Lâcher les gaz", "Retourner voir Meuh Sieurchance"],
                                               dans: jeu)
        #expect(objectif.reconnues == [.init(id: 14, etape: nil, aFaire: [142, 143], faits: [141])])
        let titre = SuiviQuetes.reconnaitre(["Une affaire de gaz", "Aller voir Meuh Sieurchance", "Lâcher les gaz",
                                             "Aller voir Assistante d'Otomaï"], dans: jeu)
        #expect(titre.reconnues.map(\.id) == [14, 15])
    }

    @Test("Un objectif lu en entier dans deux étapes : les noms cités ne tranchent pas")
    func memeObjectifDeuxEtapes() {
        let jeu = SuiviQuetes.Index(Self.quetes([Self.quete(16, ["fr": "Le retour du berger"], etapes: [
            [Self.objectif(161, "Aller voir {npc,10}")],
            [Self.objectif(162, "Aller voir {npc,10}"), Self.objectif(163, "Ramener à {npc,10} : x1 {item,20}")],
        ])]))
        // La seconde étape cite deux fois Meuh Sieurchance, mais le suivi ne
        // dit pas laquelle est ouverte.
        #expect(SuiviQuetes.reconnaitre(["Le retour du berger", "Aller voir Meuh Sieurchance"], dans: jeu).reconnues
                == [.init(id: 16, etape: nil)])
    }

    @Test("Deux étapes qui citent le même PNJ ne désignent rien")
    func etapeAmbigue() {
        let jeu = SuiviQuetes.Index(Self.quetes([Self.quete(7, ["fr": "Le retour de la bergère"], etapes: [
            [Self.objectif(71, "Aller voir {npc,10}")],
            [Self.objectif(72, "Ramener à {npc,10} : x1 {item,20}")],
        ])]))
        let reconnues = SuiviQuetes.reconnaitre(["Le retour de la bergere", "Aller voir Meuh Sieurchance"], dans: jeu).reconnues
        #expect(reconnues == [.init(id: 7, etape: 0, etapeSure: true, aFaire: [71])])
        let ambigue = SuiviQuetes.reconnaitre(["Le retour de la bergere", "Meuh Sieurchance"], dans: jeu).reconnues
        #expect(ambigue == [.init(id: 7, etape: nil)])
    }
}
