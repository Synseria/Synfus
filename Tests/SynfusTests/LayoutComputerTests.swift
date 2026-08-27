import Testing
import CoreGraphics
@testable import Synfus

/// Le calcul des dispositions est pur : une zone, un nombre, des cadres. Tout
/// ce qui touche l'écran ou l'Accessibilité reste dans `WindowArranger` et se
/// vérifie en conditions réelles.
struct LayoutComputerTests {

    private static let zone = CGRect(x: 0, y: 25, width: 1728, height: 1067)
    private static let e = LayoutComputer.espacement

    private func cadres(_ disposition: Disposition, _ nombre: Int,
                        principal: Int = 0, zone: CGRect = zone) -> [CGRect] {
        LayoutComputer.cadres(disposition, nombre: nombre,
                              indexPrincipal: principal, dans: zone)
    }

    // MARK: - Comptes

    @Test("Aucune fenêtre, aucun cadre", arguments: Disposition.allCases)
    func vide(_ disposition: Disposition) {
        #expect(cadres(disposition, 0).isEmpty)
        #expect(cadres(disposition, -1).isEmpty)
    }

    @Test("Une fenêtre seule reçoit la zone entière", arguments: Disposition.allCases)
    func seule(_ disposition: Disposition) {
        #expect(cadres(disposition, 1) == [Self.zone])
    }

    @Test("Autant de cadres que de fenêtres", arguments: Disposition.allCases)
    func comptes(_ disposition: Disposition) {
        for nombre in 2...8 {
            #expect(cadres(disposition, nombre).count == nombre)
        }
    }

    // MARK: - Confinement et non-chevauchement

    @Test("Tous les cadres tiennent dans la zone", arguments: Disposition.allCases)
    func confinement(_ disposition: Disposition) {
        for nombre in 2...8 {
            for cadre in cadres(disposition, nombre) {
                #expect(Self.zone.insetBy(dx: -0.5, dy: -0.5).contains(cadre))
            }
        }
    }

    @Test("Les cadres ne se chevauchent pas", arguments: Disposition.allCases)
    func chevauchement(_ disposition: Disposition) {
        for nombre in 2...8 {
            let tous = cadres(disposition, nombre)
            for (i, a) in tous.enumerated() {
                for b in tous[(i + 1)...] {
                    #expect(!a.insetBy(dx: 0.5, dy: 0.5).intersects(b.insetBy(dx: 0.5, dy: 0.5)))
                }
            }
        }
    }

    // MARK: - Côte à côte

    @Test("Côte à côte : colonnes égales, pleine hauteur")
    func coteACote() {
        let tous = cadres(.coteACote, 4)
        let largeurs = Set(tous.map { ($0.width * 10).rounded() })
        #expect(largeurs.count == 1)
        for cadre in tous {
            #expect(cadre.height == Self.zone.height)
            #expect(cadre.minY == Self.zone.minY)
        }
        #expect(tous.map(\.minX) == tous.map(\.minX).sorted())
    }

    // MARK: - Mosaïque

    @Test("La grille est approximativement carrée")
    func grille() {
        #expect(LayoutComputer.dimensionsGrille(nombre: 2) == (2, 1))
        #expect(LayoutComputer.dimensionsGrille(nombre: 4) == (2, 2))
        #expect(LayoutComputer.dimensionsGrille(nombre: 5) == (3, 2))
        #expect(LayoutComputer.dimensionsGrille(nombre: 8) == (3, 3))
        #expect(LayoutComputer.dimensionsGrille(nombre: 9) == (3, 3))
        #expect(LayoutComputer.dimensionsGrille(nombre: 0) == (0, 0))
    }

    @Test("Mosaïque : la dernière rangée reste alignée à gauche")
    func rangeeIncomplete() {
        let tous = cadres(.mosaique, 5) // 3 × 2, la seconde rangée n'a que 2 cadres
        #expect(tous[3].minX == Self.zone.minX)
        #expect(tous[3].minY > tous[0].minY)
    }

    // MARK: - Un grand + vignettes

    @Test("Le principal a la plus grande aire")
    func principal() {
        for index in 0..<4 {
            let tous = cadres(.principale, 4, principal: index)
            let aires = tous.map { $0.width * $0.height }
            #expect(aires[index] == aires.max())
        }
    }

    @Test("Un index principal hors bornes est serré aux bornes")
    func principalHorsBornes() {
        #expect(cadres(.principale, 3, principal: 7) == cadres(.principale, 3, principal: 2))
        #expect(cadres(.principale, 3, principal: -2) == cadres(.principale, 3, principal: 0))
    }

    @Test("Les vignettes partagent la colonne à hauteurs égales")
    func vignettes() {
        let tous = cadres(.principale, 4, principal: 0)
        let vignettes = Array(tous.dropFirst())
        let hauteurs = Set(vignettes.map { ($0.height * 10).rounded() })
        #expect(hauteurs.count == 1)
        #expect(Set(vignettes.map(\.minX)).count == 1)
        #expect(vignettes.allSatisfy { $0.width >= LayoutComputer.colonneMinimale })
    }

    // MARK: - Conversion de repère

    @Test("Écran principal : le haut Cocoa devient le haut AX")
    func conversionPrincipale() {
        // 1728 × 1117, barre de menus de 25 pt, Dock masqué : visibleFrame
        // s'arrête à y = 1092 en Cocoa.
        let zone = LayoutComputer.zoneAX(
            visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1092),
            hauteurPrincipale: 1117
        )
        #expect(zone == CGRect(x: 0, y: 25, width: 1728, height: 1092))
    }

    @Test("Écran secondaire au-dessus du principal : ordonnée AX négative")
    func conversionSecondaire() {
        // Un écran 2560 × 1440 posé au-dessus du principal (1117 de haut) :
        // en Cocoa son cadre visible va de 1117 à 2532 (25 pt de barre de menus).
        let zone = LayoutComputer.zoneAX(
            visibleFrame: CGRect(x: -400, y: 1117, width: 2560, height: 1415),
            hauteurPrincipale: 1117
        )
        #expect(zone == CGRect(x: -400, y: -1415, width: 2560, height: 1415))
    }

    @Test("Écran secondaire sous le principal : ordonnée AX au-delà de la hauteur")
    func conversionEnDessous() {
        let zone = LayoutComputer.zoneAX(
            visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
            hauteurPrincipale: 1117
        )
        #expect(zone == CGRect(x: 0, y: 1117, width: 1920, height: 1080))
    }
}
