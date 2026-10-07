import Foundation
import Testing
@testable import Synfus

/// Seul un `/travel x,y` est réécrit, et seulement si le zaap fait gagner
/// assez de cartes.
struct ItineraireZaapTests {

    /// Les zaaps actifs d'une installation neuve.
    private let zaaps = CatalogueZaaps.actifs(base: Zaap.integres, ajoutes: [], choix: [:])

    private func position(_ x: Int, _ y: Int, zone: String? = nil) -> PositionCarte {
        PositionCarte(x: x, y: y, zone: zone)
    }

    @Test("Les formes copiées par les sites de cartes donnent la cible")
    func formesDeTravel() {
        for texte in ["/travel -2,0", "/travel -2, 0", "/travel -2 0", "/travel [-2,0]", "  /travel -2,0\n"] {
            let cible = ItineraireZaap.cible(dans: texte)
            #expect(cible?.x == -2 && cible?.y == 0, "\(texte)")
        }
    }

    @Test("Tout autre texte est ignoré")
    func autresTextes() {
        for texte in ["", "-2,0", "/invite Brok", "/zaap -2,0; /travel 5,7", "/Travel -2,0",
                      "voir /travel -2,0", "/travel -2,0 merci", "/travel -2,0\n/travel 3,4",
                      "/travel -2", "/travel 999,0", "/traveler 1,2"] {
            #expect(ItineraireZaap.cible(dans: texte) == nil, "\(texte)")
            #expect(ItineraireZaap.reecrire(texte, depuis: position(-30, 30), gainMinimal: 1, zaaps: zaaps) == nil, "\(texte)")
        }
    }

