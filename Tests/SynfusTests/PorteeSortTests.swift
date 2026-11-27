import CoreGraphics
import Testing
@testable import Synfus

extension PorteeSort {
    private static let sable = Couleur(r: 248, v: 220, b: 168)
    private static let foncee = Couleur(r: 114, v: 116, b: 157)
    private static let claire = Couleur(r: 137, v: 144, b: 159)
    private static let marque = Couleur(r: 200, v: 45, b: 55)

    private static func signature(_ couleur: Couleur) -> Signature { Signature(taches: Array(repeating: couleur, count: 5)) }

    /// Une portée lue comme en jeu : le plateau de sable sans sort, puis ces
    /// cases bleuies (foncées, claires) ou couvertes ; tout le reste libre.
    static func bleuie(foncees: [GrilleIso.Case], claires: [GrilleIso.Case] = [],
                       couvertes: [GrilleIso.Case] = []) -> PorteeSort {
        let toutes = Set(foncees + claires + couvertes + (-15...15).map { GrilleIso.Case($0, 15) })
        var portee = PorteeSort()
        portee.lire(Dictionary(uniqueKeysWithValues: toutes.map { ($0, signature(sable)) }))
        var lues = Dictionary(uniqueKeysWithValues: toutes.map { ($0, signature(sable)) })
        for c in foncees { lues[c] = signature(foncee) }
        for c in claires { lues[c] = signature(claire) }
        for c in couvertes { lues[c] = signature(marque) }
        portee.lire(lues)
        return portee
    }
}

@Suite("Portée du sort lue sur le plateau")
struct PorteeSortTests {
    private typealias Case = GrilleIso.Case

    @Test("Bleu foncé à portée, bleu clair sans ligne de vue, sable libre")
    func teintes() {
        let portee = PorteeSort.bleuie(foncees: [Case(1, 0), Case(2, 0), Case(3, 0)], claires: [Case(0, 2), Case(0, 3)])
        #expect(portee.sortPrepare)
        #expect(portee.teinte(Case(2, 0)) == .portee)
        #expect(portee.teinte(Case(0, 3)) == .horsVue)
        #expect(portee.teinte(Case(5, 15)) == .libre)
        // Hors des cases lues : libre (hors de la fenêtre).
        #expect(portee.teinte(Case(40, 40)) == .libre)
    }

    @Test("Une seule teinte de bleu : tout est à portée")
    func uneTeinte() {
        let portee = PorteeSort.bleuie(foncees: [Case(1, 0), Case(2, 0), Case(0, 1), Case(0, 2)])
        #expect([Case(1, 0), Case(2, 0), Case(0, 1), Case(0, 2)].allSatisfy { portee.teinte($0) == .portee })
    }

    @Test("Sans sort, rien n'est teinté ; deux cases bleuies ne font pas un sort")
    func sansSort() {
        #expect(!PorteeSort.bleuie(foncees: []).sortPrepare)
        #expect(!PorteeSort.bleuie(foncees: [Case(1, 0), Case(2, 0)]).sortPrepare)
    }

    @Test("Une case couverte garde ce qu'on en savait : la cible survolée reste à portée")
    func memoire() {
        let sable = PorteeSort.Signature(taches: Array(repeating: .init(r: 248, v: 220, b: 168), count: 5))
        let bleu = PorteeSort.Signature(taches: Array(repeating: .init(r: 114, v: 116, b: 157), count: 5))
        let rouge = PorteeSort.Signature(taches: Array(repeating: .init(r: 200, v: 45, b: 55), count: 5))
        let cases = (0..<6).map { Case($0, 0) }
        var portee = PorteeSort()
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, sable) }))
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, bleu) }))
        var survolee = Dictionary(uniqueKeysWithValues: cases.map { ($0, bleu) })
        survolee[Case(3, 0)] = rouge
        portee.lire(survolee)
        #expect(portee.teinte(Case(3, 0)) == .portee)
        // Le sort lâché, le plateau redevient la référence.
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, sable) }))
        #expect(!portee.sortPrepare)
    }

    @Test("Le vert d'un déplacement n'est pas le bleu d'une portée")
    func deplacement() {
        let sable = PorteeSort.Signature(taches: Array(repeating: .init(r: 248, v: 220, b: 168), count: 5))
        let vert = PorteeSort.Signature(taches: Array(repeating: .init(r: 90, v: 200, b: 90), count: 5))
        #expect(PorteeSort.comparer(vert, a: sable) != .bleuie(luma: vert.taches[0].luma))
    }

    @Test("Une référence prise sort préparé se corrige dès le sort lâché")
    func referenceBleue() {
        let sable = PorteeSort.Signature(taches: Array(repeating: .init(r: 248, v: 220, b: 168), count: 5))
        let bleu = PorteeSort.Signature(taches: Array(repeating: .init(r: 114, v: 116, b: 157), count: 5))
        let cases = (0..<6).map { Case($0, 0) }
        var portee = PorteeSort()
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, bleu) }))
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, sable) }))
        #expect(!portee.sortPrepare)
        portee.lire(Dictionary(uniqueKeysWithValues: cases.map { ($0, bleu) }))
        #expect(portee.sortPrepare)
    }

    @Test("Les signatures mesurées sur une image : le centre et les côtés de chaque case")
    func mesure() {
        let centre = CGPoint(x: 300, y: 200), a = 30.0
        let bleues: Set<Case> = [Case(1, 0), Case(2, 0), Case(1, 1)]
        let sansSort = Self.plateau(a: a, centre: centre, bleues: [])
        let avecSort = Self.plateau(a: a, centre: centre, bleues: bleues)
        let grille = PlateauCombat.Grille(a: a, centre: centre)
        var portee = PorteeSort()
        portee.lire(PorteeSort.mesurer(sansSort, grille: grille))
        portee.lire(PorteeSort.mesurer(avecSort, grille: grille))
        #expect(Set(portee.teintes.filter { $0.value == .portee }.keys) == bleues)
        #expect(portee.teinte(Case(0, 0)) == .libre)
    }

    /// Un plateau de sable à joints sombres, ces cases teintées de bleu.
    private static func plateau(a: Double, centre: CGPoint, bleues: Set<Case>) -> ImageRVB {
        let largeur = 600, hauteur = 400
        var pixels = [UInt8](repeating: 255, count: largeur * hauteur * 4)
        for py in 0..<hauteur {
            for px in 0..<largeur {
                let u = (Double(px) - centre.x) / a, v = (Double(py) - centre.y) / (a / 2)
                let fx = (u + v) / 2, fy = (v - u) / 2
                let c = Case(Int(fx.rounded()), Int(fy.rounded()))
                let bord = max(abs(fx - Double(c.x)), abs(fy - Double(c.y)))
                let couleur: (UInt8, UInt8, UInt8) = bord > 0.47 ? (150, 120, 90) : bleues.contains(c) ? (114, 116, 157) : (248, 220, 168)
                let i = (py * largeur + px) * 4
                pixels[i] = couleur.0; pixels[i + 1] = couleur.1; pixels[i + 2] = couleur.2
            }
        }
        return ImageRVB(width: largeur, height: hauteur, pixels: pixels)
    }
}
