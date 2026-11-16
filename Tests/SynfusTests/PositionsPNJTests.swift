import CoreGraphics
import Foundation
import Testing
@testable import Synfus

/// Les positions d'un PNJ dépliées en cartes : leur ordre, leur part de la largeur, le clavier.
struct PositionsPNJTests {

    private func candidat(_ rang: Int, cout: Int? = nil, fois: Int = 0, dernier: Int = 0) -> OrdrePositions.Candidat {
        OrdrePositions.Candidat(rang: rang, cout: cout, fois: fois, dernier: dernier)
    }

    @Test("Les positions les plus choisies d'abord, puis les moins coûteuses ; à égalité, la plus citée")
    func ordre() {
        let sansHabitude = [candidat(0, cout: 9), candidat(1, cout: 2), candidat(2, cout: nil), candidat(3, cout: 2)]
        #expect(OrdrePositions.trier(sansHabitude).map(\.rang) == [1, 3, 0, 2])
        let habitudes = [candidat(0, cout: 1), candidat(1, cout: 9, fois: 2, dernier: 3),
                         candidat(2, cout: 9, fois: 2, dernier: 7), candidat(3, cout: 9, fois: 5, dernier: 1)]
        #expect(OrdrePositions.trier(habitudes).map(\.rang) == [3, 2, 1, 0])
    }

    @Test("L'habituelle est la plus choisie, à défaut la plus citée")
    func habituelle() {
        #expect(OrdrePositions.habituelle([candidat(0, cout: 5), candidat(1, cout: 1)]) == 0)
        #expect(OrdrePositions.habituelle([candidat(0), candidat(1, fois: 1, dernier: 2), candidat(2, fois: 1, dernier: 9)]) == 2)
        #expect(OrdrePositions.habituelle([]) == nil)
    }

    @Test("Une carte prend toute la largeur, deux la moitié, trois le tiers ; au-delà des tiers, le suivant entamé")
    func disposition() {
        let (disponible, interstice): (CGFloat, CGFloat) = (600, 10)
        func largeur(_ nombre: Int) -> CGFloat {
            DispositionPositions.largeur(nombre: nombre, disponible: disponible, interstice: interstice)
        }
        #expect(largeur(1) == 600 && largeur(2) == 295)
        #expect(abs(largeur(3) - 580 / 3) < 0.001)
        // Cinq cartes : trois entières, un interstice après chacune, puis 30 % de la quatrième.
        let tiers = largeur(5)
        #expect(abs(tiers * 3.3 + 30 - disponible) < 0.001 && tiers < largeur(3))
        #expect(largeur(4) == tiers)
        #expect(!DispositionPositions.defile(3) && DispositionPositions.defile(4))
        #expect(DispositionPositions.largeur(nombre: 0, disponible: 0, interstice: 10) == 0)
    }

    @Test("↑ et ← sur la première carte replient une fiche de positions ; une fiche de donjon rend la ligne")
    func sorties() {
        let (a, b) = (PNJ.Position(x: 1, y: 1), PNJ.Position(x: 2, y: 2))
        let positions = CartesFiche.positions([a, b])
        #expect(positions.lateral(depuis: .position(a), -1) == .replier)
        #expect(positions.lateral(depuis: .position(b), -1) == .carte(.position(a)))
        #expect(positions.lateral(depuis: .position(a), 1) == .carte(.position(b)))
        #expect(positions.lateral(depuis: .position(b), 1) == .carte(.position(b)))
        #expect(positions.versLeHaut == .replier)
        let donjon = CartesFiche(actions: [.guide("a"), .monstres])
        #expect(donjon.lateral(depuis: .guide("a"), -1) == .carte(.guide("a")) && donjon.versLeHaut == .ligne)
    }

    // MARK: - Du PNJ aux cartes

    private func quete(_ id: Int, _ nom: String) -> Quete {
        Quete(id: id, noms: ["fr": nom], niveau: 1, groupe: false, donjon: false, prerequis: [], critere: nil, etapes: [])
    }

