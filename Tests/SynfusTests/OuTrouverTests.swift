import Foundation
import Testing
@testable import Synfus

/// Où trouver un monstre ou un objet : l'assemblage des réponses de DofusDB,
/// la case choisie dans chaque repaire, l'ordre des repaires et des lâcheurs.
struct OuTrouverTests {

    // MARK: - Une petite carte

    private static func lieu(_ id: Int, _ x: Int, _ y: Int, monde: Int = Zaap.mondeDesDouze, carte: Int = 0,
                             sousZone: Int = 0, categorie: Int = CategorieLieu.divers.rawValue,
                             nom: String = "Lieu") -> Lieu {
        Lieu(id: id, x: x, y: y, monde: monde, idCarte: carte, idSousZone: sousZone, categorie: categorie, gfx: nil,
             noms: ["fr": nom], zone: [:], sousZone: [:])
    }

    /// La sous-zone 5 de 0,0 à 4,0 ; la 6 en 10,10 ; la 7, intérieur sans case,
    /// n'a qu'un repère ; un donjon en 20,20 dont l'entrée est sa carte 900.
    private static let carte = Carte(
        date: .now,
        lieux: [lieu(1, 30, 30, sousZone: 7, nom: "Atelier"),
                lieu(2, 20, 20, carte: 900, sousZone: 6, categorie: CategorieLieu.donjon.rawValue, nom: "Antre du Dragon Cochon"),
                lieu(3, -1, -1, monde: 2, sousZone: 8, nom: "Pâturages")],
        sousZones: [SousZoneCarte(id: 5, zaap: nil, voisines: [6]), SousZoneCarte(id: 6, zaap: nil, voisines: [5]),
                    SousZoneCarte(id: 7, zaap: nil, voisines: [])],
        cases: ["0,0": 5, "1,0": 5, "2,0": 5, "3,0": 5, "4,0": 5, "10,10": 6])
    private let reseau = ReseauSousZones(Self.carte)

    private func repaire(_ genre: RepaireMonstre.Genre, _ id: Int, nom: String = "R", entree: Int? = nil) -> RepaireMonstre {
        RepaireMonstre(genre: genre, id: id, noms: ["fr": nom], entree: entree)
    }

    private func situer(_ repaire: RepaireMonstre, depuis: (x: Int, y: Int)?) -> OuTrouver.Situation? {
        OuTrouver.situer(repaire, depuis: depuis, reseau: reseau, reperes: ReperesCarte(Self.carte.lieux))
    }

    @Test("L'index inverse de la carte : les cases d'une sous-zone, et son monde")
    func casesDUneSousZone() {
        #expect(reseau.cases(5).map { [$0.x, $0.y] } == [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]])
        #expect(reseau.cases(7).isEmpty)
        #expect(reseau.estDuMondeDesDouze(7) && !reseau.estDuMondeDesDouze(8))
        // La carte intégrée situe des milliers de cases.
        let integree = ReseauSousZones(Carte.integree)
        #expect(Carte.integree.sousZones.contains { !integree.cases($0.id).isEmpty })
    }

    @Test("Une sous-zone : sa case la plus proche du perso, son milieu sans position, sinon un repère")
    func sousZone() {
        #expect(situer(repaire(.sousZone, 5), depuis: (10, 1)) == .init(x: 4, y: 0, monde: 1))
        #expect(situer(repaire(.sousZone, 5), depuis: nil) == .init(x: 2, y: 0, monde: 1))
        #expect(situer(repaire(.sousZone, 7), depuis: (0, 0)) == .init(x: 30, y: 30, monde: 1))
        // Un autre monde : le repère garde le sien, qui dira « pas de zaap ».
        #expect(situer(repaire(.sousZone, 8), depuis: (0, 0)) == .init(x: -1, y: -1, monde: 2))
        #expect(situer(repaire(.sousZone, 99), depuis: (0, 0)) == nil)
    }