    @Test("Loin de la cible et près d'un zaap : le zaap précède le /travel tel quel")
    func reecrit() {
        // Cible à deux cartes du zaap de Coin des Bouftous (5,7).
        let texte = ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40), gainMinimal: 5, zaaps: zaaps)
        #expect(texte == "/zaap 5,7; /travel 6,8")
    }

    @Test("Un gain sous le seuil laisse le presse-papiers intact")
    func seuil() {
        // Depuis -2,0 (zaap d'Amakna) vers 3,-3 : 8 cartes à pied, 2 depuis
        // le zaap du Château (3,-5) — 6 de gagnées.
        #expect(ItineraireZaap.reecrire("/travel 3,-3", depuis: position(-2, 0), gainMinimal: 6, zaaps: zaaps)
                == "/zaap 3,-5; /travel 3,-3")
        #expect(ItineraireZaap.reecrire("/travel 3,-3", depuis: position(-2, 0), gainMinimal: 7, zaaps: zaaps) == nil)
    }

    @Test("Sans position, ou hors du Monde des Douze, rien n'est réécrit")
    func sansPosition() {
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: nil, gainMinimal: 1, zaaps: zaaps) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40, zone: "Incarnam (Pâturages)"),
                                        gainMinimal: 1, zaaps: zaaps) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40, zone: "Montagne des Koalaks"),
                                        gainMinimal: 1, zaaps: zaaps) != nil)
    }

    @Test("La liste intégrée : aucun zaap en double, ceux d'une autre carte inactifs")
    func table() {
        let cles = Zaap.integres.map(\.cle)
        #expect(Set(cles).count == cles.count)
        #expect(Zaap.integres.count == 45)
        let incarnam = try? #require(Zaap.integres.first { $0.monde == 2 && $0.x == 3 && $0.y == 0 })
        #expect(incarnam.map { CatalogueZaaps.estActif($0, choix: [:]) } == false)
        #expect(zaaps.allSatisfy { $0.monde == Zaap.mondeDesDouze })
        // Sans cela, un /travel 3,-1 d'Amakna passerait par le cimetière d'Incarnam.
        #expect(ItineraireZaap.reecrire("/travel 3,-1", depuis: position(-40, 20), gainMinimal: 1, zaaps: zaaps)
                == "/zaap 3,-5; /travel 3,-1")
    }

    @Test("Un zaap décoché n'est plus proposé, un zaap d'une autre carte coché l'est")
    func choix() {
        let chateau = Zaap.integres.first { $0.x == 3 && $0.y == -5 }!
        let cimetiere = Zaap.integres.first { $0.monde == 2 && $0.x == 3 && $0.y == 0 }!
        let actifs = CatalogueZaaps.actifs(base: Zaap.integres, ajoutes: [],
                                           choix: [chateau.cle: false, cimetiere.cle: true])
        #expect(!actifs.contains(chateau))
        #expect(actifs.contains(cimetiere))
    }

    @Test("Un ajout à la main compte, sans doubler un zaap connu")
    func ajouts() {
        let nouveau = Zaap(50, 50, noms: ["fr": "Nouveau"])
        let doublon = Zaap(-2, 0, noms: ["fr": "Autre nom"])
        let tous = CatalogueZaaps.tous(base: Zaap.integres, ajoutes: [nouveau, doublon])
        #expect(tous.count == Zaap.integres.count + 1)
        #expect(tous.first { $0.cle == doublon.cle }?.nom(en: .fr) == "Village d'Amakna")
        let actifs = CatalogueZaaps.actifs(base: Zaap.integres, ajoutes: [nouveau], choix: [:])
        #expect(ItineraireZaap.reecrire("/travel 51,50", depuis: position(0, 0), gainMinimal: 5, zaaps: actifs)
                == "/zaap 50,50; /travel 51,50")
    }

    @Test("La réponse de DofusDB donne un zaap par case, nommé par sa sous-zone")
    func dofusDB() throws {
        let reperes = """
        {"total":3,"data":[{"x":-2,"y":0,"worldMapId":1,"subareaId":10},
          {"x":-2,"y":0,"worldMapId":1,"subareaId":10},{"x":3,"y":0,"worldMapId":2,"subareaId":449}]}
        """
        let sousZones = """
        {"total":1,"data":[{"id":10,"name":{"id":"1","fr":"Village d'Amakna","en":"Amakna Village","es":"Pueblo de Amakna"}}]}
        """
        let decodeur = JSONDecoder()
        let zaaps = ZaapsDofusDB.assembler(
            reperes: try decodeur.decode(DofusDB.Page<ZaapsDofusDB.Repere>.self, from: Data(reperes.utf8)).data,
            sousZones: try decodeur.decode(DofusDB.Page<ZaapsDofusDB.SousZone>.self, from: Data(sousZones.utf8)).data)
        #expect(zaaps.count == 2)
        #expect(zaaps[0] == Zaap(-2, 0, noms: ["fr": "Village d'Amakna", "en": "Amakna Village", "es": "Pueblo de Amakna"]))
        #expect(zaaps[1].monde == 2)
        #expect(zaaps[1].nom(en: .en) == "Zaap")
    }

    @Test("Les commandes composées se relisent comme une cible")
    func compositions() {
        let travel = ItineraireZaap.travel(vers: (-27, 36))
        #expect(travel == "/travel -27,36")
        #expect(ItineraireZaap.cible(dans: travel).map { [$0.x, $0.y] } == [-27, 36])
        #expect(ItineraireZaap.zaap(Zaap(5, -18, noms: [:])) == "/zaap 5,-18")
    }

    @Test("On ne rejoint un perso que dans le Monde des Douze")
    func rejoindre() {
        #expect(ItineraireZaap.rejoindre(position(4, -3)).map { [$0.x, $0.y] } == [4, -3])
        #expect(ItineraireZaap.rejoindre(position(4, -3, zone: "Incarnam (Pâturages)")) == nil)
        #expect(ItineraireZaap.rejoindre(nil) == nil)
    }

    // MARK: - Favoris

    private let bouftous = Zaap(5, 7, noms: ["fr": "Coin des Bouftous"])
    private let astrub = Zaap(5, -18, noms: ["fr": "Cité d'Astrub"])
    private let amakna = Zaap(-2, 0, noms: ["fr": "Village d'Amakna"])
    private let incarnam = Zaap(2, -5, monde: 2, noms: ["fr": "Pâturages"])

    @Test("Les favoris suivent l'ordre choisi et sautent les clés inconnues")
    func favoris() {
        let connus = [bouftous, astrub, amakna]
        let favoris = CatalogueZaaps.favoris([astrub.cle, "1:99,99", bouftous.cle], parmi: connus)
        #expect(favoris == [astrub, bouftous])
    }

    @Test("Les favoris se trient du plus proche, l'autre carte en dernier")
    func triParDistance() {
        let zaaps = [incarnam, astrub, bouftous, amakna]
        #expect(CatalogueZaaps.parDistance(zaaps, depuis: position(4, 6)) == [bouftous, amakna, astrub, incarnam])
        #expect(CatalogueZaaps.distance(de: bouftous, depuis: position(4, 6)) == 2)
        #expect(CatalogueZaaps.distance(de: incarnam, depuis: position(4, 6)) == nil)
    }

    @Test("Sans position utilisable, les favoris gardent leur ordre")
    func triSansPosition() {
        let zaaps = [astrub, bouftous, amakna]
        #expect(CatalogueZaaps.parDistance(zaaps, depuis: nil) == zaaps)
        #expect(CatalogueZaaps.parDistance(zaaps, depuis: position(4, 6, zone: "Incarnam")) == zaaps)
    }

    // MARK: - Mise à jour DofusDB

    @Test("La liste DofusDB se rafraîchit absente ou vieille de plus de 30 jours")
    func aRafraichir() {
        let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let jour: TimeInterval = 24 * 3600
        func releve(age: TimeInterval) -> ReleveZaaps {
            ReleveZaaps(date: maintenant.addingTimeInterval(-age), zaaps: [])
        }
        #expect(ZaapsDofusDB.aRafraichir(releve: nil, maintenant: maintenant))
        #expect(!ZaapsDofusDB.aRafraichir(releve: releve(age: 29 * jour), maintenant: maintenant))
        #expect(!ZaapsDofusDB.aRafraichir(releve: releve(age: 30 * jour), maintenant: maintenant))
        #expect(ZaapsDofusDB.aRafraichir(releve: releve(age: 31 * jour), maintenant: maintenant))
    }
}
