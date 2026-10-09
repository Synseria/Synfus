import Foundation
import Testing
@testable import Synfus

/// Les objectifs lus sous chaque quête du suivi : ceux encore à faire, et
/// ceux qu'on en déduit faits. Textes et identifiants tirés de DofusDB, lignes
/// d'une vraie capture du suivi.
struct SuiviObjectifsTests {
    private static func objectif(_ id: Int, _ texte: String) -> ObjectifQuete {
        ObjectifQuete(id: id, textes: ["fr": texte], x: nil, y: nil, carte: nil, objet: nil, quantite: nil, type: nil)
    }

    private static func quete(_ id: Int, _ nom: String, _ etapes: [[ObjectifQuete]]) -> Quete {
        Quete(id: id, noms: ["fr": nom], niveau: 1, groupe: false, donjon: false, prerequis: [], critere: nil,
              etapes: etapes.map { EtapeQuete(noms: [:], descriptions: [:], objectifs: $0, recompenses: .aucune) })
    }

    private static func ames(_ premier: Int, _ monstres: ClosedRange<Int>) -> [ObjectifQuete] {
        monstres.enumerated().map { objectif(premier + $0.offset, "Rapporter 1 âme de {monster,\($0.element)} à {npc,10}.") }
    }

    private static let jeu = SuiviQuetes.Index(Quetes(
        format: Quetes.formatActuel, date: .now,
        quetes: [
            quete(456, "Pense-bête", [[
                objectif(3099, "Aller voir {npc,1}"), objectif(3100, "Aller voir {npc,2}"),
                objectif(3101, "Interroger les habitants dans la Montagne des Koalaks"),
                objectif(3102, "Aller voir {npc,3}"), objectif(3103, "Aller voir {npc,4}"),
                objectif(3104, "Suivre les instructions de {npc,4}"),
                objectif(3105, "Retrouver Meuh Sieurchance chez lui, au village des éleveurs"),
                objectif(3106, "Aller voir {npc,5}"), objectif(3107, "Montrer à {npc,6} : 1 {item,1}"),
            ]]),
            quete(2442, "La raison du plus fort", [[
                objectif(18459, "Explorer le territoire des Bworks à la recherche de survivants du clan de la Forêt Maléfique"),
                objectif(18460, "Entrer dans l'Akadémie des Gobs"),
                objectif(18461, "Vaincre x1 {monster,30} en un seul combat"),
                objectif(18462, "Aller voir {npc,7}"),
            ]]),
            quete(439, "L'éternelle moisson", [ames(2266, 50...57), ames(2286, 60...62)]),
            quete(1467, "Naissance d'une vocation", [[
                objectif(8154, "Localiser les responsables de la profanation"),
                objectif(8155, "Battre Profana Tryss et Nikono Klaste"),
                objectif(8156, "Montrer à {npc,8} : 1 {item,2}"),
                objectif(8166, "Examiner l'arche de l'ancien quartier des éleveurs"),
                objectif(8167, "Utiliser la boussole de Mériana puis se rendre à l'endroit indiqué"),
            ]]),
            quete(157, "La voie du guerrier", [
                [objectif(621, "Vaincre x1 {monster,40} en un seul combat"),
                 objectif(5500, "Découvrir la carte : Sortie du Repaire de Skeunk"), objectif(622, "Retourner voir {npc,9}")],
                [objectif(625, "Vaincre x1 {monster,41} en un seul combat"),
                 objectif(5504, "Découvrir la carte : Sortie du Labyrinthe du Minotot"), objectif(626, "Retourner voir {npc,9}")],
            ]),
            quete(900, "Le commandant", [[
                objectif(1, "Aller voir {npc,11}"), objectif(2, "Ramener à {npc,11} : x1 {item,1}"),
                objectif(3, "Aller voir {npc,11}"), objectif(4, "Vaincre x1 {monster,30} en un seul combat"),
                objectif(5, "Aller voir {npc,11}"),
            ]]),
            quete(901, "Les jumelles", [
                [objectif(11, "Aller voir {npc,11}")], [objectif(12, "Aller voir {npc,11}")],
            ]),
            quete(902, "Chasse au Skeunk", [[
                ObjectifQuete(id: 31, textes: ["fr": "Vaincre x8 {monster,40} sur la carte {map,216531204} en un seul combat"],
                              x: -25, y: 33, carte: 216531204, objet: nil, quantite: nil, type: 16),
                objectif(32, "Retourner voir {npc,9}"),
            ]]),
        ],
        pnjs: [],
        objets: ["1": ["fr": "Pensée perdue"], "2": ["fr": "Document Compromettant"]],
        monstres: [
            "50": ["fr": "Mob l'Éponge"], "51": ["fr": "Bouftou Royal"], "52": ["fr": "Tournesol Affamé"],
            "53": ["fr": "Gelée Royale Bleuet"], "54": ["fr": "Shin Larve"], "55": ["fr": "Rakoopeur"],
            "56": ["fr": "Scarabosse Doré"], "57": ["fr": "Gelée Royale Menthe"],
            "60": ["fr": "Gelée Royale Fraise"], "61": ["fr": "Hell Mina"], "62": ["fr": "Tanukouï San"],
            "30": ["fr": "Directeur Grunob"], "40": ["fr": "Skeunk"], "41": ["fr": "Minotot"],
        ],
        nomsPNJ: [
            "1": ["fr": "Merlan l'Enchaîneur"], "2": ["fr": "Mage Ax"], "3": ["fr": "Meuh Sieurchance"],
            "4": ["fr": "Surivitna"], "5": ["fr": "Greu Nouille"], "6": ["fr": "Danathor"],
            "7": ["fr": "Directeur Grunob"], "8": ["fr": "Capitaine Starky"], "9": ["fr": "Maître des clefs"],
            "10": ["fr": "Assistante d'Otomaï"], "11": ["fr": "Commandant Ymagiroh"],
        ],
        sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:], titres: [:], metiers: [:], camps: [:]))

    private func lu(_ lignes: [String], coupe: Bool = false) -> [SuiviQuetes.Reconnue] {
        SuiviQuetes.reconnaitre(lignes, coupe: coupe, dans: Self.jeu).reconnues
    }

    /// Le jeu écrit une carte citée par ses coordonnées, comme un monstre par
    /// son nom entre crochets : le texte comparé les porte aussi.
    @Test("Un objectif qui cite une carte se lit par ses coordonnées")
    func carteCitee() {
        let lues = lu(["Chasse au Skeunk", "Vaincre x8 [Skeunk] sur la carte [-25,33] en un", "seul combat"])
        #expect(lues.map(\.id) == [902] && lues.first?.aFaire == [31] && lues.first?.faits == [])
    }

    @Test("La capture réelle : les objectifs montrés à faire, ceux d'avant faits, étapes d'avant comprises")
    func captureReelle() {
        let reconnues = lu([
            "Suivi de quêtes",
            "Pense-bête",
            "? Retrouver Meuh Sieurchance chez lui, au village des",
            "éleveurs",
            "La raison du plus fort",
            "• Entrer dans l'Akadémie des Gobs",
            "L'éternelle moisson",
            "Rapporter 1 âme de Gelée Royale Bleuet à",
            "Assistante d'Otomaï.",
            "Rapporter 1 âme de Shin Larve à Assistante d'Otomaï.",
            "Rapporter 1 âme de Rakoopeur à Assistante",
            "d'Otomaï.",
            "VOIR PLUS…",
            "Naissance d'une vocation",
            "Examiner l'arche de l'ancien quartier des éleveurs",
            "La voie du guerrier",
            "Vaincre x1 [Minotot] en un seul combat",
            "Découvrir la carte : Sortie du Labyrinthe du Minotot",
        ])
        #expect(reconnues == [
            .init(id: 456, etape: nil, aFaire: [3105], faits: [3099, 3100, 3101, 3102, 3103, 3104],
                  nonMontres: [3106, 3107]),
            .init(id: 2442, etape: nil, aFaire: [18460], faits: [18459], nonMontres: [18461, 18462]),
            // « VOIR PLUS » cache la suite, pas ce qui précède : rien n'en est tu.
            .init(id: 439, etape: 0, etapeSure: true, aFaire: [2269, 2270, 2271], faits: [2266, 2267, 2268]),
            .init(id: 1467, etape: nil, aFaire: [8166], faits: [8154, 8155, 8156], nonMontres: [8167]),
            .init(id: 157, etape: 1, etapeSure: true, aFaire: [625, 5504], faits: [621, 5500, 622], nonMontres: [626]),
        ])
    }

    @Test("Les fautes de l'OCR n'empêchent pas de reconnaître l'objectif")
    func fautes() {
        let reconnues = lu(["L'eternelle moisson", "Rapporter 1 ame de Shin Larvc a Assistante d'0tomai",
                            "Rapporter 1 âme de Gelee Royaie Menthe à Assistante d'Otomaï"])
        // Rakoopeur et Scarabosse, entre les deux, ne sont pas montrés : pas
        // encore ouverts, ou rapportés hors de l'ordre — rien n'en est déduit fait.
        #expect(reconnues == [.init(id: 439, etape: 0, etapeSure: true, aFaire: [2270, 2273], faits: [2266, 2267, 2268, 2269],
                                    nonMontres: [2271, 2272])])
    }

    /// « Le commandant » : Aller voir Ymagiroh (1), Ramener (2), Aller voir
    /// Ymagiroh (3), Vaincre (4), Aller voir Ymagiroh (5).
    @Test("Un même texte à plusieurs rangs : les lignes suivantes départagent, sinon le plus tôt", arguments: [false, true])
    func doublons(tronque: Bool) {
        let fin = tronque ? ["VOIR PLUS…"] : []
        func lu(_ lignes: [String]) -> SuiviQuetes.Reconnue? { self.lu(["Le commandant"] + lignes + fin).first }
        let ymagiroh = "Aller voir Commandant Ymagiroh"
        // Tronquée, la liste ne tait rien après son dernier objectif montré.
        func taits(_ entiere: [Int], _ coupee: [Int]) -> [Int] { tronque ? coupee : entiere }
        // Seul, il peut être le premier : rien n'est fait. Ou le dernier :
        // rien n'est sûrement tu.
        #expect(lu([ymagiroh]) == .init(id: 900, etape: nil, aFaire: [1], faits: []))
        // Avant « Vaincre » : le premier ou le deuxième, le plus tôt l'emporte ;
        // seul le dernier est sûrement tu.
        #expect(lu([ymagiroh, "Vaincre x1 Directeur Grunob en un seul combat"])
                == .init(id: 900, etape: nil, aFaire: [1, 4], faits: [], nonMontres: taits([5], [])))
        // Après « Ramener » : le deuxième ou le troisième, et ce qui précède « Ramener » est fait.
        #expect(lu(["Ramener à Commandant Ymagiroh : x1 Pensée perdue", ymagiroh])
                == .init(id: 900, etape: nil, aFaire: [2, 3], faits: [1], nonMontres: taits([4], [])))
        // Après « Vaincre » : forcément le dernier.
        #expect(lu(["Vaincre x1 Directeur Grunob en un seul combat", ymagiroh])
                == .init(id: 900, etape: nil, aFaire: [4, 5], faits: [1, 2, 3]))
        // Deux fois : les deux premiers, ou n'importe quels deux — seul le
        // « Vaincre » est sûrement tu.
        #expect(lu([ymagiroh, ymagiroh])
                == .init(id: 900, etape: nil, aFaire: [1, 3], faits: [], nonMontres: taits([4], [])))
    }

    @Test("Une suite d'objectifs répétée plus loin dans l'étape : rien n'en est tu ni fait")
    func suiteRepetee() {
        let jeu = SuiviQuetes.Index(Quetes(format: Quetes.formatActuel, date: .now, quetes: [
            Self.quete(905, "La pêche", [[
                Self.objectif(71, "Aller voir Mage Ax"), Self.objectif(72, "Escorter Mage Ax jusqu'à Sufokia"),
                Self.objectif(73, "Aller voir Greu Nouille"),
                Self.objectif(74, "Aller voir Mage Ax"), Self.objectif(75, "Escorter Mage Ax jusqu'à Sufokia"),
            ]]),
        ], pnjs: [], objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:],
        emotes: [:], titres: [:], metiers: [:], camps: [:]))
        // Les deux premiers, ou les deux derniers : « Aller voir Greu Nouille »
        // n'est pas sûrement tu.
        let lu = SuiviQuetes.reconnaitre(["La pêche", "Aller voir Mage Ax", "Escorter Mage Ax jusqu'à Sufokia"], dans: jeu)
        #expect(lu.reconnues == [.init(id: 905, etape: nil, aFaire: [71, 72], faits: [])])
    }

    @Test("Une ligne non reconnue avant le premier objectif empêche de conclure, après non")
    func ligneInconnue() {
        let retrouver = "Retrouver Meuh Sieurchance chez lui, au village des éleveurs"
        #expect(lu(["Pense-bête", "Parler au forgeron", retrouver])
                == [.init(id: 456, etape: nil, aFaire: [3105], faits: [])])
        #expect(lu(["Pense-bête", retrouver, "Parler au forgeron"])
                == [.init(id: 456, etape: nil, aFaire: [3105], faits: [3099, 3100, 3101, 3102, 3103, 3104])])
    }

    @Test("L'écran dans le désordre de l'étape : rien n'est déduit fait")
    func desordre() {
        #expect(lu(["La raison du plus fort", "Aller voir Directeur Grunob", "Entrer dans l'Akadémie des Gobs"])
                == [.init(id: 2442, etape: nil, aFaire: [18462, 18460], faits: [])])
    }

    @Test("Une étape lue moins bien qu'une autre sur une ligne : les étapes d'avant ne sont pas cochées")
    func etapePasSure() {
        let jeu = Quetes(format: Quetes.formatActuel, date: .now, quetes: [
            Self.quete(902, "Le bricoleur", [
                [Self.objectif(21, "Parler à Bob le Bricoleur"), Self.objectif(22, "Aller voir Mage Ax")],
                [Self.objectif(31, "Aller voir Greu Nouille"), Self.objectif(32, "Parler à Bob le Bricoleux"),
                 Self.objectif(33, "Ramener à Danathor : x1 Pensée perdue")],
            ]),
        ], pnjs: [], objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:],
        emotes: [:], titres: [:], metiers: [:], camps: [:])
        let reconnues = SuiviQuetes.reconnaitre(["Le bricoleur", "Parler à Bob le Bricoleur",
                                                 "Ramener à Danathor : x1 Pensée perdue"], dans: .init(jeu)).reconnues
        #expect(reconnues == [.init(id: 902, etape: 1, etapeSure: false, aFaire: [32, 33], faits: [31])])
    }

    @Test("Une quantité qu'une faute changerait ne prouve ni les objectifs d'avant ni l'étape")
    func quantites() {
        let jeu = SuiviQuetes.Index(Quetes(format: Quetes.formatActuel, date: .now, quetes: [
            Self.quete(903, "Le marchand", [
                [Self.objectif(41, "Ramener à Danathor : x3 Pensée perdue"), Self.objectif(42, "Aller voir Mage Ax"),
                 Self.objectif(43, "Ramener à Danathor : x5 Pensée perdue")],
                [Self.objectif(51, "Ramener à Danathor : x8 Pensée perdue")],
            ]),
        ], pnjs: [], objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:],
        emotes: [:], titres: [:], metiers: [:], camps: [:]))
        func lu(_ lignes: [String]) -> [SuiviQuetes.Reconnue] {
            SuiviQuetes.reconnaitre(["Le marchand"] + lignes, dans: jeu).reconnues
        }
        // « x5 » se lit à une faute de « x3 » et de « x8 » : ni les deux premiers
        // faits, ni l'étape établie.
        #expect(lu(["Ramener à Danathor : x5 Pensée perdue"]) == [.init(id: 903, etape: 0, aFaire: [43], faits: [])])
        #expect(lu(["Ramener à Danathor : x3 Pensée perdue"]) == [.init(id: 903, etape: 0, aFaire: [41], faits: [])])
        // Après « Aller voir », « x5 » ne peut être « x3 » : l'ordre de l'étape
        // le place, et la ligne que la seconde étape n'explique pas l'établit.
        #expect(lu(["Aller voir Mage Ax", "Ramener à Danathor : x5 Pensée perdue"])
                == [.init(id: 903, etape: 0, etapeSure: true, aFaire: [42, 43], faits: [41])])
    }

    @Test("Deux étapes qui se lisent aussi bien : ni étape ni objectif")
    func etapeIncertaine() {
        #expect(lu(["Les jumelles", "Aller voir Commandant Ymagiroh"]) == [.init(id: 901, etape: nil)])
    }

    @Test("Deux objectifs voisins ne se fondent pas en un")
    func voisins() {
        #expect(lu(["Le commandant", "Ramener à Commandant Ymagiroh : x1 Pensée perdue", "Aller voir Commandant Ymagiroh"])
                == [.init(id: 900, etape: nil, aFaire: [2, 3], faits: [1], nonMontres: [4])])
    }

    @Test("Le texte au bas de la zone : la dernière quête lue ne tait rien après son dernier objectif")
    func coupeeParLaZone() {
        let lignes = ["Naissance d'une vocation", "Examiner l'arche de l'ancien quartier des éleveurs",
                      "Le commandant", "Ramener à Commandant Ymagiroh : x1 Pensée perdue"]
        #expect(lu(lignes) == [
            .init(id: 1467, etape: nil, aFaire: [8166], faits: [8154, 8155, 8156], nonMontres: [8167]),
            .init(id: 900, etape: nil, aFaire: [2], faits: [1], nonMontres: [3, 4, 5]),
        ])
        #expect(lu(lignes, coupe: true) == [
            .init(id: 1467, etape: nil, aFaire: [8166], faits: [8154, 8155, 8156], nonMontres: [8167]),
            .init(id: 900, etape: nil, aFaire: [2], faits: [1]),
        ])
    }

    @Test("« VOIR PLUS… » se reconnaît malgré une faute, dans les langues du jeu")
    func troncature() {
        for ligne in ["VOIR PLUS…", "VOIR PLU5...", "SEE MORE…", "VER MÁS…"] {
            #expect(lu(["Pense-bête", "Retrouver Meuh Sieurchance chez lui, au village des éleveurs", ligne])
                    == [.init(id: 456, etape: nil, aFaire: [3105], faits: [3099, 3100, 3101, 3102, 3103, 3104])],
                    "\(ligne)")
        }
    }
}
