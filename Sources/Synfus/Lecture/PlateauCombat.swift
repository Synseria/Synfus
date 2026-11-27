import CoreGraphics
import Foundation

/// Une image en couleurs, en mémoire, ligne du haut d'abord : ce que la
/// luminance ne distingue pas — le blanc du contour de la case active du beige
/// des cases. Une struct de valeurs, fabriquée en test sans CoreGraphics.
struct ImageRVB: Sendable, Equatable {
    let width: Int
    let height: Int
    /// `height` lignes de `width` pixels de 4 octets (R, V, B, A).
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Rendu sRGB 8 bits par CoreGraphics, à `hauteur` lignes au plus : la
    /// grille se cherche aussi bien sur une image réduite, et bien plus vite.
    init?(cgImage: CGImage, hauteurMax: Int = 720) {
        let echelle = min(1, Double(hauteurMax) / Double(max(cgImage.height, 1)))
        let width = max(1, Int(Double(cgImage.width) * echelle)), height = max(1, Int(Double(cgImage.height) * echelle))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return nil }
        self.init(width: width, height: height, pixels: pixels)
    }

    @inline(__always) func rvb(_ x: Int, _ y: Int) -> (r: Int, v: Int, b: Int) {
        let i = (y * width + x) * 4
        return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
    }

    @inline(__always) func luma(_ x: Int, _ y: Int) -> Int {
        let p = rvb(x, y)
        return (p.r * 299 + p.v * 587 + p.b * 114) / 1000
    }
}

/// Le plateau de combat retrouvé sur une capture, sans calibrage : la grille
/// isométrique par la périodicité de ses bords, la case du perso dont c'est le
/// tour par le losange blanc et creux que le jeu trace autour de lui. Pur.
enum PlateauCombat {
    /// La grille trouvée, en pixels de l'image.
    struct Grille: Equatable, Sendable {
        /// La demi-largeur d'une case.
        let a: Double
        /// Le centre d'une case.
        let centre: CGPoint

        /// La même grille en fractions d'un contenu de cette taille.
        func enFractions(image: CGSize) -> GrilleIso {
            GrilleIso(origine: CGPoint(x: centre.x / image.width, y: centre.y / image.height),
                      demiLargeur: a / image.height, rapport: image.width / image.height)
        }
    }

    /// La demi-largeur d'une case, en fraction de la hauteur du contenu, que
    /// la recherche couvre : du plateau dézoomé à la caméra rapprochée.
    static let demiLargeurs: ClosedRange<Double> = 0.015...0.09
    /// La netteté de la périodicité (0…1) sous laquelle il n'y a pas de grille.
    static let scoreMin = 0.18

    // MARK: - Grille

    /// Les bords d'une grille 2:1 sont deux familles de droites : `x + 2y` et
    /// `2y − x` constants, espacées de `2a` chacune. L'énergie des bords,
    /// mesurée perpendiculairement à chaque famille, est projetée sur sa
    /// coordonnée ; l'autocorrélation des deux profils donne la période, le
    /// repli des profils sur elle la phase — d'où un centre de case.
    static func grille(_ image: ImageRVB) -> Grille? {
        let w = image.width, h = image.height
        guard w > 40, h > 40 else { return nil }
        let n1 = w + 2 * h + 1
        var profil1 = [Double](repeating: 0, count: n1)
        var profil2 = [Double](repeating: 0, count: n1)
        for y in 2..<(h - 2) {
            for x in 1..<(w - 1) {
                // Perpendiculaire à x + 2y = cte : (1, 2) ; à 2y − x = cte : (−1, 2).
                let e1 = abs(image.luma(x + 1, y + 2) - image.luma(x - 1, y - 2))
                let e2 = abs(image.luma(x - 1, y + 2) - image.luma(x + 1, y - 2))
                profil1[x + 2 * y] += Double(e1)
                profil2[2 * y - x + w] += Double(e2)
            }
        }
        let pMin = max(4, Int((demiLargeurs.lowerBound * Double(h) * 2).rounded(.down)))
        let pMax = min(n1 / 4, Int((demiLargeurs.upperBound * Double(h) * 2).rounded(.up)))
        guard pMax > pMin else { return nil }
        let p1 = centrer(profil1, fenetre: pMax * 2), p2 = centrer(profil2, fenetre: pMax * 2)
        let energie = autocorrelation(p1, 0) + autocorrelation(p2, 0)
        guard energie > 0 else { return nil }
        var meilleure = (periode: 0, score: -Double.infinity)
        for periode in pMin...pMax {
            let score = (autocorrelation(p1, periode) + autocorrelation(p2, periode)) / energie
            if score > meilleure.score { meilleure = (periode, score) }
        }
        guard meilleure.score >= scoreMin else { return nil }
        var periodeFine = affiner(p1, p2, autour: meilleure.periode)
        guard var phase1 = phase(p1, periode: periodeFine), var phase2 = phase(p2, periode: periodeFine) else { return nil }
        // Des joints faibles (mode normal, cases beiges) laissent gagner deux
        // cases pour une : s'il y a un joint, même moindre, au milieu de la
        // période dans les deux familles, la case en vaut la moitié.
        while periodeFine / 2 >= Double(pMin),
              joint(p1, periode: periodeFine, phase: phase1) >= seuilDemiJoint,
              joint(p2, periode: periodeFine, phase: phase2) >= seuilDemiJoint {
            periodeFine /= 2
            guard let q1 = phase(p1, periode: periodeFine), let q2 = phase(p2, periode: periodeFine) else { return nil }
            (phase1, phase2) = (q1, q2)
        }
        // Les bords sont aux demi-cases : un centre est à une demi-période d'eux.
        let t1 = phase1 + periodeFine / 2, t2 = phase2 + periodeFine / 2 - Double(w)
        return Grille(a: periodeFine / 2, centre: CGPoint(x: (t1 - t2) / 2, y: (t1 + t2) / 4))
    }

