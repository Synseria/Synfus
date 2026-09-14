import Testing
import Foundation
@testable import Synfus

/// La barre de sorts se trouve par la périodicité de ses cadres, sur une
/// image fabriquée : pas de capture du jeu dans le dépôt.
struct SpellBarLocatorTests {

    /// Une « fenêtre » sombre avec, en bas, `count` cases bordées de clair.
    private func window(width: Int = 900, height: Int = 600, count: Int = 10, rows: Int = 1,
                        side: Int = 44, gap: Int = 6, originX: Int = 200, bottomMargin: Int = 40,
                        noise: Bool = false) -> LumaBitmap {
        var image = LumaBitmap(width: width, height: height, fill: 30)
        if noise {
            // Un décor : quelques aplats plus clairs au-dessus de la barre.
            image.fill(CGRect(x: 100, y: 80, width: 300, height: 120), with: 90)
            image.fill(CGRect(x: 500, y: 200, width: 200, height: 60), with: 140)
        }
        for r in 0..<rows {
            let top = height - bottomMargin - side - r * (side + gap)
            for k in 0..<count {
                let x = originX + k * (side + gap)
                let cell = CGRect(x: x, y: top, width: side, height: side)
                image.fill(cell, with: 200)                       // le cadre
                image.fill(cell.insetBy(dx: 2, dy: 2), with: 60 + UInt8(k * 9 + r * 20))  // l'icône, variable
            }
        }
        return image
    }

    @Test("Dix cases régulières sont retrouvées, avec leur pas et leur côté")
    func dixCases() throws {
        let bar = try #require(SpellBarLocator.locate(in: window()))
        #expect(bar.cells.count == 10)
        #expect(bar.side == 44)
        #expect(bar.pitch == 50)
        #expect(abs(Int(bar.cells[0].minX) - 200) <= 1)
        #expect(abs(Int(bar.cells[0].minY) - (600 - 40 - 44)) <= 1)
        #expect(abs(Int(bar.cells[9].minX) - (200 + 9 * 50)) <= 1)
    }

    @Test("Le décor au-dessus de la barre ne la fait pas dévier")
    func decorIgnore() throws {
        let bar = try #require(SpellBarLocator.locate(in: window(noise: true)))
        #expect(bar.cells.count == 10)
        #expect(bar.side == 44)
    }

    @Test("La zone mémorisée couvre la barre avec une marge, en fractions de l'image")
    func zoneRelative() throws {
        let image = window()
        let bar = try #require(SpellBarLocator.locate(in: image))
        let region = bar.region(in: CGSize(width: image.width, height: image.height))
        #expect(region.minX < 200.0 / 900 && region.maxX > (200.0 + 9 * 50 + 44) / 900)
        #expect(region.maxY <= 1 && region.minY > 0.7)
    }

    @Test("Sans rangée de cases, rien n'est inventé")
    func rienSansBarre() {
        var image = LumaBitmap(width: 900, height: 600, fill: 30)
        image.fill(CGRect(x: 100, y: 500, width: 700, height: 20), with: 200)
        #expect(SpellBarLocator.locate(in: image) == nil)
    }

    @Test("Une taille d'interface différente change le côté, pas la détection")
    func autreEchelle() throws {
        let bar = try #require(SpellBarLocator.locate(in: window(width: 1800, height: 1100, count: 8,
                                                                  side: 72, gap: 8, originX: 400)))
        #expect(bar.cells.count == 8)
        #expect(bar.side == 72)
        #expect(bar.pitch == 80)
    }

    @Test("Trois rangées superposées sont rendues de haut en bas")
    func troisRangees() throws {
        let bar = try #require(SpellBarLocator.locate(in: window(count: 12, rows: 3)))
        #expect(bar.rows.count == 3)
        #expect(bar.rows.allSatisfy { $0.count == 12 })
        #expect(bar.rows[0][0].minY < bar.rows[2][0].minY)
        #expect(Int(bar.rows[2][0].minY - bar.rows[1][0].minY) == bar.pitch)
    }
}
