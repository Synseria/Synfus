import CoreGraphics

/// La flèche de direction qu'une ligne du suivi de chasse porte à son début,
/// cherchée **en pixels** quand l'OCR n'a pas reconnu le glyphe (Vision écorche
/// la flèche en triangle plein). Des gabarits dessinés (tige + tête), comparés
/// à l'image lue par le coefficient de Dice sur les pixels d'encre — une
/// reconnaissance de forme, pas de texte. Pur : bitmap en entrée, testable sans
/// écran.
enum DetectionFleche {
    /// Au-delà, le meilleur gabarit est retenu comme la direction de la ligne.
    static let seuil = 0.6

    /// La meilleure correspondance trouvée : direction et score de Dice.
    struct Correspondance: Equatable, Sendable {
        let direction: Direction
        let score: Double
    }

    /// Le gabarit d'une flèche pointant dans `direction`, haute de `hauteur`
    /// pixels. Dessiné à l'est, puis tourné par quarts de tour (coordonnées
    /// écran, y vers le bas : un quart de tour horaire mène est → sud).
    /// `contour` : seulement le bord de la flèche — le jeu la dessine creuse.
    static func gabarit(_ direction: Direction, hauteur: Int, contour: Bool = false) -> LumaBitmap {
        let h = max(hauteur, 6)
        let w = max(Int(CGFloat(h) * 1.3), 8)
        var resultat = dessinerEst(largeur: w, hauteur: h)
        if contour { resultat = contourDe(resultat) }
        let tours: Int
        switch direction {
        case .est: tours = 0
        case .sud: tours = 1
        case .ouest: tours = 2
        case .nord: tours = 3
        }
        for _ in 0..<tours { resultat = tourneHoraire(resultat) }
        return resultat
    }

    /// Le contour d'une forme pleine : les pixels pleins qui touchent le vide.
    private static func contourDe(_ image: LumaBitmap) -> LumaBitmap {
        let (w, h) = (image.width, image.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                guard image[x, y] > 127 else { continue }
                let vide = (x == 0 || image[x - 1, y] <= 127) || (x == w - 1 || image[x + 1, y] <= 127)
                    || (y == 0 || image[x, y - 1] <= 127) || (y == h - 1 || image[x, y + 1] <= 127)
                if vide { pixels[y * w + x] = 255 }
            }
        }
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    /// La direction de la flèche dessinée au début de la ligne `cadre` dans
    /// `image` — cherchée dans une marge à gauche du texte lu, là où le jeu la
    /// met. `texte` : début du texte de la ligne en x absolus (le cadre OCR peut
    /// contenir la flèche ou la coller à son bord) ; défaut : `cadre.minX`.
    /// `nil` : aucune direction ne colle assez.
    static func direction(dans image: LumaBitmap, ligne cadre: CGRect, texte: CGFloat? = nil) -> Correspondance? {
        // Deux lectures de la même flèche, combinées : les gabarits (Dice sur
        // l'encre binarisée) et la conicité (l'apex de la tête est le côté le
        // moins chargé du plus gros bloc d'encre à gauche de la ligne).
        var parDirection = scoresParGabarits(dans: image, ligne: cadre, texte: texte)
        if let c = directionConicite(image, ligne: cadre) {
            parDirection[c.direction] = max(parDirection[c.direction] ?? 0, c.score)
        }
        guard let meilleur = parDirection.max(by: { $0.value < $1.value }), meilleur.value >= Self.seuil else { return nil }
        return Correspondance(direction: meilleur.key, score: meilleur.value)
    }

