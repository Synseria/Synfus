import Testing
@testable import Synfus

/// Le décodage des lignes lues en haut à gauche de la fenêtre. Les entrées
/// sont les sorties réelles de Vision sur des captures du jeu.
struct PositionCarteTests {

    @Test("Lecture réelle : zone puis coordonnées et niveau")
    func lectureReelle() {
        let lignes = ["Montagne des Koalaks (Village des Eleveu.", "-16, 1 - Niveau 1",
                      "ISANCT]", "De Brikke et de Brokke"]
        let position = PositionCarte.lire(lignes)
        #expect(position?.x == -16)
        #expect(position?.y == 1)
        #expect(position?.zone == "Montagne des Koalaks (Village des Eleveu")
    }

    @Test("Deux coordonnées négatives, et un « Niveau » mal lu")
    func deuxNegatives() {
        let position = PositionCarte.lire(["Bonta (Faubourgs des artisans)", "-29, -57 - Nivcau 10"])
        #expect(position?.coordonnees == "-29, -57")
        #expect(position?.zone == "Bonta (Faubourgs des artisans)")
    }

    @Test("Le signe moins lu en flèche ou en tiret long reste un moins")
    func tiretsSubstitues() {
        #expect(PositionCarte.lire(["→16, 1 - Niveau 1"])?.x == -16)
        #expect(PositionCarte.lire(["— 3 , −12"])?.coordonnees == "-3, -12")
    }

    @Test("La virgule lue en point passe encore")
    func virguleEnPoint() {
        #expect(PositionCarte.lire(["4. -18 - Niveau 20"])?.coordonnees == "4, -18")
    }

    @Test("Deux nombres ailleurs qu'en tête de ligne ne sont pas une position")
    func pasEnTete() {
        #expect(PositionCarte.lire(["Quête : tuer 3, 4 bouftous"]) == nil)
        #expect(PositionCarte.lire(["Niveau 1"]) == nil)
        #expect(PositionCarte.lire([]) == nil)
    }

    @Test("Une valeur hors carte est une erreur de lecture")
    func horsBorne() {
        #expect(PositionCarte.lire(["1600, 1 - Niveau 1"]) == nil)
    }

    @Test("Sans ligne de zone, la position reste lue")
    func sansZone() {
        let position = PositionCarte.lire(["-16, 1 - Niveau 1"])
        #expect(position?.coordonnees == "-16, 1")
        #expect(position?.zone == nil)
    }
}

/// L'empreinte qui évite de relancer l'OCR tant que le texte ne change pas.
struct EmpreinteTexteTests {

    private func image(texteEn colonnes: Range<Int>, fond: UInt8 = 60) -> LumaBitmap {
        let (w, h) = (192, 48)
        var pixels = [UInt8](repeating: fond, count: w * h)
        for y in 10..<20 { for x in colonnes { pixels[y * w + x] = 255 } }
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    @Test("Le même texte sur un décor qui change reste semblable")
    func decorQuiBouge() {
        let a = EmpreinteTexte(image(texteEn: 10..<80, fond: 40))
        let b = EmpreinteTexte(image(texteEn: 10..<80, fond: 180))
        #expect(a.semblable(a: b))
    }

    @Test("Un autre texte change l'empreinte")
    func texteQuiChange() {
        let a = EmpreinteTexte(image(texteEn: 10..<80))
        let b = EmpreinteTexte(image(texteEn: 10..<140))
        #expect(!a.semblable(a: b))
    }
}
