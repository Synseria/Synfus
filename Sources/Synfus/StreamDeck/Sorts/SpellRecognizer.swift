import CoreGraphics
import Foundation

/// L'index `sorts.json` écrit par `Tools/fetch-ankama-assets.sh` : les sorts
/// connus, par classe, et où est leur icône.
struct SpellIndex: Sendable {
    struct Entry: Codable, Sendable, Equatable {
        let id: Int
        let nom: String
        let classe: String
        let fichier: String
    }

    let entries: [Entry]
    private let byID: [Int: Entry]

    init(entries: [Entry]) {
        self.entries = entries
        byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func load() -> SpellIndex? {
        guard let url = AnkamaAssets.spellIndexURL,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return nil }
        return SpellIndex(entries: entries)
    }

    /// L'index lu une fois — `reload()` après un nouveau téléchargement.
    @MainActor private(set) static var shared: SpellIndex? = load()
    @MainActor static func reload() { shared = load() }

    /// La clé des sorts communs à toutes les classes, telle que le script l'écrit.
    static let commonKey = "communs"

    /// Les sorts d'une classe **et** les communs : une barre porte les deux.
    func entries(forClass key: String) -> [Entry] {
        entries.filter { $0.classe == key || $0.classe == Self.commonKey }
    }

    func entry(id: Int) -> Entry? { byID[id] }

    /// L'icône d'un sort, par identifiant.
    func iconURL(id: Int) -> URL? {
        entry(id: id).flatMap { AnkamaAssets.spellIconURL(fichier: $0.fichier) }
    }
}

/// Reconnaît le sort d'une case par comparaison d'imagettes — la case
/// recadrée contre les icônes des sorts **de la classe du perso** : vingt à
/// trente candidats, pas cinq cents. Pure et testable ; ce qu'elle vaut sur
/// des captures réelles se mesure dans le Diagnostic.
///
/// Le comparateur est une corrélation normalisée sur `side × side` pixels de
/// luminance : insensible à la luminosité globale et au contraste — un sort
/// grisé (PA insuffisants) reste le même dessin, plus sombre —, sensible à la
/// forme. La marge entre le meilleur candidat et le second est ce qui dit si
/// l'on peut se fier au résultat.
enum SpellRecognizer {

    /// Une icône connue, réduite une fois pour toutes.
    struct Candidate: Sendable, Equatable {
        let id: Int
        let nom: String
        let thumb: LumaBitmap
    }

    struct Match: Sendable, Equatable {
        let id: Int
        let nom: String
        /// Corrélation avec le meilleur candidat, dans [-1, 1].
        let score: Double
        /// Corrélation du second — la marge `score - runnerUp` est la confiance.
        let runnerUp: Double
        var margin: Double { score - runnerUp }
        /// Suffisamment net pour être retenu sans confirmation.
        var isConfident: Bool { score >= SpellRecognizer.minScore && margin >= SpellRecognizer.minMargin }
    }

    /// Côté des imagettes comparées. Assez petit pour être rapide, assez
    /// grand pour que deux sorts de la même classe se distinguent.
    static let side = 40
    static let minScore = 0.7
    static let minMargin = 0.12
    /// Part rognée de chaque bord, **des deux côtés** — la case du jeu comme
    /// l'icône de référence. Le cadre et le fond sont les mêmes pour tous les
    /// sorts d'une classe : les garder, c'était comparer des cadres. Mesuré
    /// sur une capture réelle : sans rognage, 0,7 de score et 0,1 de marge ;
    /// le picto seul creuse l'écart.
    static let inset: CGFloat = 0.22

    static func candidate(id: Int, nom: String, icon: LumaBitmap) -> Candidate {
        Candidate(id: id, nom: nom, thumb: thumbnail(ofCell: icon))
    }

    /// Le centre de la case, réduit — le même traitement pour la case du jeu
    /// et pour l'icône de référence.
    static func thumbnail(ofCell cell: LumaBitmap) -> LumaBitmap {
        let dx = CGFloat(cell.width) * inset, dy = CGFloat(cell.height) * inset
        return cell.cropped(to: CGRect(x: dx, y: dy, width: CGFloat(cell.width) - 2 * dx,
                                       height: CGFloat(cell.height) - 2 * dy)).resized(to: side)
    }

    /// En deçà, la case est tenue pour **vide** : un aplat n'a pas de forme,
    /// et corrélerait pourtant avec n'importe quel sort par ses seuls bords.
    static let minContrast = 14.0

    static func identify(cell: LumaBitmap, among candidates: [Candidate]) -> Match? {
        guard !candidates.isEmpty else { return nil }
        let probe = thumbnail(ofCell: cell)
        guard standardDeviation(probe) >= minContrast else { return nil }
        // Un premier tri sans décalage, puis le décalage n'est cherché que pour
        // les meilleurs : vingt-cinq positions pour cinquante candidats et
        // trente-six cases, c'était la seconde de trop.
        let coarse = candidates.map { ($0, correlation(probe, $0.thumb)) }.sorted { $0.1 > $1.1 }
        let ranked = coarse.prefix(6)
            .map { ($0.0, bestCorrelation(probe, $0.0.thumb)) }
            .sorted { $0.1 > $1.1 }
        let best = ranked[0]
        let second = ranked.count > 1 ? ranked[1].1 : -1
        return Match(id: best.0.id, nom: best.0.nom, score: best.1, runnerUp: second)
    }

    static func standardDeviation(_ image: LumaBitmap) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        let n = Double(image.pixels.count)
        let mean = image.pixels.reduce(0.0) { $0 + Double($1) } / n
        let variance = image.pixels.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) } / n
        return variance.squareRoot()
    }

    /// Décalage maximal, en pixels d'imagette, toléré entre la case et la
    /// référence : le cadre du jeu et celui du PNG ne coïncident pas au pixel.
    static let maxShift = 2

    /// La meilleure corrélation à un petit décalage près.
    static func bestCorrelation(_ a: LumaBitmap, _ b: LumaBitmap) -> Double {
        var best = -1.0
        for dy in -maxShift...maxShift {
            for dx in -maxShift...maxShift {
                best = max(best, correlation(a, b, dx: dx, dy: dy))
            }
        }
        return best
    }

    /// Corrélation normalisée (coefficient de Pearson) de deux imagettes de
    /// même taille, `b` décalée de (dx, dy) — sur leur recouvrement. Une image
    /// uniforme n'a pas de forme : corrélation nulle.
    static func correlation(_ a: LumaBitmap, _ b: LumaBitmap, dx: Int = 0, dy: Int = 0) -> Double {
        guard a.width == b.width, a.height == b.height, a.width > abs(dx), a.height > abs(dy) else { return 0 }
        var sa = 0.0, sb = 0.0, n = 0.0
        var pairs: [(Double, Double)] = []
        pairs.reserveCapacity(a.pixels.count)
        for y in max(0, dy)..<min(a.height, a.height + dy) {
            for x in max(0, dx)..<min(a.width, a.width + dx) {
                let va = Double(a[x, y]), vb = Double(b[x - dx, y - dy])
                pairs.append((va, vb)); sa += va; sb += vb; n += 1
            }
        }
        guard n > 0 else { return 0 }
        let meanA = sa / n, meanB = sb / n
        var cov = 0.0, varA = 0.0, varB = 0.0
        for (va, vb) in pairs {
            let da = va - meanA, db = vb - meanB
            cov += da * db; varA += da * da; varB += db * db
        }
        guard varA > 0, varB > 0 else { return 0 }
        return cov / (varA * varB).squareRoot()
    }
}