    /// La direction par conicité : la flèche du jeu est un triangle blanc à
    /// liseré noir — seuil haut pour ne garder que le blanc plein. L'apex
    /// (la pointe) est le côté du blob le moins chargé en encre.
    static func directionConicite(_ image: LumaBitmap, ligne cadre: CGRect) -> Correspondance? {
        let h = Int(cadre.height)
        guard h >= 8 else { return nil }
        let region = CGRect(x: cadre.minX, y: cadre.minY - CGFloat(h) * 0.3,
                            width: min(cadre.width, CGFloat(h) * 2.5),
                            height: cadre.height + CGFloat(h) * 0.6)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard region.width > 8, region.height > 8 else { return nil }
        // binarisation "blanc pur" : seuil à 80 % de la plage
        let x0 = Int(region.minX), y0 = Int(region.minY)
        let rw = Int(region.width), rh = Int(region.height)
        var mn = UInt8.max, mx = UInt8(0)
        for y in y0..<(y0 + rh) { for x in x0..<(x0 + rw) {
            let v = image[x, y]; if v < mn { mn = v }; if v > mx { mx = v }
        } }
        guard Int(mx) - Int(mn) >= 40 else { return nil }
        let seuilBlanc = Int(mn) + (Int(mx) - Int(mn)) * 8 / 10
        func encre(_ x: Int, _ y: Int) -> Int { Int(image[x0 + x, y0 + y]) >= seuilBlanc ? 1 : 0 }
        // colonnes d'encre, hors colonnes pleines (bordure du panneau)
        var cols = [Int](repeating: 0, count: rw)
        for x in 0..<rw { for y in 0..<rh { cols[x] += encre(x, y) } }
        let xs = (0..<rw).filter { cols[$0] > 0 && cols[$0] <= rh * 4 / 5 }
        guard !xs.isEmpty else { return nil }
        // clusters séparés par un blanc d'au moins 3 colonnes ; la flèche est le
        // premier cluster assez gros, hors bordure (x < 6)
        var clusters: [(x0: Int, x1: Int, aire: Int)] = []
        var c0 = xs[0], c1 = xs[0], aire = cols[xs[0]]
        for x in xs.dropFirst() {
            if x - c1 <= 3 { c1 = x; aire += cols[x] } else { clusters.append((c0, c1, aire)); c0 = x; c1 = x; aire = cols[x] }
        }
        clusters.append((c0, c1, aire))
        // la flèche : un cluster en forme de triangle (taux de remplissage d'une
        // tête pleine, largeur ≈ hauteur) — pas une lettre ni un bloc de texte
        func enFormeDeTete(_ c: (x0: Int, x1: Int, aire: Int)) -> Bool {
            let w = c.x1 - c.x0 + 1
            var hmax = 0
            for x in c.x0...c.x1 {
                var y0 = rh, y1 = -1
                for y in 0..<rh { if encre(x, y) == 1 { if y < y0 { y0 = y }; if y > y1 { y1 = y } } }
                if y1 >= y0 { hmax = max(hmax, y1 - y0 + 1) }
            }
            guard hmax >= 6, w >= 6 else { return false }
            let ratio = Double(w) / Double(hmax)
            let remplissage = Double(c.aire) / Double(w * hmax)
            return ratio >= 0.55 && ratio <= 1.9 && remplissage >= 0.3 && remplissage <= 0.95
        }
        guard let cluster = clusters.first(where: { $0.x0 >= 6 && enFormeDeTete($0) }) else { return nil }
        let (bx0, bx1) = (cluster.x0, cluster.x1)
        func masse(_ xa: Int, _ xb: Int, _ ya: Int, _ yb: Int) -> Int {
            var m = 0
            for x in xa...xb { for y in ya...yb { m += encre(x, y) } }
            return m
        }
        let total = masse(bx0, bx1, 0, rh - 1)
        guard total > 20 else { return nil }
        // hauteur du blob pour classer horizontal/vertical
        var hmax = 0
        for x in bx0...bx1 { var y0 = rh, y1 = -1; for y in 0..<rh { if encre(x, y) == 1 { if y < y0 { y0 = y }; if y > y1 { y1 = y } } }; if y1 >= y0 { hmax = max(hmax, y1 - y0 + 1) } }
        let w = bx1 - bx0 + 1
        let quart = max(1, w / 4)
        let quartHaut = max(1, rh / 4)
        var direction: Direction, score: Double
        if w >= hmax {
            let gauche = masse(bx0, bx0 + quart - 1, 0, rh - 1)
            let droite = masse(bx1 - quart + 1, bx1, 0, rh - 1)
            if gauche <= droite { direction = .ouest; score = Double(droite - gauche) / Double(total) }
            else { direction = .est; score = Double(gauche - droite) / Double(total) }
        } else {
            let haut = masse(bx0, bx1, 0, quartHaut - 1)
            let bas = masse(bx0, bx1, rh - quartHaut, rh - 1)
            if haut <= bas { direction = .nord; score = Double(bas - haut) / Double(total) }
            else { direction = .sud; score = Double(haut - bas) / Double(total) }
        }
        guard score > 0.05 else { return nil }
        return Correspondance(direction: direction, score: min(1, 0.4 + 2 * score))
    }

