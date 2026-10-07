import Testing
@testable import Synfus

/// Seul un `/travel x,y` est réécrit, et seulement si le zaap fait gagner
/// assez de cartes.
struct ItineraireZaapTests {

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
            #expect(ItineraireZaap.reecrire(texte, depuis: position(-30, 30), gainMinimal: 1) == nil, "\(texte)")
        }
    }

    @Test("Loin de la cible et près d'un zaap : le zaap précède le /travel tel quel")
    func reecrit() {
        // Cible à deux cartes du zaap de Coin des Bouftous (5,7).
        let texte = ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40), gainMinimal: 5)
        #expect(texte == "/zaap 5,7; /travel 6,8")
    }

    @Test("Un gain sous le seuil laisse le presse-papiers intact")
    func seuil() {
        // Depuis -2,0 (zaap d'Amakna) vers 3,-3 : 8 cartes à pied, 2 depuis
        // le zaap du Château (3,-5) — 6 de gagnées.
        #expect(ItineraireZaap.reecrire("/travel 3,-3", depuis: position(-2, 0), gainMinimal: 6)
                == "/zaap 3,-5; /travel 3,-3")
        #expect(ItineraireZaap.reecrire("/travel 3,-3", depuis: position(-2, 0), gainMinimal: 7) == nil)
    }

    @Test("Sans position, ou hors du Monde des Douze, rien n'est réécrit")
    func sansPosition() {
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: nil, gainMinimal: 1) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40, zone: "Incarnam (Pâturages)"),
                                        gainMinimal: 1) == nil)
        #expect(ItineraireZaap.reecrire("/travel 6,8", depuis: position(-30, -40, zone: "Montagne des Koalaks"),
                                        gainMinimal: 1) != nil)
    }

    @Test("La table : une seule grille, aucun zaap en double")
    func table() {
        let cases = Zaap.tous.map { "\($0.x),\($0.y)" }
        #expect(Set(cases).count == cases.count)
        #expect(Zaap.tous.contains(Zaap(-2, 0)))
        // Incarnam (Route des âmes) n'est pas sur la grille du Monde des Douze.
        #expect(!Zaap.tous.contains(Zaap(-1, -3)))
    }
}
