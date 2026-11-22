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

    /// Le gabarit d'une flèche pointant dans `direction`, haute de `hauteur`
    /// pixels. Dessiné à l'est, puis tourné par quarts de tour (coordonnées
    /// écran, y vers le bas : un quart de tour horaire mène est → sud).
    static func gabarit(_ direction: Direction, hauteur: Int) -> LumaBitmap {
        let h = max(hauteur, 6)
        let w = max(Int(CGFloat(h) * 1.3), 8)
        var resultat = dessinerEst(largeur: w, hauteur: h)
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

    /// La direction de la flèche dessinée au début de la ligne `cadre` dans
    /// `image` — cherchée dans une marge à gauche du texte lu, là où le jeu la
    /// met. `texte` : début du texte de la ligne en x absolus (le cadre OCR peut
    /// contenir la flèche ou la coller à son bord) ; défaut : `cadre.minX`.
    /// `nil` : aucune direction ne colle assez.
    static func direction(dans image: LumaBitmap, ligne cadre: CGRect, texte: CGFloat? = nil) -> (direction: Direction, score: Double)? {
        let h = Int(cadre.height)
        guard h >= 8 else { return nil }
        // Région de recherche : de la gauche de la ligne jusqu'au début du texte,
        // et serrée verticalement sur la ligne : au-delà, ce sont les flèches
        // des lignes voisines.
        let debutTexte = texte ?? cadre.minX
        let marge = CGFloat(h) * 1.9
        let region = CGRect(x: min(cadre.minX, debutTexte) - marge, y: cadre.minY - CGFloat(h) * 0.3,
                            width: marge + (debutTexte - min(cadre.minX, debutTexte)) + min(cadre.width, CGFloat(h) * 0.5) + CGFloat(h) * 0.4,
                            height: cadre.height + CGFloat(h) * 0.6)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard region.width > 8, region.height > 8 else { return nil }
        guard let encre = binariser(image, dans: region) else { return nil }
        // `encre` est local à la région : ses coordonnées commencent à (0, 0).
        let rw = Int(region.width)

        var meilleur: (direction: Direction, score: Double)? = nil
        for direction in Direction.allCases {
            let gabarit = Self.gabarit(direction, hauteur: Int(cadre.height * 1.15))
            let gw = gabarit.width, gh = gabarit.height
            guard gw < rw, gh < Int(region.height) else { continue }
            let gabaritEncre = gabarit.pixels.map { $0 > 127 ? UInt8(1) : UInt8(0) }
            let totalGabarit = gabaritEncre.reduce(0) { $0 + Int($1) }
            guard totalGabarit > 4 else { continue }
            // La flèche se termine au début du texte lu : on ne cherche que là —
            // sinon les blocs du texte lui-même vaudraient une flèche.
            let localTexte = debutTexte - region.minX
            let pxMax = Int(localTexte + CGFloat(h) * 0.25) - gw
            guard pxMax >= 0 else { continue }
            var meilleurLocal = 0.0
            // Pas de 2 px : la région est petite, la précision du centrage n'y change rien.
            for py in stride(from: 0, to: Int(region.height) - gh, by: 2) {
                for px in stride(from: 0, to: pxMax, by: 2) {
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
            if meilleurLocal >= (meilleur?.score ?? 0) {
                meilleur = (direction, meilleurLocal)
            }
        }
        guard let meilleur, meilleur.score >= Self.seuil else { return nil }
        return meilleur
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