    /// Le meilleur score de chaque direction sur une ligne, toutes variantes
    /// confondues — pour le diagnostic (« que dit l'analyse »).
    static func scoresParGabarits(dans image: LumaBitmap, ligne cadre: CGRect, texte: CGFloat? = nil) -> [Direction: Double] {
        let h = Int(cadre.height)
        guard h >= 8 else { return [:] }
        let debutTexte = texte ?? cadre.minX
        let marge = CGFloat(h) * 1.9
        let region = CGRect(x: min(cadre.minX, debutTexte) - marge, y: cadre.minY - CGFloat(h) * 0.3,
                            width: marge + (debutTexte - min(cadre.minX, debutTexte)) + min(cadre.width, CGFloat(h) * 0.5) + CGFloat(h) * 0.4,
                            height: cadre.height + CGFloat(h) * 0.6)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard region.width > 8, region.height > 8, let encre = binariser(image, dans: region) else { return [:] }
        let rw = Int(region.width)
        var parDirection: [Direction: Double] = [:]
        for facteur in [1.15, 0.85, 0.6] {
            for contour in [false, true] {
                for direction in Direction.allCases {
                    let gabarit = Self.gabarit(direction, hauteur: Int(CGFloat(cadre.height) * facteur), contour: contour)
                    let gw = gabarit.width, gh = gabarit.height
                    guard gw < rw, gh < Int(region.height) else { continue }
                    let gabaritEncre = gabarit.pixels.map { $0 > 127 ? UInt8(1) : UInt8(0) }
                    let totalGabarit = gabaritEncre.reduce(0) { $0 + Int($1) }
                    guard totalGabarit > 4 else { continue }
                    let localTexte = debutTexte - region.minX
                    let pxMax = min(rw - gw, Int(max(localTexte, CGFloat(gw) * 1.5) + CGFloat(h) * 0.25) - gw)
                    guard pxMax >= 0 else { continue }
                    var meilleurLocal = 0.0
                    for py in stride(from: 0, to: Int(region.height) - gh, by: 1) {
                        for px in stride(from: 0, to: pxMax, by: 1) {
                            var intersection = 0, encreZone = 0
                            for gy in 0..<gh {
                                let ligneZone = (py + gy) * rw
                                let ligneGabarit = gy * gw
                                for gx in 0..<gw {
                                    let zone = encre[ligneZone + px + gx]
                                    let g = gabaritEncre[ligneGabarit + gx]
                                    if g == 1 { if zone == 1 { intersection += 1 } }
                                    if zone == 1 { encreZone += 1 }
                                }
                            }
                            let dice = Double(2 * intersection) / Double(totalGabarit + encreZone)
                            if dice > meilleurLocal { meilleurLocal = dice }
                        }
                    }
                    if meilleurLocal > (parDirection[direction] ?? 0) { parDirection[direction] = meilleurLocal }
                }
            }
        }
        return parDirection
    }

    /// Le détail de la détection sur une ligne : le glyphe lu par l'OCR dans le
    /// texte, et la meilleure correspondance en pixels (direction + score) —
    /// pour dire à l'utilisateur ce que le scan a vu.
    static func detail(dans ligne: String, cadre: CGRect, image: LumaBitmap?, texte: CGFloat? = nil) -> (glyphe: Direction?, pixel: Correspondance?) {
        let glyphe = Direction(ligneLue: ligne)
        let pixel = image.flatMap { Self.direction(dans: $0, ligne: cadre, texte: texte) }
        return (glyphe, pixel)
    }

    /// L'image de `region` binarisée (1 = encre) ; `nil` si la région est plate
    /// (pas de texte, pas de flèche). Le seuil s'adapte : texte clair sur fond
    /// sombre ou l'inverse, les deux se lisent.
    private static func binariser(_ image: LumaBitmap, dans region: CGRect) -> [UInt8]? {
        let x0 = Int(region.minX), y0 = Int(region.minY)
        let w = Int(region.width), h = Int(region.height)
        var min = UInt8.max, max = UInt8(0)
        for y in y0..<(y0 + h) {
            for x in x0..<(x0 + w) {
                let v = image[x, y]
                if v < min { min = v }
                if v > max { max = v }
            }
        }
        guard Int(max) - Int(min) >= 40 else { return nil }
        // 45 % de la plage : au milieu de l'anticrénelage (calcul en Int : en UInt8, × 9 déborde).
        let seuil = Int(min) + (Int(max) - Int(min)) * 9 / 20
        var binaire = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                binaire[y * w + x] = Int(image[x0 + x, y0 + y]) >= seuil ? 1 : 0
            }
        }
        return binaire
    }

    /// Le gabarit de la flèche est : tige horizontale et tête triangulaire, encre blanche.
    private static func dessinerEst(largeur w: Int, hauteur h: Int) -> LumaBitmap {
        var pixels = [UInt8](repeating: 0, count: w * h)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let contexte = CGContext(data: buffer.baseAddress, width: w, height: h,
                                           bitsPerComponent: 8, bytesPerRow: w,
                                           space: CGColorSpaceCreateDeviceGray(),
                                           bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            contexte.setFillColor(CGColor(gray: 1, alpha: 1))
            let e = max(2, h / 5)
            let tete = max(w / 3, 4)
            contexte.fill(CGRect(x: 0, y: (h - e) / 2, width: w - tete, height: e))
            let chemin = CGMutablePath()
            chemin.move(to: CGPoint(x: w - tete, y: h / 5))
            chemin.addLine(to: CGPoint(x: w - 1, y: h / 2))
            chemin.addLine(to: CGPoint(x: w - tete, y: h - h / 5))
            chemin.closeSubpath()
            contexte.addPath(chemin)
            contexte.fillPath()
            return true
        }
        precondition(ok)
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    /// Un quart de tour horaire (y vers le bas) : est devient sud.
    private static func tourneHoraire(_ image: LumaBitmap) -> LumaBitmap {
        let (w, h) = (image.width, image.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                pixels[x * h + (h - 1 - y)] = image[x, y]
            }
        }
        return LumaBitmap(width: h, height: w, pixels: pixels)
    }
}
