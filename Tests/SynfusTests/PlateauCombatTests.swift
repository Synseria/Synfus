import CoreGraphics
import Testing
@testable import Synfus

@Suite("Plateau de combat retrouvé sur une capture")
struct PlateauCombatTests {
    /// Un plateau synthétique : cases beiges en damier de deux tons, joints
    /// sombres d'un pixel, la case `active` cernée d'un liseré blanc, la case
    /// `visee` rouge à liseré blanc.
    static func plateau(largeur: Int = 900, hauteur: Int = 560, a: Double, centre: CGPoint,
                        active: (Int, Int)? = nil, visee: (Int, Int)? = nil) -> ImageRVB {
        var pixels = [UInt8](repeating: 0, count: largeur * hauteur * 4)
        for py in 0..<hauteur {
            for px in 0..<largeur {
                let u = (Double(px) - centre.x) / a, v = (Double(py) - centre.y) / (a / 2)
                let fx = (u + v) / 2, fy = (v - u) / 2
                let cx = Int(fx.rounded()), cy = Int(fy.rounded())
                let dx = abs(fx - Double(cx)), dy = abs(fy - Double(cy))
                let bord = max(dx, dy)
                var c: (UInt8, UInt8, UInt8) = (cx + cy) % 2 == 0 ? (238, 214, 170) : (226, 198, 150)
                if bord > 0.47 { c = (150, 120, 90) }
                if let visee, (cx, cy) == visee { c = bord > 0.42 ? (250, 250, 250) : (200, 40, 50) }
                if let active, (cx, cy) == active, bord > 0.40, bord <= 0.47 { c = (252, 252, 250) }
                let i = (py * largeur + px) * 4
                pixels[i] = c.0; pixels[i + 1] = c.1; pixels[i + 2] = c.2; pixels[i + 3] = 255
            }
        }
        return ImageRVB(width: largeur, height: hauteur, pixels: pixels)
    }

    /// Deux grilles valent la même si leurs cases coïncident : même `a`, et un
    /// centre de l'une est un centre de l'autre.
    private func coincide(_ g: PlateauCombat.Grille, a: Double, centre: CGPoint) -> Bool {
        guard abs(g.a - a) / a < 0.02 else { return false }
        let (x, y) = GrilleIso.caseSous(centre, a: CGFloat(g.a), centre: g.centre)
        let p = GrilleIso.projeter(x, y, a: CGFloat(g.a), centre: g.centre)
        return hypot(p.x - centre.x, p.y - centre.y) < 0.12 * a
    }

    @Test("La grille d'un damier synthétique, à toutes les tailles", arguments: [18.0, 27.5, 40.0, 49.0])
    func grille(a: Double) throws {
        let centre = CGPoint(x: 431.3, y: 257.8)
        let g = try #require(PlateauCombat.grille(Self.plateau(a: a, centre: centre)))
        #expect(coincide(g, a: a, centre: centre), "\(g)")
    }

    @Test("La case active : le liseré blanc ; pas la case visée, rouge")
    func caseActive() throws {
        let centre = CGPoint(x: 431.3, y: 257.8)
        let image = Self.plateau(a: 32, centre: centre, active: (2, -1), visee: (-3, 1))
        let g = try #require(PlateauCombat.grille(image))
        let position = try #require(PlateauCombat.caseActive(image, grille: g))
        let p = GrilleIso.projeter(position.x, position.y, a: CGFloat(g.a), centre: g.centre)
        let attendu = GrilleIso.projeter(2, -1, a: 32, centre: centre)
        #expect(hypot(p.x - attendu.x, p.y - attendu.y) < 4)
        #expect(PlateauCombat.caseActive(Self.plateau(a: 32, centre: centre, visee: (-3, 1)), grille: g) == nil)
    }

    @Test("Sans damier, pas de grille")
    func sansDamier() {
        let uni = ImageRVB(width: 300, height: 200, pixels: [UInt8](repeating: 128, count: 300 * 200 * 4))
        #expect(PlateauCombat.grille(uni) == nil)
    }

    @Test("Une grille retrouvée sur une autre case coïncide avec la première")
    func coincide() {
        let contenu = CGSize(width: 1600, height: 1000)
        let g = GrilleIso(origine: CGPoint(x: 0.5, y: 0.4), demiLargeur: 0.04, rapport: 1.6)
        let a = 0.04 * 1000
        // Trois cases plus loin (x + 3, y − 1) : mêmes cases.
        let ailleurs = CGPoint(x: (800 + (3 - -1) * a) / 1600, y: (400 + (3 + -1) * a / 2) / 1000)
        #expect(g.coincide(avec: GrilleIso(origine: ailleurs, demiLargeur: 0.0402, rapport: 1.6), contenu: contenu))
        // Une demi-case de côté, ou une autre taille : une autre grille.
        #expect(!g.coincide(avec: GrilleIso(origine: CGPoint(x: (800 + a / 2) / 1600, y: 0.4), demiLargeur: 0.04, rapport: 1.6), contenu: contenu))
        #expect(!g.coincide(avec: GrilleIso(origine: g.origine, demiLargeur: 0.045, rapport: 1.6), contenu: contenu))
    }
}
