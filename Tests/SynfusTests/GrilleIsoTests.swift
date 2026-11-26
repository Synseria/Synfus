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

    // MARK: - Grille calibrée

    /// Le contenu de `7.png` (2000 × 1234) : a mesuré à 53 px.
    private let contenu = CGSize(width: 2000, height: 1234)
    private var grille: GrilleIso {
        GrilleIso(origine: CGPoint(x: 0.5, y: 0.45), demiLargeur: 53.0 / 1234, rapport: 2000.0 / 1234)
    }

    @Test("Fraction du contenu → case → centre, sur toute la grille")
    func grilleAllerRetour() {
        for x in -7...7 {
            for y in -7...7 {
                let c = GrilleIso.Case(x, y)
                let p = grille.centre(c, contenu: contenu)
                let fraction = CGPoint(x: p.x / contenu.width, y: p.y / contenu.height)
                #expect(grille.caseSous(fraction: fraction, contenu: contenu) == c)
            }
        }
        #expect(grille.centre(GrilleIso.Case(0, 0), contenu: contenu) == CGPoint(x: 1000, y: 0.45 * 1234))
    }

    @Test("La même grille à une autre taille de fenêtre, même rapport")
    func autreTaille() {
        let moitie = CGSize(width: 1000, height: 617)
        let p = grille.centre(GrilleIso.Case(3, -2), contenu: moitie)
        #expect(grille.caseSous(fraction: CGPoint(x: p.x / 1000, y: p.y / 617), contenu: moitie) == GrilleIso.Case(3, -2))
        #expect(abs(grille.a(moitie) - 26.5) < 0.001)
        #expect(grille.valable(pour: moitie))
    }

    @Test("Un autre rapport invalide la grille")
    func rapport() {
        #expect(grille.valable(pour: contenu))
        #expect(grille.valable(pour: CGSize(width: 2010, height: 1234)))
        #expect(!grille.valable(pour: CGSize(width: 1728, height: 1084)))
        #expect(!grille.valable(pour: CGSize(width: 2000, height: 1054)))
        #expect(!grille.valable(pour: .zero))
    }

    @Test("Deux centres cliqués retrouvent a et l'origine", arguments: [
        GrilleIso.Case(6, 0), GrilleIso.Case(0, 5), GrilleIso.Case(4, -3), GrilleIso.Case(-5, -5),
    ])
    func depuis(ecart: GrilleIso.Case) throws {
        let a = grille.centre(GrilleIso.Case(0, 0), contenu: contenu)
        let b = grille.centre(ecart, contenu: contenu)
        let f = { (p: CGPoint) in CGPoint(x: p.x / self.contenu.width, y: p.y / self.contenu.height) }
        let retrouvee = try #require(GrilleIso.depuis(centreA: f(a), centreB: f(b), ecart: ecart, contenu: contenu))
        #expect(abs(retrouvee.demiLargeur - grille.demiLargeur) < 1e-9)
        #expect(abs(retrouvee.origine.x - grille.origine.x) < 1e-9)
        #expect(abs(retrouvee.origine.y - grille.origine.y) < 1e-9)
        #expect(abs(retrouvee.rapport - grille.rapport) < 1e-9)
    }

    @Test("Un clic à quelques pixels près donne a à mieux que 2 %")
    func depuisImprecis() throws {
        let a = grille.centre(GrilleIso.Case(0, 0), contenu: contenu)
        let b = grille.centre(GrilleIso.Case(8, 0), contenu: contenu)
        let decale = CGPoint(x: b.x + 4, y: b.y - 3)
        let retrouvee = try #require(GrilleIso.depuis(
            centreA: CGPoint(x: a.x / 2000, y: a.y / 1234), centreB: CGPoint(x: decale.x / 2000, y: decale.y / 1234),
            ecart: GrilleIso.Case(8, 0), contenu: contenu))
        #expect(abs(retrouvee.demiLargeur / grille.demiLargeur - 1) < 0.02)
    }

    @Test("Un écart nul, des points confondus ou une pente fausse : pas de grille")
    func depuisRefus() {
        let a = CGPoint(x: 0.5, y: 0.5)
        #expect(GrilleIso.depuis(centreA: a, centreB: CGPoint(x: 0.6, y: 0.55), ecart: GrilleIso.Case(0, 0),
                                 contenu: contenu) == nil)
        #expect(GrilleIso.depuis(centreA: a, centreB: a, ecart: GrilleIso.Case(4, 0), contenu: contenu) == nil)
        // B à l'horizontale de A alors que l'écart dit ↘ : pas une grille 2:1.
        #expect(GrilleIso.depuis(centreA: a, centreB: CGPoint(x: 0.7, y: 0.5), ecart: GrilleIso.Case(4, 0),
                                 contenu: contenu) == nil)
    }

    @Test("Les sommets d'une case de la grille sont ceux du losange en points")
    func losangeGrille() {
        let c = GrilleIso.Case(2, -1)
        #expect(grille.losange(c, contenu: contenu)
                == GrilleIso.losange(2, -1, a: grille.a(contenu), centre: CGPoint(x: 1000, y: 0.45 * 1234)))
    }
}
