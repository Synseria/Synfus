import Foundation
import Testing
@testable import Synfus

/// Le tri « Auto » de la palette : fautes de frappe tolérées, score, habitudes.
struct ScorePaletteTests {

    /// Des PNJ seuls, sans position du perso : ni distance ni zaap ne départagent.
    private func contexte(_ noms: [String], frequentation: [String: FrequentationPalette.Compte] = [:]) -> ContextePalette {
        let pnjs = noms.enumerated().map { rang, nom in
            PNJ(id: rang + 1, noms: ["fr": nom],
                passages: [PNJ.Passage(position: .init(x: rang, y: 0), carte: nil, sousZone: nil, quetes: 1)])
        }
        var contexte = ContextePalette()
        contexte.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: [], pnjs: pnjs,
            objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:],
            titres: [:], metiers: [:], camps: [:])
        contexte.frequentation = FrequentationPalette(frequentation)
        return contexte
    }

    private func titres(_ requete: String, _ contexte: ContextePalette) -> [String] {
        RecherchePalette.entrees(requete, contexte).map(\.titre)
    }

    // MARK: - Fautes de frappe

    @Test("« Funoroshi » et « funoro » trouvent « Founoroshi »")
    func faute() {
        let founoroshi = contexte(["Founoroshi", "Bworkette"])
        #expect(titres("Funoroshi", founoroshi) == ["Founoroshi"])
        #expect(titres("funoro", founoroshi) == ["Founoroshi"])
        #expect(titres("fonn", founoroshi) == ["Founoroshi"])
        #expect(titres("bwarkette", founoroshi) == ["Bworkette"])
    }

    @Test("Un mot de trois lettres ne tolère aucune faute")
    func motCourt() {
        #expect(titres("fon", contexte(["Founoroshi"])).isEmpty)
        #expect(RecherchePalette.Champs.tolerance("fon") == nil)
        #expect(RecherchePalette.Champs.tolerance("funo") == 1 && RecherchePalette.Champs.tolerance("funoroshi") == 2)
    }

    @Test("Assez de résultats exacts : la tolérance ne joue pas ; sinon les approchés viennent après")
    func seuil() {
        let lettres = "ABCDEFGH".map(String.init)
        let assez = contexte(lettres.prefix(RecherchePalette.seuilTolerance).map { "Funoro \($0)" } + ["Founoroshi"])
        #expect(!titres("funoro", assez).contains("Founoroshi"))
        let peu = contexte(lettres.prefix(RecherchePalette.seuilTolerance - 1).map { "Funoro \($0)" } + ["Founoroshi"])
        let trouves = titres("funoro", peu)
        #expect(trouves.last == "Founoroshi" && trouves.count == RecherchePalette.seuilTolerance)
    }

    @Test("Une correspondance exacte bat une entrée très fréquentée mais seulement approchée")
    func exactDevant() {
        let noms = ["Founoroshi", "Funoroshi"]
        let habitue = contexte(noms, frequentation: ["pnj:1": .init(fois: 500, dernier: 1)])
        #expect(titres("funoroshi", habitue) == ["Funoroshi", "Founoroshi"])
    }

    // MARK: - Score

    @Test("À correspondance égale, l'entrée la plus fréquentée passe devant")
    func habitudes() {
        let noms = ["Bworkette", "Bworkette"]
        let ids = { (contexte: ContextePalette) in RecherchePalette.entrees("bwork", contexte).compactMap(\.cle) }
        #expect(ids(contexte(noms)) == ["pnj:1", "pnj:2"])
        let habitue = contexte(noms, frequentation: ["pnj:1": .init(fois: 1, dernier: 9), "pnj:2": .init(fois: 5, dernier: 1)])
        #expect(ids(habitue) == ["pnj:2", "pnj:1"])
        // Même palier : le plus récent.
        let recent = contexte(noms, frequentation: ["pnj:1": .init(fois: 4, dernier: 1), "pnj:2": .init(fois: 6, dernier: 2)])
        #expect(ids(recent) == ["pnj:2", "pnj:1"])
    }

    @Test("Les habitudes s'écrasent en paliers : un de plus à chaque doublement")
    func paliers() {
        #expect([0, 1, 2, 3, 4, 7, 8, 100].map(ScorePalette.palier) == [0, 1, 2, 2, 3, 3, 4, 7])
    }

    private let parGenre = [
        EntreePalette(id: "quete:1", genre: .quete, titre: "Q", effet: .ouvrirQuete(1)),
        EntreePalette(id: "pnj:1:0,0", genre: .pnj, titre: "P", cle: "pnj:1", effet: .trajet(x: 0, y: 0, sousZone: nil)),
        EntreePalette(id: "lieu:1", genre: .lieu, titre: "L", cle: "lieu:1", effet: .trajet(x: 1, y: 1, sousZone: nil)),
        EntreePalette(id: "boss:1", genre: .monstre, titre: "B", effet: .donjon(1)),
        EntreePalette(id: "zaap:1:0,0", genre: .zaap, titre: "Z", cle: "1:0,0", effet: .copier("/zaap 0,0")),
    ]

    private func ranges(_ entrees: [EntreePalette], correspondance: Int?) -> [String] {
        let scores = entrees.map { ScorePalette($0, correspondance: correspondance, compte: nil) }
        return entrees.indices.sorted { ScorePalette.avant(scores[$0], scores[$1]) ?? ($0 < $1) }.map { entrees[$0].titre }
    }

    @Test("À score égal : zaap, boss, PNJ, puis le reste dans l'ordre d'arrivée ; sans requête, le genre ne compte pas")
    func genres() {
        #expect(ranges(parGenre, correspondance: 60) == ["Z", "B", "P", "Q", "L"])
        #expect(ranges(parGenre, correspondance: nil) == ["Q", "P", "L", "B", "Z"])
        #expect(parGenre[3].estBoss && !parGenre[3].enDernier)
        #expect(EntreePalette(id: "action:x", genre: .action, titre: "A",
                              effet: .action(.boss(.special(.kimbo), nom: "Kimbo"))).estBoss)
    }

    @Test("L'ordre est total et le même d'un calcul à l'autre")
    func ordreTotal() {
        var generateur = SystemRandomNumberGenerator()
        let genres: [EntreePalette.Genre] = [.zaap, .pnj, .lieu]
        let distances: [Int?] = [nil, 1, 2]
        let comptes: [FrequentationPalette.Compte?] = [nil, .init(fois: 1, dernier: 1), .init(fois: 3, dernier: 2)]
        let scores = (0..<60).map { _ in
            ScorePalette(EntreePalette(id: "x", genre: genres.randomElement(using: &generateur)!, titre: "x",
                                       favori: Bool.random(using: &generateur),
                                       distance: distances.randomElement(using: &generateur)!, effet: .copier("")),
                         correspondance: [20, 60].randomElement(using: &generateur),
                         compte: comptes.randomElement(using: &generateur)!)
        }
        for a in scores {
            for b in scores {
                // Antisymétrique : jamais l'un devant l'autre dans les deux sens ; égaux dans les deux sens.
                switch (ScorePalette.avant(a, b), ScorePalette.avant(b, a)) {
                case (true?, true?), (false?, false?): Issue.record("\(a) et \(b) se contredisent")
                case (nil, _?), (_?, nil): Issue.record("\(a) et \(b) : égalité d'un seul côté")
                default: break
                }
                if ScorePalette.avant(a, b) == nil { #expect(a == b) }
            }
        }
        let monde = contexte(["Bworkette", "Bwork", "Bworkon", "Bworknet"])
        #expect(RecherchePalette.entrees("bw", monde) == RecherchePalette.entrees("bw", monde))
    }

    @Test("Sans rien taper, les favoris les plus choisis passent devant les plus proches")
    func accueil() {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna")
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        let (amakna, bonta) = ("1:-2,0", "1:-31,-56")
        contexte.favoris = [amakna, bonta]
        #expect(RecherchePalette.entrees("", contexte).prefix(2).compactMap(\.cle) == [amakna, bonta])
        contexte.frequentation = FrequentationPalette([bonta: .init(fois: 2, dernier: 1)])
        #expect(RecherchePalette.entrees("", contexte).prefix(2).compactMap(\.cle) == [bonta, amakna])
    }

    // MARK: - Fréquentation

    @Test("Seul ce qui mène au jeu compte : une commande, un geste, une copie ne comptent pas")
    func cles() {
        #expect(FrequentationPalette.cle(de: parGenre[0]) == "quete:1")
        #expect(FrequentationPalette.cle(de: parGenre[1]) == "pnj:1")
        #expect(FrequentationPalette.cle(de: parGenre[3]) == "boss:1")
        #expect(FrequentationPalette.cle(de: parGenre[4]) == "1:0,0")
        #expect(FrequentationPalette.cle(de: EntreePalette(id: "cmd:/w", genre: .commande, titre: "/w", effet: .completer("/w "))) == nil)
        #expect(FrequentationPalette.cle(de: EntreePalette(id: "recent:0", genre: .recent, titre: "/a", effet: .copier("/a"))) == nil)
        #expect(FrequentationPalette.cle(de: EntreePalette(id: "action:x", genre: .action, titre: "R",
                                                           effet: .action(.rangerFenetres))) == nil)
    }

    @Test("Le compteur reste borné : le moins choisi s'en va, jamais celui qu'on vient de choisir")
    func borne() {
        var frequentation = FrequentationPalette()
        frequentation.noter("habitue")
        frequentation.noter("habitue")
        for rang in 0..<(FrequentationPalette.taille + 50) { frequentation.noter("\(rang)") }
        #expect(frequentation.comptes.count == FrequentationPalette.taille)
        #expect(frequentation.comptes["habitue"]?.fois == 2)
        #expect(frequentation.comptes["\(FrequentationPalette.taille + 49)"]?.fois == 1)
        #expect(frequentation.comptes["0"] == nil)
    }

    @Test("Les habitudes s'écrivent comme leur table et se relisent")
    func relecture() throws {
        var frequentation = FrequentationPalette()
        frequentation.noter("lieu:2738")
        let donnees = try JSONEncoder().encode(frequentation)
        let objet = try #require(try JSONSerialization.jsonObject(with: donnees) as? [String: [String: Int]])
        #expect(objet == ["lieu:2738": ["fois": 1, "dernier": 1]])
        #expect(try JSONDecoder().decode(FrequentationPalette.self, from: donnees) == frequentation)
    }
}
