import Foundation
import Testing
@testable import Synfus

/// Seul un `/travel x,y` est réécrit, et seulement si le zaap fait gagner
/// assez de cartes.
struct ItineraireZaapTests {

    /// Les zaaps actifs d'une installation neuve, et les sous-zones de la carte intégrée.
    private let reseau = ReseauSousZones(Carte.integree)
    private var zaaps: [Zaap] { CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:], reseau: reseau) }
    private var situes: ZaapsSitues { ZaapsSitues(zaaps, reseau: reseau) }

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
        for texte in ["", "-2,0", "/invite Brok", "/zaap -2,0 ; /travel 5,7", "/Travel -2,0",
                      "voir /travel -2,0", "/travel -2,0 merci", "/travel -2,0\n/travel 3,4",
                      "/travel -2", "/travel 999,0", "/traveler 1,2"] {
            #expect(ItineraireZaap.cible(dans: texte) == nil, "\(texte)")
            #expect(ItineraireZaap.reecrire(texte, sousZone: nil, depuis: position(-30, 30), gainMinimal: 1, zaaps: situes, zaapDuJeu: true, intercalees: []) == nil, "\(texte)")
        }
    }

    @Test("Loin de la cible et près d'un zaap : le zaap précède le /travel tel quel")
    func reecrit() {
        // Cible à deux cartes du zaap de Coin des Bouftous (5,7).
        let texte = ItineraireZaap.reecrire("/travel 6,8", sousZone: nil, depuis: position(-30, -40), gainMinimal: 5, zaaps: situes, zaapDuJeu: true, intercalees: [])
        #expect(texte == "/zaap 5,7 ; /travel 6,8")
    }

    @Test("Les commandes intercalées se glissent entre le zaap et le /travel")
    func intercalees() {
        let texte = ItineraireZaap.reecrire("/travel 6,8", sousZone: nil, depuis: position(-30, -40), gainMinimal: 5, zaaps: situes,
                                            zaapDuJeu: true, intercalees: ["/a", "/a"])
        #expect(texte == "/zaap 5,7 ; /a ; /a ; /travel 6,8")
    }

    @Test("La saisie des commandes intercalées : « ; » sépare, le « / » manquant est ajouté, le vide ignoré")
    func saisieIntercalees() {
        #expect(ItineraireZaap.intercalees("/a") == ["/a"])
        #expect(ItineraireZaap.intercalees(" /a ;; a ; /s  ") == ["/a", "/a", "/s"])
        #expect(ItineraireZaap.intercalees("").isEmpty)
        #expect(ItineraireZaap.intercalees(" ; ").isEmpty)
    }

    @Test("Un gain sous le seuil laisse le presse-papiers intact")
    func seuil() {
        // Depuis -2,0 (zaap d'Amakna) vers 3,-4 : 9 cartes à pied, 1 depuis
        // le zaap du Château (3,-5) — 8 de gagnées.
        #expect(ItineraireZaap.reecrire("/travel 3,-4", sousZone: nil, depuis: position(-2, 0), gainMinimal: 8, zaaps: situes, zaapDuJeu: true, intercalees: [])
                == "/zaap 3,-5 ; /travel 3,-4")
        #expect(ItineraireZaap.reecrire("/travel 3,-4", sousZone: nil, depuis: position(-2, 0), gainMinimal: 9, zaaps: situes, zaapDuJeu: true, intercalees: []) == nil)
    }

    @Test("Sans position, ou hors du Monde des Douze, rien n'est réécrit")
    func sansPosition() {
        #expect(ItineraireZaap.reecrire("/travel 6,8", sousZone: nil, depuis: nil, gainMinimal: 1, zaaps: situes, zaapDuJeu: true, intercalees: []) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", sousZone: nil, depuis: position(-30, -40, zone: "Incarnam (Pâturages)"),
                                        gainMinimal: 1, zaaps: situes, zaapDuJeu: true, intercalees: []) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", sousZone: nil, depuis: position(-30, -40, zone: "Montagne des Koalaks"),
                                        gainMinimal: 1, zaaps: situes, zaapDuJeu: true, intercalees: []) != nil)
    }

    @Test("La liste intégrée : aucun zaap en double, ceux d'Incarnam inactifs, ceux d'une couche du Monde des Douze actifs")
    func table() {
        let cles = Carte.integree.zaaps.map(\.cle)
        #expect(Set(cles).count == cles.count)
        #expect(Carte.integree.zaaps.count == 45)
        let incarnam = try? #require(Carte.integree.zaaps.first { $0.monde == 2 && $0.x == 3 && $0.y == 0 })
        #expect(incarnam.map { CatalogueZaaps.estActif($0, choix: [:], reseau: reseau) } == false)
        #expect(!zaaps.contains { $0.monde == 2 })
        // La Canopée, couche au-dessus de la jungle d'Otomaï.
        #expect(zaaps.contains { $0.x == -54 && $0.y == 16 && $0.monde != Zaap.mondeDesDouze })
        // Sans cela, un /travel 3,-1 d'Amakna passerait par le cimetière
        // d'Incarnam (3,0) à vol d'oiseau ; par les sous-zones, c'est le
        // zaap du Village d'Amakna.
        #expect(ItineraireZaap.reecrire("/travel 3,-1", sousZone: nil, depuis: position(-40, 20), gainMinimal: 1, zaaps: ZaapsSitues(zaaps, reseau: .vide), zaapDuJeu: true, intercalees: [])
                == "/zaap 3,-5 ; /travel 3,-1")
        #expect(ItineraireZaap.reecrire("/travel 3,-1", sousZone: nil, depuis: position(-40, 20), gainMinimal: 1, zaaps: situes, zaapDuJeu: true, intercalees: [])
                == "/zaap -2,0 ; /travel 3,-1")
    }

    @Test("Un zaap décoché n'est plus proposé, un zaap d'une autre carte coché l'est")
    func choix() {
        let chateau = Carte.integree.zaaps.first { $0.x == 3 && $0.y == -5 }!
        let cimetiere = Carte.integree.zaaps.first { $0.monde == 2 && $0.x == 3 && $0.y == 0 }!
        let actifs = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [],
                                           choix: [chateau.cle: false, cimetiere.cle: true], reseau: reseau)
        #expect(!actifs.contains(chateau))
        #expect(actifs.contains(cimetiere))
    }

    @Test("Un ajout à la main compte, sans doubler un zaap connu")
    func ajouts() {
        let nouveau = Zaap(50, 50, noms: ["fr": "Nouveau"])
        let doublon = Zaap(-2, 0, noms: ["fr": "Autre nom"])
        let tous = CatalogueZaaps.tous(base: Carte.integree.zaaps, ajoutes: [nouveau, doublon])
        #expect(tous.count == Carte.integree.zaaps.count + 1)
        #expect(tous.first { $0.cle == doublon.cle }?.nom(en: .fr) == "Village d'Amakna")
        let actifs = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [nouveau], choix: [:], reseau: reseau)
        #expect(ItineraireZaap.reecrire("/travel 51,50", sousZone: nil, depuis: position(0, 0), gainMinimal: 5, zaaps: ZaapsSitues(actifs, reseau: reseau), zaapDuJeu: true, intercalees: [])
                == "/zaap 50,50 ; /travel 51,50")
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

    @Test("La région de la zone lue, tranchée à la lecture : sans casse ni accents, au début du nom seulement")
    func horsDuMondeDesDouze() {
        #expect(position(0, 0, zone: "incarnam (Paturages)").horsDuMondeDesDouze)
        #expect(position(0, 0, zone: "Ecaflipus").horsDuMondeDesDouze)
        #expect(!position(0, 0, zone: "Amakna (Incarnam)").horsDuMondeDesDouze)
        #expect(!position(0, 0, zone: nil).horsDuMondeDesDouze)
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

    // MARK: - Sous-zones

    @Test("Le zaap de la sous-zone visée, pas le plus proche à vol d'oiseau derrière la montagne")
    func zaapDeLaSousZone() {
        // [-20,9], Territoire des dragodindes sauvages : Sidimote [-25,12] est
        // à huit cartes mais sans chemin ; le jeu y rattache le zaap des
        // Koalaks [-16,1].
        let astrub = position(5, -18)
        #expect(ItineraireZaap.reecrire("/travel -20,9", sousZone: nil, depuis: astrub, gainMinimal: 5, zaaps: situes, zaapDuJeu: true, intercalees: [])
                == "/zaap -16,1 ; /travel -20,9")
        #expect(ItineraireZaap.reecrire("/travel -20,9", sousZone: nil, depuis: astrub, gainMinimal: 5, zaaps: ZaapsSitues(zaaps, reseau: .vide), zaapDuJeu: true, intercalees: [])
                == "/zaap -25,12 ; /travel -20,9")
    }

    @Test("Le zaap du jeu cède à celui des sous-zones quand il est bien plus loin")
    func zaapDuJeuLointain() {
        // [4,12], Forêt d'Amakna : le jeu y rattache le Rivage sufokien
        // [10,22], à seize cartes ; le Coin des Bouftous [5,7] est à six.
        #expect(ItineraireZaap.reecrire("/travel 4,12", sousZone: nil, depuis: position(5, -18), gainMinimal: 5, zaaps: situes, zaapDuJeu: true, intercalees: [])
                == "/zaap 5,7 ; /travel 4,12")
        // [-20,9] : Koalak [-16,1] à douze cartes, la Route des Roulottes
        // [-25,12] à huit par les sous-zones — trop peu pour céder.
        #expect(ItineraireZaap.zaap(vers: (-20, 9), sousZone: nil, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] } == [-16, 1])
        #expect(ItineraireZaap.zaap(vers: (-20, 9), sousZone: nil, parmi: situes, zaapDuJeu: false).map { [$0.x, $0.y] } == [-25, 12])
    }

    @Test("Le zaap du jeu garde la main dans sa zone : pas de falaise franchie à vol d'oiseau")
    func falaises() {
        // Mériana [-6,-3], Marécages nauséabonds (Montagne des Koalaks) : le
        // jeu y rattache Koalak [-16,1] ; la Montagne des Craqueleurs [-5,-8],
        // plus près, est derrière les falaises, dans une autre zone.
        #expect(ItineraireZaap.zaap(vers: (-6, -3), sousZone: 232, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] }
                == [-16, 1])
        #expect(ItineraireZaap.zaap(vers: (-6, -3), sousZone: nil, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] }
                == [-16, 1])
    }

    @Test("Une cible dont on sait la sous-zone prend le zaap de sa couche, pas celui de la case d'en dessous")
    func couche() {
        // L'Assistante d'Otomaï [-55,15], Village de la Canopée : la case
        // est celle de la Jungle obscure, rattachée au Village côtier [-46,18].
        #expect(ItineraireZaap.zaap(vers: (-55, 15), sousZone: 469, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] }
                == [-54, 16])
        #expect(ItineraireZaap.zaap(vers: (-55, 15), sousZone: nil, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] }
                == [-46, 18])
        #expect(ItineraireZaap.reecrire("/travel -55,15", sousZone: 469, depuis: position(5, -18), gainMinimal: 5,
                                        zaaps: situes, zaapDuJeu: true, intercalees: ["/a"])
                == "/zaap -54,16 ; /a ; /travel -55,15")
        // Une sous-zone hors du Monde des Douze (Incarnam) ne compte pas : la case décide.
        #expect(ItineraireZaap.zaap(vers: (6, 8), sousZone: 445, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] }
                == ItineraireZaap.zaap(vers: (6, 8), sousZone: nil, parmi: situes, zaapDuJeu: true).map { [$0.x, $0.y] })
    }

    /// 1 ─ 2 ─ 3, et 4 isolée ; la cible [0,0] est dans la sous-zone 1, qui
    /// désigne le zaap A. 1, 2 et 4 sont d'une zone, 3 d'une autre.
    private let petitReseau = ReseauSousZones(Carte(
        date: .now, lieux: [],
        sousZones: [SousZoneCarte(id: 1, zaap: 100, zone: 10, voisines: [2]), SousZoneCarte(id: 2, zaap: nil, zone: 10, voisines: [1, 3]),
                    SousZoneCarte(id: 3, zaap: nil, zone: 20, voisines: [2]), SousZoneCarte(id: 4, zaap: nil, zone: 10, voisines: [])],
        cases: ["0,0": 1, "1,0": 1, "5,0": 2, "9,0": 3, "30,0": 3, "40,0": 4]))
    private let zaapB = Zaap(9, 0, noms: ["fr": "B"], idCarte: 200, idSousZone: 3)
    private let zaapC = Zaap(5, 0, noms: ["fr": "C"], idCarte: 300, idSousZone: 2)
    private let zaapD = Zaap(1, 1, noms: ["fr": "D"], idCarte: 400, idSousZone: 4)

    private func choisi(_ cible: (Int, Int), _ zaaps: [Zaap], zaapDuJeu: Bool = true) -> String? {
        ItineraireZaap.zaap(vers: cible, sousZone: nil, parmi: ZaapsSitues(zaaps, reseau: petitReseau), zaapDuJeu: zaapDuJeu)?.nom(en: .fr)
    }

    @Test("Le zaap associé l'emporte, sauf s'il est hors de la zone et que celui des sous-zones, dedans, épargne l'écart")
    func associe() {
        // C, par les sous-zones, est à cinq cartes de la cible ; D, plus près,
        // est dans une sous-zone isolée.
        let ecart = ItineraireZaap.ecartZaapDuJeu
        let presque = Zaap(5 + ecart - 1, 0, noms: ["fr": "A"], idCarte: 100, idSousZone: 3)
        let tropLoin = Zaap(5 + ecart, 0, noms: ["fr": "A"], idCarte: 100, idSousZone: 3)
        let tropLoinMemeZone = Zaap(5 + ecart, 0, noms: ["fr": "A"], idCarte: 100, idSousZone: 2)
        #expect(choisi((0, 0), [zaapC, zaapD, presque]) == "A")
        #expect(choisi((0, 0), [zaapC, zaapD, tropLoin]) == "C")
        // Dans la zone de la cible, le jeu sait le chemin : il garde la main.
        #expect(choisi((0, 0), [zaapC, zaapD, tropLoinMemeZone]) == "A")
        // Sans le zaap du jeu : le plus proche en sous-zones traversées.
        #expect(choisi((0, 0), [zaapC, zaapD, presque], zaapDuJeu: false) == "C")
    }

    @Test("Aucun zaap joignable par les sous-zones : celui du jeu, pas le vol d'oiseau")
    func associeIsole() {
        let isole = Zaap(40, 0, noms: ["fr": "A"], idCarte: 100, idSousZone: 4)
        #expect(choisi((0, 0), [zaapD, isole]) == "A")
        #expect(choisi((0, 0), [zaapD, isole], zaapDuJeu: false) == "D")
    }

    @Test("Associé inactif : le moins de sous-zones à traverser, puis le moins de cartes")
    func sauts() {
        // D est à deux cartes mais dans une sous-zone isolée ; C, à une
        // sous-zone ; B, à deux.
        #expect(choisi((0, 0), [zaapB, zaapC, zaapD]) == "C")
        #expect(choisi((0, 0), [zaapB, zaapD]) == "B")
        // Deux zaaps dans la même sous-zone : le plus proche de la cible.
        let loin = Zaap(30, 0, noms: ["fr": "Loin"], idSousZone: 3)
        #expect(choisi((1, 0), [loin, zaapB]) == "B")
    }

    @Test("Un ajout à la main se situe par ses coordonnées")
    func ajoutSitue() {
        let ajout = Zaap(9, 0, noms: ["fr": "Ajout"])
        #expect(choisi((0, 0), [zaapD, ajout]) == "Ajout")
    }

    @Test("Cible hors du relevé, ou aucun zaap joignable : le plus proche à vol d'oiseau")
    func volDOiseau() {
        #expect(choisi((60, 0), [zaapB, zaapC]) == "B")
        #expect(choisi((40, 0), [zaapB, zaapC]) == "B")
    }
}
