import Testing
import Foundation
import CoreGraphics
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

/// La géométrie des zones de lecture : fractions du contenu, sans barre de
/// titre, ramenées à une hauteur fixe.
struct ZoneEcranTests {

    @Test("En fenêtré, la zone se place sous la barre de titre")
    func sousLaBarreDeTitre() {
        let contenu = ZoneEcran.contenu(fenetre: CGSize(width: 1000, height: 628), barreTitre: 28, pleinEcran: false)
        #expect(contenu == CGRect(x: 0, y: 28, width: 1000, height: 600))
        let source = ZoneEcran.source(CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.1), contenu: contenu)
        #expect(source == CGRect(x: 100, y: 328, width: 200, height: 60))
    }

    @Test("En plein écran, le contenu est toute la fenêtre")
    func pleinEcran() {
        let contenu = ZoneEcran.contenu(fenetre: CGSize(width: 1728, height: 1059), barreTitre: 28, pleinEcran: true)
        #expect(contenu == CGRect(x: 0, y: 0, width: 1728, height: 1059))
    }

    @Test("La même zone suit la taille de la fenêtre")
    func suitLaTaille() {
        let zone = ZoneEcran.positionParDefaut.rect
        let petite = ZoneEcran.source(zone, contenu: CGRect(x: 0, y: 0, width: 800, height: 500))
        let grande = ZoneEcran.source(zone, contenu: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        #expect(grande.width == petite.width * 2)
        #expect(grande.minY == petite.minY * 2)
    }

    @Test("L'échelle ramène le contenu à la hauteur de référence, sans dépasser le natif")
    func echelle() {
        #expect(ZoneEcran.echelle(hauteurContenu: 1080, plafond: 2) == 1)
        #expect(ZoneEcran.echelle(hauteurContenu: 2160, plafond: 2) == 0.5)
        #expect(ZoneEcran.echelle(hauteurContenu: 360, plafond: 2) == 2)
        #expect(ZoneEcran.echelle(hauteurContenu: 0, plafond: 2) == 1)
    }

    @Test("Une zone tracée hors du contenu y est ramenée")
    func bornee() {
        let zone = ZoneEcran(x: 0.95, y: -0.1, largeur: 0.2, hauteur: 0.001).bornee()
        #expect(zone.x + zone.largeur <= 1)
        #expect(zone.y == 0)
        #expect(zone.hauteur == ZoneEcran.tailleMinimale)
    }
}

/// Le bouton « Fin de tour » : rose, gris ou absent. Les lignes sont celles
/// que Vision a rendues sur une vraie capture.
struct LectureCombatTests {

    @Test("Fin de tour sur fond rose, avec le décompte : mon tour")
    func monTour() {
        let constat = LectureCombat.classer(lignes: ["29s", "FIN DE TOUR"], rose: 0.21)
        #expect(constat == .init(genre: .monTour, secondes: 29))
    }

    @Test("Fin de tour sans rose : le tour d'un autre")
    func pasMonTour() {
        #expect(LectureCombat.classer(lignes: ["12s", "FIN DE TOUR"], rose: 0.01).genre == .pasMonTour)
    }

    @Test("Rien de lisible dans la zone : hors combat, même s'il y a du rose")
    func horsCombat() {
        #expect(LectureCombat.classer(lignes: [], rose: 0.3).genre == .horsCombat)
        #expect(LectureCombat.classer(lignes: ["Astrub"], rose: 0).genre == .horsCombat)
    }

    @Test("Le bouton se reconnaît en anglais, en espagnol, et malgré l'OCR")
    func langues() {
        #expect(LectureCombat.classer(lignes: ["END TURN"], rose: 0.2).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["FIN DE TURNO"], rose: 0.2).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["FIN DETOUR"], rose: 0.2).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["PRÊT"], rose: 0).genre == .placement)
        #expect(LectureCombat.classer(lignes: ["READY"], rose: 0).genre == .placement)
    }

    @Test("Le décompte se lit collé ou espacé, et rien d'autre ne passe pour lui")
    func decompte() {
        #expect(LectureCombat.decompte("29s") == 29)
        #expect(LectureCombat.decompte(" 5 S") == 5)
        #expect(LectureCombat.decompte("FIN DE TOUR") == nil)
        #expect(LectureCombat.decompte("s") == nil)
        #expect(LectureCombat.decompte("1234s") == nil)
    }

    @Test("Le rose du bouton compte, son liseré sombre et le gris non")
    func ratioRose() {
        let rose: [UInt8] = [194, 112, 185, 255]
        let lisere: [UInt8] = [76, 45, 72, 255]
        let gris: [UInt8] = [128, 128, 128, 255]
        let vert: [UInt8] = [173, 255, 68, 255]
        #expect(LectureCombat.ratioRose(rgba: rose + rose + lisere + gris) == 0.5)
        #expect(LectureCombat.ratioRose(rgba: vert + gris) == 0)
        #expect(LectureCombat.ratioRose(rgba: []) == 0)
    }

    /// Relevés sur une vraie capture du bouton grisé : son dégradé gris et les
    /// icônes lavande pâle de la rangée du dessous — 0 % de rose mesuré sur
    /// l'image entière, lue « FIN DE TOUR » → pas son tour.
    @Test("Le bouton grisé et ses icônes lavande ne comptent pas comme rose")
    func boutonGrise() {
        let gris1: [UInt8] = [139, 139, 139, 255]
        let gris2: [UInt8] = [120, 119, 119, 255]
        let fond: [UInt8] = [60, 55, 61, 255]
        let lavande: [UInt8] = [205, 180, 215, 255]
        #expect(LectureCombat.ratioRose(rgba: gris1 + gris2 + fond + lavande) == 0)
        #expect(LectureCombat.classer(lignes: ["FIN DE TOUR"], rose: 0).genre == .pasMonTour)
    }

    @Test("Un tour qui continue garde son échéance ; un nouveau décompte la remplace")
    func echeance() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let debut = EtatCombat.depuis(.init(genre: .monTour, secondes: 30), avant: nil, maintenant: t0)
        #expect(debut == .monTour(fin: t0.addingTimeInterval(30)))
        let suite = EtatCombat.depuis(.init(genre: .monTour, secondes: nil), avant: debut,
                                      maintenant: t0.addingTimeInterval(5))
        #expect(suite == debut)
        #expect(EtatCombat.depuis(.init(genre: .pasMonTour, secondes: 12), avant: debut, maintenant: t0) == .pasMonTour)
        #expect(!EtatCombat.horsCombat.enCombat)
    }

    @Test("Le même texte passé du rose au gris relance l'OCR")
    func signature() {
        let empreinte = EmpreinteTexte(cases: Array(repeating: false, count: EmpreinteTexte.colonnes * EmpreinteTexte.lignes))
        let rose = SignatureZone(empreinte: empreinte, rose: 0.21)
        let gris = SignatureZone(empreinte: empreinte, rose: 0.01)
        let roseAussi = SignatureZone(empreinte: empreinte, rose: 0.35)
        #expect(!rose.semblable(a: gris))
        #expect(rose.semblable(a: roseAussi))
        #expect(SignatureZone(empreinte: empreinte, rose: nil).semblable(a: SignatureZone(empreinte: empreinte, rose: nil)))
    }
}
