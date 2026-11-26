import CoreGraphics
import Testing
@testable import Synfus

@Suite("Grille isométrique")
struct GrilleIsoTests {
    private let centre = CGPoint(x: 400, y: 300)
    private let a: CGFloat = 37

    @Test("Le centre projeté d'une case retombe dans la case")
    func allerRetour() {
        for x in -7...7 {
            for y in -7...7 {
                let p = GrilleIso.projeter(x, y, a: a, centre: centre)
                #expect(GrilleIso.caseSous(p, a: a, centre: centre) == (x, y))
            }
        }
    }

    @Test("Tout l'intérieur d'un losange est sa case, jusqu'au bord")
    func interieur() {
        let sommets = GrilleIso.losange(2, -1, a: a, centre: centre)
        let p = GrilleIso.projeter(2, -1, a: a, centre: centre)
        #expect(sommets.count == 4)
        for sommet in sommets {
            // Un peu en deçà de chaque sommet, vers le centre.
            let dedans = CGPoint(x: p.x + (sommet.x - p.x) * 0.95, y: p.y + (sommet.y - p.y) * 0.95)
            #expect(GrilleIso.caseSous(dedans, a: a, centre: centre) == (2, -1))
        }
        // Juste au-delà du sommet droit : la case voisine à droite à l'écran (x + 1, y − 1).
        let dehors = CGPoint(x: sommets[1].x + 1, y: sommets[1].y)
        #expect(GrilleIso.caseSous(dehors, a: a, centre: centre) == (3, -2))
    }

    @Test("x descend vers la droite, y vers la gauche")
    func sens() {
        let origine = GrilleIso.projeter(0, 0, a: a, centre: centre)
        let x = GrilleIso.projeter(1, 0, a: a, centre: centre)
        let y = GrilleIso.projeter(0, 1, a: a, centre: centre)
        #expect(origine == centre)
        #expect(x.x > origine.x && x.y > origine.y)
        #expect(y.x < origine.x && y.y > origine.y)
    }
}