    private func contexte(frequentation: FrequentationPalette = FrequentationPalette()) -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna")
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]), reseau: .vide)
        contexte.frequentation = frequentation
        let passage = { (x: Int, y: Int, quetes: [Int], sousZone: Int?) in
            PNJ.Passage(position: .init(x: x, y: y), carte: 7, sousZone: sousZone, quetes: quetes)
        }
        contexte.quetes = Quetes(
            format: Quetes.formatActuel, date: .now,
            quetes: [quete(1, "Zèbre 10"), quete(2, "Zèbre 9"), quete(3, "Abeille"), quete(4, "Cane"), quete(5, "Dodo")],
            pnjs: [PNJ(id: 1, noms: ["fr": "Voyageur"],
                       passages: [passage(-32, -57, [1, 2, 3], 10), passage(-2, 1, [4], nil), passage(40, 40, [5], nil)]),
                   PNJ(id: 2, noms: ["fr": "Sédentaire"], passages: [passage(-2, 6, [4], nil)])],
            objets: [:], monstres: [:], nomsPNJ: [:],
            sousZones: ["10": SousZoneNommee(noms: ["fr": "Village d'Amakna"], zone: ["fr": "Amakna"])],
            famillesObjets: [:], familles: [:], emotes: [:], titres: [:], metiers: [:], camps: [:])
        return contexte
    }

    @Test("Les cartes d'un PNJ : sous-zone et zone, quêtes par ordre alphabétique, trajet sans « à pied », habituelle")
    func cartes() throws {
        let cartes = RecherchePalette.positions(de: 1, contexte())
        #expect(cartes.count == 3)
        // Sans habitude, la moins chère d'abord (-2,1 : une carte du perso).
        let premiere = cartes[0]
        #expect(premiere.position == PNJ.Position(x: -2, y: 1) && premiere.quetes == ["Cane"])
        #expect(premiere.itineraire == L("palette.trajet.cartes", nombre: 1, 1))
        // Sur place : « Ici », pas « 0 carte ».
        #expect(RecherchePalette.itineraire(ItineraireZaap.Trajet(zaap: nil, cartes: 0), .fr) == L("palette.trajet.ici"))
        #expect(premiere.entree.titre == Coordonnees.texte(-2, 1) && premiere.entree.etiquette == nil)
        // L'habituelle est la plus citée : seule à porter la pastille.
        let citee = try #require(cartes.first { $0.position == PNJ.Position(x: -32, y: -57) })
        #expect(citee.entree.etiquette == L("palette.pnj.habituelle") && cartes.filter { $0.entree.etiquette != nil }.count == 1)
        #expect(citee.entree.titre == "Village d'Amakna" && citee.entree.sousTitre == "Amakna")
        #expect(citee.quetes == ["Abeille", "Zèbre 9", "Zèbre 10"] && citee.entree.carte == 7)
        #expect(citee.entree.detail == Coordonnees.texte(-32, -57))
        // Un seul passage : une grande carte, sans pastille.
        let seule = RecherchePalette.positions(de: 2, contexte())
        #expect(seule.count == 1 && seule[0].entree.etiquette == nil)
        #expect(RecherchePalette.positions(de: 99, contexte()).isEmpty)
    }

    @Test("Une position choisie d'habitude passe devant et porte la pastille")
    func habitude() {
        let habitudes = FrequentationPalette(["pnj:1:40,40": .init(fois: 2, dernier: 5)])
        let cartes = RecherchePalette.positions(de: 1, contexte(frequentation: habitudes))
        #expect(cartes.first?.position == PNJ.Position(x: 40, y: 40))
        #expect(cartes.first?.entree.etiquette == L("palette.pnj.habituelle"))
        #expect(PNJ.cle(1, en: .init(x: 40, y: 40)) == "pnj:1:40,40")
    }

    // MARK: - Le clavier

    @MainActor
    @Test("→ déplie un PNJ, ← sur sa première carte et ↑ le replient ; Entrée copie la carte choisie")
    func clavier() throws {
        let modele = PaletteModele(contexte: contexte(), requete: "voyageur")
        let ligne = try #require(modele.entrees.first)
        #expect(ligne.effet == .positions(1) && modele.deplie == nil && modele.texteDeLaSelection == nil)
        #expect(modele.lateral(1) && modele.deplie == ligne.id)
        let premiere = try #require(modele.positionsDeplie.first)
        #expect(modele.carte == .position(premiere.position))
        // Le texte que ↵ copiera : le trajet de la carte choisie.
        #expect(modele.texteDeLaSelection?.contains("/travel") == true)
        #expect(modele.lateral(1) && modele.carte == .position(modele.positionsDeplie[1].position))
        #expect(modele.lateral(-1) && modele.carte == .position(premiere.position))
        #expect(modele.lateral(-1) && modele.deplie == nil)
        _ = modele.lateral(1)
        modele.deplacer(ligne: -1)
        #expect(modele.deplie == nil && modele.carte == nil)
    }

    @MainActor
    @Test("Un PNJ à une position : Entrée copie, → le déplie en une grande carte")
    func unePosition() throws {
        let modele = PaletteModele(contexte: contexte(), requete: "sedentaire")
        let ligne = try #require(modele.entrees.first)
        #expect(ligne.effet != .positions(2) && ligne.pnj == 2 && modele.texteDeLaSelection?.contains("/travel") == true)
        #expect(modele.lateral(1) && modele.deplie == ligne.id && modele.positionsDeplie.count == 1)
    }
}
