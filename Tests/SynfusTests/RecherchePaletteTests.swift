import Foundation
import Testing
@testable import Synfus

/// La recherche de la palette, sur la carte intégrée.
struct RecherchePaletteTests {

    private func contexte(position: PositionCarte? = PositionCarte(x: -2, y: 0, zone: "Amakna"),
                          etiquettes: [String: String] = [:], favoris: Set<String> = []) -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = position
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        contexte.lieux = Carte.integree.lieux
        contexte.etiquettes = etiquettes
        contexte.favoris = favoris
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        return contexte
    }

    private func premiere(_ requete: String, _ contexte: ContextePalette) -> EntreePalette? {
        RecherchePalette.entrees(requete, contexte).first
    }

    @Test("Sans rien taper : les zaaps, favoris d'abord puis du plus proche")
    func grille() {
        let amakna = "1:-2,0", bonta = "1:-31,-56"
        let entrees = RecherchePalette.entrees("", contexte(favoris: [bonta]))
        #expect(entrees.allSatisfy { $0.genre == .zaap })
        #expect(entrees.first?.cle == bonta)
        #expect(entrees.dropFirst().first?.cle == amakna)
    }

    @Test("Sans rien taper : les lieux et PNJ favoris avec les zaaps favoris, du plus proche, puis les autres zaaps")
    func grilleDesFavoris() throws {
        let banque = try #require(Carte.integree.lieux.first { $0.nom(en: .fr) == "Banque" && $0.zone(en: .fr) == "Bonta" })
        var avecQuetes = contexte(etiquettes: ["pnj:6309": "Ama"], favoris: ["1:-31,-56", banque.cle, "pnj:6309"])
        let passage = { (x: Int, y: Int, quetes: Int) in PNJ.Passage(position: .init(x: x, y: y), carte: nil, sousZone: nil, quetes: quetes) }
        avecQuetes.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: [],
            pnjs: [PNJ(id: 6309, noms: ["fr": "Amayiro"], passages: [passage(-32, -57, 101), passage(0, 0, 1)])],
            objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:],
            titres: [:], metiers: [:], camps: [:])
        let entrees = RecherchePalette.entrees("", avecQuetes)
        let favoris = entrees.prefix { $0.favori }
        #expect(Set(favoris.compactMap(\.cle)) == ["1:-31,-56", banque.cle, "pnj:6309"])
        #expect(favoris.compactMap(\.distance) == favoris.compactMap(\.distance).sorted())
        // Le PNJ n'y paraît qu'une fois, à sa case habituelle, avec son étiquette.
        let amayiro = try #require(favoris.first { $0.genre == .pnj })
        #expect(amayiro.detail == Coordonnees.texte(-32, -57) && amayiro.etiquette == "Ama")
        #expect(entrees.dropFirst(favoris.count).allSatisfy { $0.genre == .zaap && !$0.favori })
        // Ses deux cases se cherchent, étoilées l'une et l'autre.
        #expect(RecherchePalette.entrees("amayiro", avecQuetes).filter(\.favori).count == 2)
    }

    @Test("Monstres et objets du catalogue des quêtes : leur filtre, Entrée déplie où les trouver, après le reste dans « Tout »")
    func monstresEtObjets() throws {
        var avecQuetes = contexte()
        avecQuetes.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: [], pnjs: [],
            objets: ["7294": ["fr": "Poils de Pétartifoux"], "2179": ["fr": "Dent de dragodinde"]],
            monstres: ["792": ["fr": "Bworkette"], "100": ["fr": "Amakna Bwork"]], nomsPNJ: [:], sousZones: [:],
            famillesObjets: ["2179": 9], familles: ["9": ["fr": "Ressource"]], emotes: [:], titres: [:], metiers: [:], camps: [:])
        let monstres = RecherchePalette.entrees("", avecQuetes, filtre: .monstres)
        #expect(monstres.map(\.titre) == ["Amakna Bwork", "Bworkette"])
        #expect(monstres.last?.effet == .ouTrouver(.monstre(792)) && RecherchePalette.texte(de: .ouTrouver(.monstre(792)), avecQuetes) == nil)
        let objets = RecherchePalette.entrees("", avecQuetes, filtre: .objets)
        #expect(objets.map(\.sousTitre) == ["Ressource", L("palette.objet")])
        #expect(objets.first?.effet == .ouTrouver(.objet(2179)))
        // « amakna » : zaaps et lieux d'abord, le monstre après.
        let tout = RecherchePalette.entrees("amakna", avecQuetes)
        let monstre = try #require(tout.firstIndex { $0.genre == .monstre })
        #expect(tout[..<monstre].allSatisfy { !$0.genre.enDernier } && tout[monstre...].allSatisfy(\.genre.enDernier))
    }

    @Test("Un PNJ sur une carte intérieure est dit « intérieur » : /travel mène devant")
    func interieur() throws {
        var avecQuetes = contexte()
        let passage = { (carte: Int) in PNJ.Passage(position: .init(x: -32, y: -57), carte: carte, sousZone: nil, quetes: 1) }
        avecQuetes.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: [],
            pnjs: [PNJ(id: 6309, noms: ["fr": "Amayiro"], passages: [passage(217318404)]),
                   PNJ(id: 1, noms: ["fr": "Dehors"], passages: [passage(1)])],
            objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:],
            titres: [:], metiers: [:], camps: [:])
        avecQuetes.interieurs = CartesInterieures(date: .now, cartes: [217318404])
        let pnjs = RecherchePalette.pnjs(avecQuetes)
        #expect(pnjs.map(\.interieur) == [true, false])
        #expect(!CartesInterieures.vide.contient(nil) && avecQuetes.interieurs.contient(217318404))
        let donnees = try JSONEncoder().encode(avecQuetes.interieurs)
        #expect(CartesInterieures.relire(donnees) == avecQuetes.interieurs && CartesInterieures.relire(Data("{}".utf8)) == nil)
    }

    @Test("Un PNJ hors du Monde des Douze : le /travel seul, sans zaap ni distance d'Amakna")
    func pnjHorsDesDouze() throws {
        var avecQuetes = contexte()
        let douze = try #require(Carte.integree.sousZones.first { avecQuetes.reseau.estDuMondeDesDouze($0.id) }?.id)
        let ailleurs = 999_999
        #expect(avecQuetes.reseau.horsDesDouze(ailleurs))
        // La carte pas encore lue ne dit rien du monde : la case est supposée des Douze.
        #expect(!ReseauSousZones.vide.horsDesDouze(ailleurs))
        let passage = { (sousZone: Int) in PNJ.Passage(position: .init(x: 4, y: -3), carte: nil, sousZone: sousZone, quetes: 1) }
        avecQuetes.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: [],
            pnjs: [PNJ(id: 1, noms: ["fr": "Incarnam"], passages: [passage(ailleurs)]),
                   PNJ(id: 2, noms: ["fr": "Amakna"], passages: [passage(douze)])],
            objets: [:], monstres: [:], nomsPNJ: [:], sousZones: [:], famillesObjets: [:], familles: [:], emotes: [:],
            titres: [:], metiers: [:], camps: [:])
        let pnjs = RecherchePalette.pnjs(avecQuetes)
        let incarnam = try #require(pnjs.first { $0.titre == "Incarnam" })
        let amakna = try #require(pnjs.first { $0.titre == "Amakna" })
        #expect(incarnam.effet == .copier("/travel 4,-3"))
        #expect(incarnam.distance == nil && incarnam.itineraire == nil)
        #expect(amakna.effet == .trajet(x: 4, y: -3))
        #expect(amakna.distance != nil)
    }

    @Test("Un lieu porte sa carte et son pictogramme, un zaap sa carte : la liste en montre la vue")
    func vuesDesCartes() throws {
        let banque = try #require(Carte.integree.lieux.first { $0.nom(en: .fr) == "Banque" && $0.zone(en: .fr) == "Bonta" })
        let entree = try #require(RecherchePalette.lieux(contexte()).first { $0.cle == banque.cle })
        #expect(entree.carte == banque.idCarte && entree.pictogramme == banque.gfx && entree.pictogramme != nil)
        let zaap = try #require(premiere("/zaap bonta", contexte()))
        #expect(zaap.carte != nil && zaap.pictogramme == nil)
    }

    @Test("/zaap bonta trouve Cœur immaculé par sa zone")
    func zaapParZone() {
        let entree = premiere("/zaap bonta", contexte())
        #expect(entree?.titre == "Cœur immaculé")
        #expect(entree?.effet == .copier("/zaap -31,-56"))
    }

    @Test("Une étiquette passe devant les noms")
    func etiquette() {
        let entree = premiere("/zaap fri 1", contexte(etiquettes: ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2"]))
        #expect(entree?.cle == "1:-78,-41")
    }

    @Test("/travel banque bonta : la banque de Bonta, par le zaap")
    func travelLieu() throws {
        let entree = try #require(premiere("/travel banque bonta", contexte()))
        #expect(entree.titre == "Banque")
        #expect(entree.sousTitre?.contains("Bonta") == true)
        let texte = try #require(RecherchePalette.texte(de: entree.effet, contexte()))
        #expect(texte.hasPrefix("/zaap -31,-56 ; /travel "))
    }

    @Test("Une ligne de trajet dit le zaap retenu et les cartes, ou les cartes à pied")
    func itineraire() throws {
        let bonta = try #require(premiere("/travel banque bonta", contexte()))
        let texte = try #require(RecherchePalette.texte(de: bonta.effet, contexte()))
        #expect(texte.hasPrefix("/zaap -31,-56 ; "))
        let cartes = ItineraireZaap.distance((-31, -56), try #require(ItineraireZaap.cible(dans: String(texte.dropFirst(16)))))
        #expect(bonta.itineraire == L("palette.trajet.via", nombre: cartes, "Cœur immaculé", cartes))
        let amakna = try #require(RecherchePalette.lieux(contexte()).first {
            $0.titre == "Banque" && $0.detail == Coordonnees.texte(2, -2)
        })
        #expect(amakna.distance == 6 && amakna.itineraire == L("palette.trajet.aPied", nombre: 6, 6))
        #expect(RecherchePalette.texte(de: amakna.effet, contexte()) == "/travel 2,-2")
        // Sans position, ni cartes ni zaap : rien à dire.
        #expect(premiere("/travel banque bonta", contexte(position: nil))?.itineraire == nil)
    }

    @Test("Les surnoms des joueurs : fm, hdv conso")
    func surnoms() {
        #expect(premiere("/travel fm", contexte())?.titre == "Atelier des forgemages")
        #expect(premiere("/travel hdv conso", contexte())?.titre == "Hôtel de vente des consommables")
    }

    @Test("Le lieu le plus proche passe devant à score égal")
    func plusProche() throws {
        let depuisBonta = contexte(position: PositionCarte(x: -31, y: -55, zone: "Bonta"))
        let entree = try #require(premiere("/travel banque", depuisBonta))
        #expect(entree.sousTitre?.contains("Bonta") == true)
    }

    @Test("/travel x,y : le trajet, zaap compris")
    func travelCoordonnees() {
        #expect(premiere("/travel 6,8", contexte(position: PositionCarte(x: -30, y: -40, zone: nil)))?.effet
                == .copier("/zaap 5,7 ; /travel 6,8"))
    }

    @Test("/ liste les commandes ; une commande à argument se complète")
    func commandes() {
        let entrees = RecherchePalette.entrees("/", contexte())
        #expect(entrees.count == CommandeJeu.allCases.count)
        #expect(premiere("/wh", contexte())?.titre == "/whois")
        #expect(premiere("/w", contexte())?.effet == .completer("/w "))
        #expect(premiere("/away", contexte())?.effet == .copier("/away"))
    }

    @Test("% liste les variables, filtrées")
    func variables() {
        #expect(RecherchePalette.entrees("%", contexte()).count == VariableJeu.allCases.count)
        #expect(RecherchePalette.entrees("%vie", contexte()).map(\.titre) == ["%vie%", "%viemax%", "%viep%"])
    }

    @Test("/invite : toute l'équipe d'abord, puis chacun")
    func invitations() {
        let entrees = RecherchePalette.entrees("/invite", contexte())
        #expect(entrees.map(\.effet) == [.copier("/invite Brok; /invite Cid"), .copier("/invite Brok"), .copier("/invite Cid")])
    }

    @Test("Sans préfixe : un geste")
    func tout() {
        #expect(premiere("ranger", contexte())?.effet == .action(.rangerFenetres))
    }

    @Test("Les accents et la casse ne comptent pas")
    func normalisation() {
        #expect(premiere("/zaap COEUR", contexte())?.titre == "Cœur immaculé")
        #expect(premiere("/zaap eleveurs", contexte())?.titre == "Village des Éleveurs")
    }

    @Test("Les copies récentes : en tête, sans doublon, huit au plus")
    func recents() {
        var recents: [String] = []
        for texte in ["/zaap 1,1", "/zaap 2,2", "/zaap 1,1"] { recents = RecherchePalette.noterRecent(texte, dans: recents) }
        #expect(recents == ["/zaap 1,1", "/zaap 2,2"])
        for index in 0..<20 { recents = RecherchePalette.noterRecent("\(index)", dans: recents) }
        #expect(recents.count == RecherchePalette.nombreDeRecents)
        var avecRecents = contexte()
        avecRecents.recents = ["/travel 12,34"]
        #expect(premiere("12,34", avecRecents)?.effet == .copier("/travel 12,34"))
    }

    // MARK: - Filtres et tris

    @Test("Sans préfixe, les zaaps passent devant les lieux")
    func zaapsDevant() {
        let entrees = RecherchePalette.entrees("amakna", contexte())
        let premierLieu = entrees.firstIndex { $0.genre == .lieu }
        let dernierZaap = entrees.lastIndex { $0.genre == .zaap }
        #expect(premierLieu != nil && dernierZaap != nil && dernierZaap! < premierLieu!)
    }

    @Test("Le filtre ne garde qu'une famille ; vide, il liste la famille entière")
    func filtres() {
        #expect(RecherchePalette.entrees("amakna", contexte(), filtre: .lieux).allSatisfy { $0.genre == .lieu })
        #expect(RecherchePalette.entrees("", contexte(), filtre: .quetes).isEmpty)
        #expect(FiltrePalette.tout.suivant(-1) == FiltrePalette.allCases.last)
    }

    @Test("Les trois tris : proximité, alphabétique, type")
    func tris() {
        let proches = RecherchePalette.entrees("/travel banque", contexte(), tri: .proximite).compactMap(\.distance)
        #expect(proches == proches.sorted())
        let titres = RecherchePalette.entrees("", contexte(), filtre: .lieux, tri: .alphabetique).map(\.titre)
        #expect(titres == titres.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        let categories = RecherchePalette.entrees("", contexte(), filtre: .lieux, tri: .type).compactMap(\.categorie)
        #expect(categories == categories.sorted())
    }

    @Test("Les premiers d'une liste : ceux du tri complet, ex aequo dans leur ordre d'arrivée")
    func premiers() {
        var generateur = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let nombres = (0..<Int.random(in: 0...60, using: &generateur)).map { _ in Int.random(in: 0...15, using: &generateur) }
            let elements = Array(nombres.enumerated())
            for limite in [0, 1, 5, 30, 80] {
                let attendus = elements.sorted { $0.element < $1.element }.prefix(limite).map(\.offset)
                #expect(RecherchePalette.premiers(elements, limite) { $0.element < $1.element }.map(\.offset) == attendus)
            }
        }
    }

    @Test("La clé alphabétique range comme localizedStandardCompare : casse, accents, nombres")
    func cleAlphabetique() {
        let titres = ["zaap 10", "Zaap 9", "École", "Ecaflip", "Enutrof", "Éther", "bonta", "Bonta 2", "L'Arche", "Lac",
                      "Œil de Vortex", "Ouginak", "Cœur", "Coffre"]
        let cle = { RecherchePalette.Champs(titre: $0).cleAlphabetique }
        let attendu = titres.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(titres.sorted { cle($0) < cle($1) } == attendu)
    }
}