    /// Le profil moins sa moyenne glissante : seule la périodicité reste.
    private static func centrer(_ profil: [Double], fenetre: Int) -> [Double] {
        var cumul = [Double](repeating: 0, count: profil.count + 1)
        for i in profil.indices { cumul[i + 1] = cumul[i] + profil[i] }
        return profil.indices.map { i in
            let a = max(0, i - fenetre / 2), b = min(profil.count, i + fenetre / 2 + 1)
            return profil[i] - (cumul[b] - cumul[a]) / Double(b - a)
        }
    }

    private static func autocorrelation(_ p: [Double], _ decalage: Int) -> Double {
        guard decalage < p.count else { return 0 }
        var s = 0.0
        for i in 0..<(p.count - decalage) { s += p[i] * p[i + decalage] }
        return s
    }

    /// La période au dixième de pixel, par la somme des profils repliés.
    private static func affiner(_ p1: [Double], _ p2: [Double], autour periode: Int) -> Double {
        var meilleure = (Double(periode), -Double.infinity)
        for dixiemes in -10...10 {
            let candidate = Double(periode) + Double(dixiemes) / 10
            guard candidate > 2 else { continue }
            let contraste = repli(p1, periode: candidate).max()! + repli(p2, periode: candidate).max()!
            if contraste > meilleure.1 { meilleure = (candidate, contraste) }
        }
        return meilleure.0
    }

    /// Le profil replié sur la période, en `periode` cases arrondies.
    private static func repli(_ p: [Double], periode: Double) -> [Double] {
        let n = max(1, Int(periode.rounded()))
        var bacs = [Double](repeating: 0, count: n)
        for i in p.indices {
            let reste = Double(i).truncatingRemainder(dividingBy: periode)
            bacs[min(n - 1, Int(reste / periode * Double(n)))] += p[i]
        }
        return bacs
    }

    /// Un joint au milieu de la période, rapporté à celui de la phase, au-dessus du fond.
    static let seuilDemiJoint = 0.3

    private static func joint(_ p: [Double], periode: Double, phase: Double) -> Double {
        let bacs = lisse(repli(p, periode: periode), periode: periode)
        let n = bacs.count
        let fond = bacs.sorted()[n / 2]
        func valeur(_ t: Double) -> Double { bacs[((Int((t / periode * Double(n)).rounded(.down)) % n) + n) % n] }
        let principal = valeur(phase) - fond
        guard principal > 0 else { return 0 }
        return (valeur(phase + periode / 2) - fond) / principal
    }

    /// Le profil replié, lissé sur la portée de la mesure d'un bord.
    private static func lisse(_ bruts: [Double], periode: Double) -> [Double] {
        let n = bruts.count
        let demi = max(1, Int((portee * Double(n) / periode).rounded()))
        return (0..<n).map { i in (-demi...demi).reduce(0.0) { $0 + bruts[((i + $1) % n + n) % n] } }
    }

    /// Où les bords tombent dans la période. La mesure d'un bord s'étend de
    /// `portee` de part et d'autre (`± (1, 2)` décale la coordonnée de 5) : un
    /// joint répond par deux pics qui l'encadrent. Le profil replié est lissé
    /// sur cette largeur avant d'y chercher son maximum.
    private static let portee = 5.0

