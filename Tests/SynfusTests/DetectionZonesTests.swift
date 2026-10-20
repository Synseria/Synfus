import CoreGraphics
import Testing
@testable import Synfus

/// Les zones retrouvées sur ce que l'OCR lit du contenu entier — textes et
/// cadres relevés sur de vraies captures (fenêtre de 1728 × 1084 points).
struct DetectionZonesTests {
    private typealias Vu = DetectionZones.TexteVu

    private static func vu(_ x: Double, _ y: Double, _ l: Double, _ h: Double, _ texte: String) -> Vu {
        Vu(texte: texte, cadre: CGRect(x: x, y: y, width: l, height: h))
    }

    /// Relevé sur `20260914-183523` et `20260914-123833`.
    private static let ecran: [Vu] = [
        vu(0.003, 0.036, 0.252, 0.026, "Montagne des Koalaks (Village des Éleveu.."),
        vu(0.004, 0.060, 0.077, 0.021, "-16, 1 - Niveau 1"),
        vu(0.003, 0.081, 0.041, 0.024, "[SANCT]"),
        vu(0.007, 0.119, 0.106, 0.015, "De Brikke et de Brokke"),
        vu(0.017, 0.138, 0.080, 0.014, "Trouver Brikke I1 forgeronne"),
        vu(0.016, 0.848, 0.195, 0.012, "[18:341 Vous connaissez une nouvelle attitude : Dofus Ocre"),
        vu(0.016, 0.862, 0.106, 0.012, "[18:341 Bienvenue dans DOFUS !"),
        vu(0.016, 0.874, 0.358, 0.014, "Pour ne pas te faire voler ton compte, n'entre iamais tes identifiants ailleurs"),
        vu(0.016, 0.902, 0.182, 0.017, "[12:29] Terminez votre tour avec le bouton Fin de tour."),
        vu(0.411, 0.902, 0.035, 0.020, "100%"),
        vu(0.016, 0.917, 0.212, 0.012, "(14:04] Précédente connexion sur ce compte : 14/09/2026 à 17:43"),
        vu(0.016, 0.957, 0.190, 0.014, "[18:34] Un membre de votre quilde, Syn-Ops, est en ligne."),
        vu(0.715, 0.957, 0.039, 0.024, "11* 107"),
    ]

    private static func contient(_ zone: ZoneEcran?, _ texte: Vu) -> Bool {
        zone.map { $0.rect.contains(texte.cadre) } ?? false
    }

    @Test("Position, tchat et cœur se retrouvent, chacun autour de son texte")
    func ecranOrdinaire() throws {
        let zones = DetectionZones.detecter(Self.ecran)
        let position = try #require(zones[.position])
        #expect(Self.contient(position, Self.ecran[0]) && Self.contient(position, Self.ecran[1]))
        #expect(!Self.contient(position, Self.ecran[3]))
        #expect(position.largeur >= ZoneEcran.positionParDefaut.largeur)
        let tchat = try #require(zones[.tchat])
        for ligne in Self.ecran[5...11] where ligne.cadre.minX < 0.1 { #expect(Self.contient(tchat, ligne), "\(ligne.texte)") }
        #expect(!Self.contient(tchat, Self.ecran[9]))
        let vie = try #require(zones[.vie])
        #expect(Self.contient(vie, Self.ecran[9]))
        #expect(!Self.contient(vie, Self.ecran[12]))
        // « Fin de tour » dans une ligne du tchat n'est pas le bouton.
        #expect(zones[.combat] == nil)
        // Sans quêtes ni indices reconnus, pas de suivi.
        #expect(zones[.quetes] == nil && zones[.chasse] == nil)
    }

    @Test("Le suivi de quêtes part de son premier titre et garde au moins le bas du défaut")
    func suiviDeQuetes() throws {
        let quetes = try #require(DetectionZones.detecter(Self.ecran, titres: [3])[.quetes])
        #expect(Self.contient(quetes, Self.ecran[3]) && Self.contient(quetes, Self.ecran[4]))
        #expect(!Self.contient(quetes, Self.ecran[1]))
        #expect(quetes.y + quetes.hauteur >= ZoneEcran.quetesParDefaut.y + ZoneEcran.quetesParDefaut.hauteur - 0.001)
        // Un « titre » lu dans le tchat ne fait pas un suivi.
        #expect(DetectionZones.detecter(Self.ecran, titres: [11])[.quetes] == nil)
    }

    @Test("Le bouton de fin de tour, en bas à droite, et son décompte au-dessus")
    func combat() throws {
        let bouton = Self.vu(0.82, 0.93, 0.06, 0.02, "FIN DE TOUR")
        let decompte = Self.vu(0.84, 0.885, 0.02, 0.018, "29s")
        let zone = try #require(DetectionZones.detecter(Self.ecran + [bouton, decompte])[.combat])
        #expect(Self.contient(zone, bouton) && Self.contient(zone, decompte))
        #expect(zone.bornee() == zone)
    }

    @Test("Des coordonnées mal lues sur l'écran entier suffisent à trouver la zone")
    func coordonneesMalLues() {
        #expect(DetectionZones.ressembleAuxCoordonnees("316, 1 - Niveau T"))
        #expect(DetectionZones.ressembleAuxCoordonnees("-29, -57 - Nivcau 10"))
        #expect(!DetectionZones.ressembleAuxCoordonnees("Montagne des Koalaks"))
        #expect(!DetectionZones.ressembleAuxCoordonnees("[SANCT]"))
    }

    @Test("Rien de reconnaissable : aucune zone")
    func rien() {
        #expect(DetectionZones.detecter([Self.vu(0.4, 0.4, 0.1, 0.02, "Dofus")]).isEmpty)
    }

    @Test("L'heure du tchat se reconnaît malgré l'OCR : « [18:341 », « (14:04] »")
    func heure() {
        #expect(Harebourg.heure("[18:341 Bienvenue") != nil)
        #expect(Harebourg.heure("(14:04] Syn-App : 1%") != nil)
        #expect(Harebourg.perso("[14:041 Syn-App : Confusion 90° horaire", parmi: ["Syn-App"]) == "Syn-App")
        #expect(Harebourg.heure("Bienvenue dans DOFUS !") == nil)
    }
}
