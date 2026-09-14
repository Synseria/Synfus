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
        /// Les rangées, de haut en bas ; dans chacune, les cases de gauche à
        /// droite, en pixels de l'image. Le jeu en affiche jusqu'à trois —
        /// une par barre de sorts.
        let rows: [[CGRect]]
        /// Pas entre deux cases (côté + interstice), le même dans les deux sens.
        let pitch: Int
        /// Côté d'une case.
        let side: Int

        /// Toutes les cases, rangée par rangée.
        var cells: [CGRect] { rows.flatMap { $0 } }

        /// La zone couvrant la barre, en fractions de l'image — ce que l'on
        /// mémorise pour ne capturer que cette bande la fois suivante.
        func region(in imageSize: CGSize, margin: CGFloat = 0.5) -> CGRect {
            guard let first = rows.first?.first, let last = rows.last?.last else { return .zero }
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

    /// Hauteur des bandes horizontales balayées pour trouver les colonnes,
    /// et tolérance de position d'un bord, en pixels.
    static let stripHeight = 16
    static let tolerance = 3
    /// Interstice minimal entre deux cases.
    static let minGap = 3

    /// La signature retenue : sur une bande horizontale, les bords verticaux
    /// forment des **pics**, et une rangée de cases est une suite de pics
    /// « gauche, droite, gauche, droite… » au même pas — un réseau. Les
    /// positions des pics sont entières, le pas ne l'est pas forcément : il
    /// est estimé en fraction et chaque case est cherchée à sa place, à
    /// `tolerance` près, sans accumuler de dérive.
    static func locate(in image: LumaBitmap) -> Bar? {
        guard image.width > minCell * minCells, image.height > minCell * 2 else { return nil }
        let bandTop = Int(CGFloat(image.height) * (1 - searchBand))

        // 1. Les colonnes : le réseau qui couvre le plus de cases, toutes
        //    bandes confondues.
        var best: (lattice: Lattice, y: Int)?
        var y = bandTop
        while y + stripHeight <= image.height {
            let columns = columnEdgeProfile(image, rows: y..<(y + stripHeight))
            if let lattice = bestLattice(peaks: peaks(of: columns)), lattice.isBetter(than: best?.lattice) {
                best = (lattice, y)
            }
            y += stripHeight / 2
        }
        guard let (lattice, stripY) = best else { return nil }
        let side = lattice.side
        let xs = lattice.lefts

        // 2. Les lignes, sur la seule largeur des cases : le même réseau, à la
        //    verticale — haut, bas, haut, bas… au même pas. Une rangée doit
        //    contenir la bande où les colonnes ont été trouvées ; et seuls les
        //    bords nets comptent — le décor du jeu fait des pics partout, et un
        //    réseau tolérant y trouverait toujours son compte.
        let columns = xs[0]..<min(image.width, xs[xs.count - 1] + side)
        let rows = rowEdgeProfile(image, from: bandTop, columns: columns)
        let strongest = rows.max() ?? 1
        let rowPeaks = peaks(of: rows).filter { $0.value * 4 >= strongest }.map { ($0.x + bandTop, $0.value) }
        guard let vertical = bestLattice(peaks: rowPeaks, side: side, pitch: lattice.pitch, minCount: 1,
                                         containing: stripY + stripHeight / 2)
        else { return nil }
        let cells = vertical.lefts.map { top in
            xs.map { x in CGRect(x: x, y: top, width: side, height: vertical.side) }
        }
        return Bar(rows: cells, pitch: Int(lattice.pitch.rounded()), side: side)
    }

    /// Un réseau de cases sur un profil : bords gauches (ou hauts), côté, pas
    /// fractionnaire, et force cumulée des bords.
    struct Lattice: Equatable {
        let lefts: [Int]
        let side: Int
        let pitch: Double
        let strength: Int

        var count: Int { lefts.count }

        func isBetter(than other: Lattice?) -> Bool {
            guard let other else { return true }
            return (count, strength) > (other.count, other.strength)
        }
    }

    /// Les maxima locaux d'un profil, les `limit` plus forts.
    static func peaks(of profile: [Int], limit: Int = 120) -> [(x: Int, value: Int)] {
        guard profile.count > 2 else { return [] }
        var maxima: [(x: Int, value: Int)] = []
        for x in 1..<(profile.count - 1)
        where profile[x] > 0 && profile[x] >= profile[x - 1] && profile[x] > profile[x + 1] {
            maxima.append((x, profile[x]))
        }
        return Array(maxima.sorted { $0.value > $1.value }.prefix(limit)).sorted { $0.x < $1.x }
    }

    /// Le réseau qui couvre le plus de pics. Chaque paire de pics est essayée
    /// comme (gauche, droite) d'une première case ; le pas est la distance au
    /// pic suivant qui ressemble à un bord gauche ; puis on avance case par
    /// case tant que les deux bords tombent sur un pic — en réestimant le pas
    /// sur la distance parcourue, pour qu'un pas de 83,4 ne dérive pas.
    ///
    /// Avec `side` et `pitch` imposés (la recherche verticale), seules la
    /// position et le nombre de rangées restent à trouver.
    static func bestLattice(peaks: [(x: Int, value: Int)], side fixedSide: Int? = nil,
                            pitch fixedPitch: Double? = nil, minCount: Int = minCells,
                            containing anchor: Int? = nil) -> Lattice? {
        guard peaks.count >= 2 else { return nil }
        let xs = peaks.map(\.x)
        func peak(near x: Double) -> Int? {
            let target = Int(x.rounded())
            var lo = 0, hi = xs.count - 1
            while lo < hi { let mid = (lo + hi) / 2; if xs[mid] < target { lo = mid + 1 } else { hi = mid } }
            var bestIndex: Int?
            for i in [lo - 1, lo, lo + 1] where i >= 0 && i < xs.count && abs(xs[i] - target) <= tolerance {
                if bestIndex == nil || abs(xs[i] - target) < abs(xs[bestIndex!] - target) { bestIndex = i }
            }
            return bestIndex
        }
        var best: Lattice?
        for i in 0..<(peaks.count - 1) {
            let sides: [Int]
            if let fixedSide { sides = [fixedSide] } else {
                sides = ((i + 1)..<min(peaks.count, i + 6)).map { xs[$0] - xs[i] }.filter { $0 >= minCell && $0 <= maxCell }
            }
            for side in sides {
                guard peak(near: Double(xs[i] + side)) != nil else { continue }
                let pitches: [Double]
                if let fixedPitch { pitches = [fixedPitch] } else {
                    pitches = ((i + 1)..<min(peaks.count, i + 8)).map { Double(xs[$0] - xs[i]) }
                        // Un interstice d'au moins `minGap` : des lettres qui se
                        // touchent font aussi un réseau, ce n'en est pas un.
                        .filter { $0 >= Double(side + minGap) && $0 <= Double(side) * 1.5 }
                }
                for initialPitch in pitches {
                    var pitch = initialPitch
                    var lefts = [xs[i]]
                    var strength = peaks[i].value + (peak(near: Double(xs[i] + side)).map { peaks[$0].value } ?? 0)
                    while true {
                        let expected = Double(xs[i]) + Double(lefts.count) * pitch
                        guard let l = peak(near: expected), let r = peak(near: expected + Double(side)) else { break }
                        lefts.append(xs[l])
                        strength += peaks[l].value + peaks[r].value
                        // Le pas mesuré sur toute la suite, plus juste que le premier.
                        pitch = Double(xs[l] - xs[i]) / Double(lefts.count - 1)
                    }
                    let lattice = Lattice(lefts: lefts, side: side, pitch: pitch, strength: strength)
                    if let anchor, !lefts.contains(where: { $0 <= anchor && anchor <= $0 + side }) { continue }
                    if lattice.count >= minCount, lattice.isBetter(than: best) { best = lattice }
                }
            }
        }
        return best
    }

    // MARK: - Profils

    /// Somme, par ligne, des différences verticales de luminance — fort sur
    /// une ligne horizontale de cadre.
    static func rowEdgeProfile(_ image: LumaBitmap, from firstRow: Int, columns: Range<Int>? = nil) -> [Int] {
        let xs = (columns ?? 0..<image.width).clamped(to: 0..<image.width)
        var profile = [Int](repeating: 0, count: image.height - firstRow)
        for y in firstRow..<(image.height - 1) {
            var sum = 0
            for x in xs {
                sum += abs(Int(image[x, y + 1]) - Int(image[x, y]))
            }
            profile[y - firstRow] = sum
        }
        return profile
    }

    /// Somme, par colonne, des différences horizontales de luminance sur les
    /// lignes données — fort sur un bord vertical de case.
    static func columnEdgeProfile(_ image: LumaBitmap, rows: ClosedRange<Int>) -> [Int] {
        columnEdgeProfile(image, rows: Range(rows))
    }

    static func columnEdgeProfile(_ image: LumaBitmap, rows: Range<Int>) -> [Int] {
        var profile = [Int](repeating: 0, count: image.width)
        for y in rows where y < image.height {
            for x in 0..<(image.width - 1) {
                profile[x] += abs(Int(image[x + 1, y]) - Int(image[x, y]))
            }
        }
        return profile
    }

    /// Les paires de lignes marquées à une distance plausible l'une de
    /// l'autre, les plus fortes d'abord. Chaque ligne n'entre que dans sa
    /// meilleure paire : sinon les quarante premières seraient quarante
    /// variantes de la même. La seconde est cherchée après la première : le
    /// bas d'une case est sous son haut.
    static func strongestPairs(_ profile: [Int], offset: Int, minGap: Int, maxGap: Int, limit: Int = 40) -> [(Int, Int)] {
        guard profile.count > minGap else { return [] }
        // Les lignes candidates : maxima locaux du profil.
        let lines = (1..<(profile.count - 1)).filter { profile[$0] >= profile[$0 - 1] && profile[$0] > profile[$0 + 1] && profile[$0] > 0 }
        var pairs: [(score: Int, top: Int, bottom: Int)] = []
        for top in lines {
            var bestBottom: (score: Int, y: Int)?
            for bottom in lines where bottom >= top + minGap && bottom <= top + maxGap {
                let score = profile[top] + profile[bottom]
                if bestBottom == nil || score > bestBottom!.score { bestBottom = (score, bottom) }
            }
            if let bestBottom { pairs.append((bestBottom.score, top, bestBottom.y)) }
        }
        return pairs.sorted { $0.score > $1.score }.prefix(limit).map { ($0.top + offset, $0.bottom + offset) }
    }

    /// La paire la plus marquée seule — pour les tests des profils.
    static func strongestPair(_ profile: [Int], offset: Int, minGap: Int, maxGap: Int) -> (Int, Int)? {
        strongestPairs(profile, offset: offset, minGap: minGap, maxGap: maxGap, limit: 1).first
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
        guard (columns.max() ?? 0) > 0 else { return [] }
        var scores: [Double] = []
        var x = offset
        while x + side < columns.count {
            // Un bord peut tomber à un pixel près : on prend le meilleur voisin.
            let left = (max(0, x - 1)...min(columns.count - 1, x + 1)).map { columns[$0] }.max() ?? 0
            let right = (max(0, x + side - 1)...min(columns.count - 1, x + side + 1)).map { columns[$0] }.max() ?? 0
            // Rapporté au maximum **local** — deux pas de part et d'autre — :
            // un panneau plus contrasté ailleurs sur la ligne n'écrase pas la
            // rangée, et une case se juge par rapport à ses voisines.
            let window = max(0, x - 2 * pitch)...min(columns.count - 1, x + side + 2 * pitch)
            let peak = Double(columns[window].max() ?? 1)
            scores.append(peak > 0 ? Double(left + right) / (2 * peak) : 0)
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