    private static func phase(_ p: [Double], periode: Double) -> Double? {
        let bacs = lisse(repli(p, periode: periode), periode: periode)
        let n = bacs.count
        guard let pic = bacs.indices.max(by: { bacs[$0] < bacs[$1] }) else { return nil }
        let voisins = [-1, 0, 1].map { (Double(pic + $0), max(0, bacs[(pic + $0 + n) % n])) }
        let poids = voisins.reduce(0) { $0 + $1.1 }
        let indice = poids > 0 ? voisins.reduce(0) { $0 + $1.0 * $1.1 } / poids : Double(pic)
        return (indice + 0.5) / Double(n) * periode
    }

    // MARK: - Case active

    /// La case dont le losange porte le contour blanc et creux du perso actif,
    /// en cases de la grille (`centre` = case 0, 0) ; `nil` si aucune ne le
    /// porte assez nettement. La case visée porte aussi un liseré blanc, mais
    /// son intérieur est rouge : écartée.
    static func caseActive(_ image: ImageRVB, grille: Grille) -> (x: Int, y: Int)? {
        let a = CGFloat(grille.a)
        // Les cases dont le centre tombe dans l'image.
        let coins = [CGPoint(x: 0, y: 0), CGPoint(x: image.width, y: 0), CGPoint(x: 0, y: image.height),
                     CGPoint(x: image.width, y: image.height)].map { GrilleIso.caseSous($0, a: a, centre: grille.centre) }
        let xs = coins.map(\.x), ys = coins.map(\.y)
        var meilleure: (position: (x: Int, y: Int), score: Double)?
        var deuxieme = 0.0
        for cx in xs.min()!...xs.max()! {
            for cy in ys.min()!...ys.max()! {
                let c = GrilleIso.projeter(cx, cy, a: a, centre: grille.centre)
                guard c.x > a, c.y > a / 2, c.x < CGFloat(image.width) - a, c.y < CGFloat(image.height) - a / 2 else { continue }
                let score = contourBlanc(image, centre: c, a: a)
                guard score >= seuilContour, !interieurRouge(image, centre: c, a: a),
                      grilleLocale(image, grille: grille, autour: c) >= seuilGrilleLocale else { continue }
                if score > (meilleure?.score ?? 0) {
                    deuxieme = meilleure?.score ?? deuxieme
                    meilleure = ((cx, cy), score)
                } else {
                    deuxieme = max(deuxieme, score)
                }
            }
        }
        // Deux cases presque aussi blanches : rien de sûr.
        guard let meilleure, meilleure.score >= avanceMin * deuxieme else { return nil }
        return meilleure.position
    }

    /// Ce que le contour d'une case a de blanc : la part sur tout le losange et
    /// sur ses deux côtés du bas, que le perso debout masque le moins. Mesuré :
    /// la case active en montre plus d'un quart, ses voisines presque rien.
    static let seuilContour = 0.25
    /// Les bords autour de la case suivent la grille au moins d'autant plus
    /// qu'ailleurs : la case est sur le plateau, pas sur un bouton de l'interface.
    static let seuilGrilleLocale = 1.4

    /// L'énergie des bords près des joints de la grille, rapportée à celle loin
    /// d'eux, dans les cases autour de `centre`. Sur le plateau, les joints
    /// portent les bords ; sur l'interface, ils tombent n'importe où.
    static func grilleLocale(_ image: ImageRVB, grille: Grille, autour centre: CGPoint) -> Double {
        let periode = 2 * grille.a
        let t1c = Double(grille.centre.x + 2 * grille.centre.y), t2c = Double(2 * grille.centre.y - grille.centre.x)
        let rayonX = Int(2.5 * grille.a), rayonY = Int(1.25 * grille.a)
        var pres = 0.0, nPres = 0, loin = 0.0, nLoin = 0
        for y in max(2, Int(centre.y) - rayonY)..<min(image.height - 2, Int(centre.y) + rayonY) {
            for x in max(1, Int(centre.x) - rayonX)..<min(image.width - 1, Int(centre.x) + rayonX) {
                let e1 = Double(abs(image.luma(x + 1, y + 2) - image.luma(x - 1, y - 2)))
                let e2 = Double(abs(image.luma(x - 1, y + 2) - image.luma(x + 1, y - 2)))
                // Distance au joint le plus proche, dans chaque famille : les joints sont aux demi-périodes du centre.
                func ecart(_ t: Double, _ tc: Double) -> Double {
                    let r = (t - tc - periode / 2).truncatingRemainder(dividingBy: periode)
                    let m = r < 0 ? r + periode : r
                    return min(m, periode - m)
                }
                for (e, d) in [(e1, ecart(Double(x + 2 * y), t1c)), (e2, ecart(Double(2 * y - x), t2c))] {
                    if d <= portee { pres += e; nPres += 1 } else if d >= periode / 4 { loin += e; nLoin += 1 }
                }
            }
        }
        guard nPres > 0, nLoin > 0 else { return 0 }
        return (pres / Double(nPres)) / max(1, loin / Double(nLoin))
    }