    @Test("Un donjon : son repère, par sa carte d'entrée, sinon par son nom ; une expédition n'est nulle part")
    func donjon() {
        #expect(situer(repaire(.donjon, 1, entree: 900), depuis: nil) == .init(x: 20, y: 20, monde: 1))
        #expect(situer(repaire(.donjon, 1, nom: "Antre du dragon cochon", entree: 4), depuis: nil)
                == .init(x: 20, y: 20, monde: 1))
        #expect(situer(repaire(.donjon, 2, nom: "Expédition - Antre du Dragon Cochon", entree: 5), depuis: nil) == nil)
    }

    @Test("Les repères indexés : à clé égale le premier de la carte, un donjon seulement parmi les donjons")
    func reperes() {
        let donjon = CategorieLieu.donjon.rawValue
        let reperes = ReperesCarte([Self.lieu(1, 0, 0, carte: 7, sousZone: 3, nom: "Antre"),
                                    Self.lieu(2, 1, 1, carte: 8, sousZone: 3, categorie: donjon, nom: "Antre"),
                                    Self.lieu(3, 2, 2, carte: 9, sousZone: 4, categorie: donjon, nom: "Antre"),
                                    Self.lieu(4, 3, 3, carte: 8, sousZone: 4, categorie: donjon, nom: "Château")])
        #expect(reperes.lieu(sousZone: 3)?.id == 1 && reperes.lieu(sousZone: 4)?.id == 3 && reperes.lieu(sousZone: 5) == nil)
        #expect(reperes.donjon(carte: 8)?.id == 2 && reperes.donjon(carte: 7) == nil)
        #expect(reperes.donjon(nom: "ANTRE")?.id == 2 && reperes.donjon(nom: "chateau")?.id == 4)
    }

    @Test("Les repaires du plus proche au plus loin, zaaps compris ; sans coût après, dans l'ordre ; introuvables écartés")
    func ordreDesRepaires() {
        let repaires = [repaire(.sousZone, 8, nom: "Ailleurs"), repaire(.sousZone, 99, nom: "Nulle part"),
                        repaire(.sousZone, 6, nom: "Loin"), repaire(.sousZone, 5, nom: "Près")]
        // Un coût où 10,10 est plus proche que 4,0 (un zaap y mène).
        let situes = OuTrouver.situes(repaires, depuis: (8, 0), reseau: reseau,
                                      reperes: ReperesCarte(Self.carte.lieux)) { cible in
            cible == (10, 10) ? 1 : ItineraireZaap.distance((8, 0), cible)
        }
        #expect(situes.map { $0.repaire.noms["fr"] } == ["Loin", "Près", "Ailleurs"])
        #expect(situes.map(\.cartes) == [1, 4, nil])
    }

    // MARK: - DofusDB

    private static func decoder<T: Decodable>(_ json: String) throws -> [T] {
        try JSONDecoder().decode(DofusDB.Page<T>.self, from: Data(json.utf8)).data
    }

    private static let monstres = """
    {"total":2,"data":[
      {"id":101,"name":{"fr":"Bouftou"},"subareas":[5,82],
       "drops":[{"objectId":384,"percentDropForGrade5":53},{"objectId":2455,"percentDropForGrade5":8.8}]},
      {"id":121,"name":{"fr":"Minotoror"},"subareas":[210],
       "drops":[{"objectId":384,"percentDropForGrade5":0,"maxPercentDrop":60}]}]}
    """
    private static let sousZones = """
    {"total":3,"data":[{"id":5,"name":{"fr":"Coin des Bouftous"},"dungeonId":-1},
      {"id":82,"name":{"fr":"Cour du Bouftou Royal"},"dungeonId":1},
      {"id":210,"name":{"fr":"Centre du labyrinthe"},"dungeonId":4}]}
    """
    private static let donjons = """
    {"total":1,"data":[{"id":1,"name":{"fr":"Cour du Bouftou Royal"},"entranceMapId":120063489,"subarea":82,
      "monsters":[101,134]}]}
    """
    private static let recette = """
    {"total":1,"data":[{"resultId":384,"resultLevel":20,"ingredientIds":[2,1],"quantities":[3,1],"jobId":27,
      "job":{"id":27,"name":{"fr":"Tailleur"}},
      "ingredients":[{"id":1,"name":{"fr":"Fil"}},{"id":2,"name":{"fr":"Laine"}}]}]}
    """

    @Test("Un monstre : ses sous-zones, puis ses donjons à la place de leurs salles")
    func ficheMonstre() throws {
        let monstres: [OuTrouverDofusDB.MonstreAPI] = try Self.decoder(Self.monstres)
        let fiche = OuTrouverDofusDB.fiche(monstres[0], sousZones: try Self.decoder(Self.sousZones),
                                           donjons: try Self.decoder(Self.donjons))
        #expect(fiche.repaires == [
            RepaireMonstre(genre: .sousZone, id: 5, noms: ["fr": "Coin des Bouftous"], entree: nil),
            RepaireMonstre(genre: .donjon, id: 1, noms: ["fr": "Cour du Bouftou Royal"], entree: 120063489),
        ])
        // Une salle de donjon dont DofusDB ne rend pas le donjon reste une sous-zone (que rien ne situera).
        let minotoror = OuTrouverDofusDB.fiche(monstres[1], sousZones: try Self.decoder(Self.sousZones), donjons: [])
        #expect(minotoror.repaires.map(\.id) == [210])
    }

    @Test("Un objet : les lâcheurs du plus généreux au moins généreux, la recette dans l'ordre de DofusDB")
    func sourcesObjet() throws {
        let sources = OuTrouverDofusDB.assembler(
            objet: 384, monstres: try Self.decoder(Self.monstres), sousZones: try Self.decoder(Self.sousZones),
            donjons: try Self.decoder(Self.donjons), recette: try Self.decoder(Self.recette).first)
        #expect(sources.lacheurs.map(\.monstre.id) == [121, 101])
        #expect(sources.lacheurs.map(\.taux) == [60, 53])
        #expect(sources.recette == SourcesObjet.Recette(
            metier: ["fr": "Tailleur"], niveau: 20,
            ingredients: [.init(noms: ["fr": "Laine"], quantite: 3), .init(noms: ["fr": "Fil"], quantite: 1)]))
        let rien = OuTrouverDofusDB.assembler(objet: 1, monstres: [], sousZones: [], donjons: [], recette: nil)
        #expect(rien.lacheurs.isEmpty && rien.recette == nil)
    }

    @Test("Les lâcheurs : le repaire le plus proche d'abord ; sans position, le plus généreux")
    func ordreDesLacheurs() {
        func fiche(_ id: Int) -> FicheMonstre { FicheMonstre(id: id, noms: [:], repaires: []) }
        let sources = SourcesObjet(lacheurs: [.init(monstre: fiche(1), taux: 50), .init(monstre: fiche(2), taux: 10),
                                              .init(monstre: fiche(3), taux: 30)], recette: nil)
        func situe(_ cartes: Int?) -> [RepaireSitue] {
            [RepaireSitue(repaire: repaire(.sousZone, 5), situation: .init(x: 0, y: 0, monde: 1), cartes: cartes)]
        }
        let proches = OuTrouver.lacheurs(sources) { $0.id == 2 ? situe(3) : $0.id == 3 ? situe(9) : [] }
        #expect(proches.map(\.lacheur.monstre.id) == [2, 3, 1])
        let sansPosition = OuTrouver.lacheurs(sources) { _ in situe(nil) }
        #expect(sansPosition.map(\.lacheur.monstre.id) == [1, 3, 2])
    }

    @Test("Le cache se relit dans sa forme, une autre forme repart de zéro")
    func cache() throws {
        var cache = CacheOuTrouver()
        cache.monstres["1"] = .init(date: .now, valeur: FicheMonstre(id: 1, noms: ["fr": "Bouftou"], repaires: []))
        let relu = CacheOuTrouver.relire(try JSONEncoder().encode(cache))
        #expect(relu.monstres["1"]?.valeur.noms == ["fr": "Bouftou"])
        #expect(CacheOuTrouver.relire(Data(#"{"format":0,"monstres":{},"objets":{}}"#.utf8)).monstres.isEmpty)
        #expect(CacheOuTrouver.relire(nil).objets.isEmpty)
    }

    // MARK: - Ce que cite un objectif

    private func objectif(_ texte: String, objet: Int? = nil) -> ObjectifQuete {
        ObjectifQuete(id: 1, textes: ["fr": texte], x: nil, y: nil, carte: nil, objet: objet, quantite: objet.map { _ in 1 },
                      type: nil)
    }

    @Test("Un objectif dit où trouver son monstre, sinon l'objet qu'il cite sans le faire ramener")
    func sujetDUnObjectif() {
        #expect(Quetes.sujet(objectif("Vaincre x1 {monster,827} en un seul combat")) == .monstre(827))
        #expect(Quetes.sujet(objectif("Utiliser {item,12} sur {monster,7}")) == .monstre(7))
        #expect(Quetes.sujet(objectif("Utiliser {item,12}")) == .objet(12))
        // L'objet à ramener est dans les ressources, qui disent déjà où le trouver.
        #expect(Quetes.sujet(objectif("Ramener à {npc,1} : x3 {item,12}", objet: 12)) == nil)
        #expect(Quetes.sujet(objectif("Aller voir {npc,1}")) == nil)
    }
}
