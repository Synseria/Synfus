import CoreGraphics
import Foundation

/// Retrouve la barre de sorts dans une capture de fenêtre : une rangée de
/// cases carrées, de même taille, régulièrement espacées, dans le bandeau
/// bas. Pure — une image entre, des cadres sortent —, donc testable sur des
/// images fabriquées.
///
/// La méthode est géométrique et non des coordonnées figées : la fenêtre
/// change de taille, l'échelle d'interface aussi, et le jeu se met à jour.
/// Les cases ont un cadre, c'est-à-dire des **bords** — verticaux à gauche et
/// à droite de chaque case, horizontaux en haut et en bas —, et ces bords se
/// répètent au pas d'une case. C'est cette périodicité qu'on cherche.
///
/// Hypothèses, à confronter aux captures réelles avant de s'y fier :
/// - la barre est dans le tiers inférieur de la fenêtre (`searchBand`) ;
/// - une case fait entre `minCell` et `maxCell` pixels de côté ;
/// - au moins `minCells` cases se suivent au même pas.
enum SpellBarLocator {

    struct Bar: Equatable, Sendable {
        /// Cadres des cases, de gauche à droite, en pixels de l'image.
        let cells: [CGRect]
        /// Pas entre deux cases (côté + interstice).
        let pitch: Int
        /// Côté d'une case.
        let side: Int