    /// La case retenue l'emporte au moins d'autant sur la suivante.
    static let avanceMin = 1.5

    /// Le contour blanc d'un losange réduit à `echelle`, côté par côté (haut-droit, bas-droit, bas-gauche, haut-gauche).
    private static func blancsParCote(_ image: ImageRVB, centre: CGPoint, a: CGFloat, echelle: CGFloat) -> [Double] {
        let sommets = [CGPoint(x: 0, y: -0.5), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0.5), CGPoint(x: -1, y: 0)]
        return (0..<4).map { cote in
            let debut = sommets[cote], fin = sommets[(cote + 1) % 4]
            var blancs = 0, total = 0
            for k in 1..<16 {
                let f = CGFloat(k) / 16
                let x = Int(centre.x + (debut.x + (fin.x - debut.x) * f) * a * echelle)
                let y = Int(centre.y + (debut.y + (fin.y - debut.y) * f) * a * echelle)
                guard x >= 0, y >= 0, x < image.width, y < image.height else { continue }
                total += 1
                guard estBlanc(image.rvb(x, y)) else { continue }
                // Le liseré de la case visée, voisine : bordé de rouge.
                let bordeDeRouge = [0.1, 0.2, 0.3].contains { k in
                    let dx = Int((CGFloat(x) - centre.x) * k), dy = Int((CGFloat(y) - centre.y) * k)
                    return [(x + dx, y + dy), (x - dx, y - dy)].contains { px, py in
                        px >= 0 && py >= 0 && px < image.width && py < image.height && estRouge(image.rvb(px, py))
                    }
                }
                if !bordeDeRouge { blancs += 1 }
            }
            return total > 0 ? Double(blancs) / Double(total) : 0
        }
    }

    /// Le score du contour blanc d'une case : le meilleur, à quelques échelles
    /// près du bord, du tout et des deux côtés du bas ; 0 si l'intérieur ou le
    /// pourtour sont blancs aussi — un bouton ou un texte de l'interface.
    static func contourBlanc(_ image: ImageRVB, centre: CGPoint, a: CGFloat) -> Double {
        var meilleur = 0.0
        for echelle in stride(from: 0.8, through: 1.0, by: 0.05) {
            let cotes = blancsParCote(image, centre: centre, a: a, echelle: CGFloat(echelle))
            meilleur = max(meilleur, cotes.reduce(0, +) / 4, (cotes[1] + cotes[2]) / 2)
        }
        guard meilleur > 0 else { return 0 }
        let dedans = blancsParCote(image, centre: centre, a: a, echelle: 0.55).reduce(0, +) / 4
        let autour = blancsParCote(image, centre: centre, a: a, echelle: 1.35).reduce(0, +) / 4
        return dedans > 0.25 || autour > 0.25 ? 0 : meilleur
    }

    private static func interieurRouge(_ image: ImageRVB, centre: CGPoint, a: CGFloat) -> Bool {
        var rouges = 0, total = 0
        for dy in stride(from: -0.2, through: 0.2, by: 0.1) {
            for dx in stride(from: -0.4, through: 0.4, by: 0.1) {
                let x = Int(centre.x + CGFloat(dx) * a), y = Int(centre.y + CGFloat(dy) * a)
                guard x >= 0, y >= 0, x < image.width, y < image.height else { continue }
                let p = image.rvb(x, y)
                total += 1
                if estRouge(p) { rouges += 1 }
            }
        }
        return total > 0 && Double(rouges) / Double(total) > 0.4
    }

    @inline(__always) static func estRouge(_ p: (r: Int, v: Int, b: Int)) -> Bool {
        p.r > p.v + 60 && p.r > p.b + 60
    }

    /// Clair et sans teinte : le beige des cases (bleu bas) et le bleu du mode
    /// tactique (rouge bas) n'en sont pas.
    @inline(__always) static func estBlanc(_ p: (r: Int, v: Int, b: Int)) -> Bool {
        min(p.r, p.v, p.b) >= 205 && max(p.r, p.v, p.b) - min(p.r, p.v, p.b) <= 35
    }
}