        /// La zone couvrant la barre, en fractions de l'image — ce que l'on
        /// mémorise pour ne capturer que cette bande la fois suivante.
        func region(in imageSize: CGSize, margin: CGFloat = 0.5) -> CGRect {
            guard let first = cells.first, let last = cells.last else { return .zero }
            let box = first.union(last).insetBy(dx: -CGFloat(side) * margin, dy: -CGFloat(side) * margin)
            return CGRect(x: box.minX / imageSize.width, y: box.minY / imageSize.height,
                          width: box.width / imageSize.width, height: box.height / imageSize.height)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    /// Part de la hauteur, depuis le bas, où chercher la barre.
    static let searchBand: CGFloat = 0.35
    static let minCell = 24
    static let maxCell = 160
    static let minCells = 4

    static func locate(in image: LumaBitmap) -> Bar? {
        guard image.width > minCell * minCells, image.height > minCell * 2 else { return nil }
        let bandTop = Int(CGFloat(image.height) * (1 - searchBand))

        // 1. Profil des bords horizontaux par ligne, sur la bande : les deux
        //    lignes les plus marquées à une distance de case l'une de l'autre
        //    sont le haut et le bas des cases.
        let rows = rowEdgeProfile(image, from: bandTop)
        guard let (top, bottom) = strongestPair(rows, offset: bandTop,
                                                minGap: minCell, maxGap: min(maxCell, image.height - bandTop - 1))
        else { return nil }
        let side = bottom - top

        // 2. Profil des bords verticaux par colonne, sur les seules lignes des
        //    cases, puis son pas dominant par autocorrélation : le pas d'une case.
        let columns = columnEdgeProfile(image, rows: top...bottom)
        guard let pitch = dominantPeriod(columns, minLag: side, maxLag: side * 2) else { return nil }

        // 3. Phase : l'offset qui aligne le mieux des bords gauche **et** droit
        //    à chaque pas ; puis la plus longue suite de cases qui tiennent.
        let scores = (0..<pitch).map { offset in cellScores(columns, offset: offset, pitch: pitch, side: side) }
        guard let (offset, run) = bestRun(scores) else { return nil }
        let cells = run.map { k in
            CGRect(x: offset + k * pitch, y: top, width: side, height: side)
        }
        return Bar(cells: cells, pitch: pitch, side: side)
    }

    // MARK: - Profils

    /// Somme, par ligne, des différences verticales de luminance — fort sur
    /// une ligne horizontale de cadre.
    static func rowEdgeProfile(_ image: LumaBitmap, from firstRow: Int) -> [Int] {
        var profile = [Int](repeating: 0, count: image.height - firstRow)
        for y in firstRow..<(image.height - 1) {
            var sum = 0
            for x in 0..<image.width {
                sum += abs(Int(image[x, y + 1]) - Int(image[x, y]))
            }
            profile[y - firstRow] = sum
        }
        return profile
    }

    /// Somme, par colonne, des différences horizontales de luminance sur les
    /// lignes données — fort sur un bord vertical de case.
    static func columnEdgeProfile(_ image: LumaBitmap, rows: ClosedRange<Int>) -> [Int] {
        var profile = [Int](repeating: 0, count: image.width)
        for y in rows where y < image.height {
            for x in 0..<(image.width - 1) {
                profile[x] += abs(Int(image[x + 1, y]) - Int(image[x, y]))
            }
        }
        return profile
    }

    /// Les deux lignes les plus marquées à une distance plausible l'une de
    /// l'autre. La seconde est cherchée après la première : le bas d'une case
    /// est sous son haut.
    static func strongestPair(_ profile: [Int], offset: Int, minGap: Int, maxGap: Int) -> (Int, Int)? {
        guard profile.count > minGap else { return nil }
        var best: (score: Int, top: Int, bottom: Int)?
        for top in 0..<(profile.count - minGap) {
            for bottom in (top + minGap)...min(top + maxGap, profile.count - 1) {
                let score = profile[top] + profile[bottom]
                if best == nil || score > best!.score { best = (score, top, bottom) }
            }
        }
        guard let best, best.score > 0 else { return nil }
        return (best.top + offset, best.bottom + offset)
    }

    /// Le décalage pour lequel le profil se ressemble le plus à lui-même.
    static func dominantPeriod(_ profile: [Int], minLag: Int, maxLag: Int) -> Int? {
        guard profile.count > maxLag * 2, minLag >= 1, maxLag >= minLag else { return nil }
        let mean = Double(profile.reduce(0, +)) / Double(profile.count)
        let centered = profile.map { Double($0) - mean }
        var best: (lag: Int, value: Double)?
        for lag in minLag...maxLag {
            var sum = 0.0
            for i in 0..<(centered.count - lag) { sum += centered[i] * centered[i + lag] }
            let value = sum / Double(centered.count - lag)
            if best == nil || value > best!.value { best = (lag, value) }
        }
        guard let best, best.value > 0 else { return nil }
        return best.lag
    }

    /// Pour chaque case possible à cet offset, la force cumulée de ses bords
    /// gauche et droit, rapportée au maximum du profil.
    static func cellScores(_ columns: [Int], offset: Int, pitch: Int, side: Int) -> [Double] {
        let peak = Double(columns.max() ?? 1)
        guard peak > 0 else { return [] }
        var scores: [Double] = []
        var x = offset
        while x + side < columns.count {
            // Un bord peut tomber à un pixel près : on prend le meilleur voisin.
            let left = (max(0, x - 1)...min(columns.count - 1, x + 1)).map { columns[$0] }.max() ?? 0
            let right = (max(0, x + side - 1)...min(columns.count - 1, x + side + 1)).map { columns[$0] }.max() ?? 0
            scores.append(Double(left + right) / (2 * peak))
            x += pitch
        }
        return scores
    }

    /// L'offset et la plus longue suite de cases au-dessus du seuil.
    static func bestRun(_ scoresByOffset: [[Double]], threshold: Double = 0.45) -> (Int, Range<Int>)? {
        var best: (offset: Int, run: Range<Int>, strength: Double)?
        for (offset, scores) in scoresByOffset.enumerated() {
            var start = 0
            while start < scores.count {
                guard scores[start] >= threshold else { start += 1; continue }
                var end = start
                while end < scores.count, scores[end] >= threshold { end += 1 }
                let strength = scores[start..<end].reduce(0, +)
                if end - start >= minCells,
                   best == nil || (end - start, strength) > (best!.run.count, best!.strength) {
                    best = (offset, start..<end, strength)
                }
                start = end
            }
        }
        guard let best else { return nil }
        return (best.offset, best.run)
    }
}
