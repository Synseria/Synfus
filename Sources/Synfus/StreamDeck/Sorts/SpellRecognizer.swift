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

    func entries(forClass key: String) -> [Entry] {
        entries.filter { $0.classe == key }
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
    static let side = 32
    static let minScore = 0.6
    static let minMargin = 0.1

    static func candidate(id: Int, nom: String, icon: LumaBitmap) -> Candidate {
        Candidate(id: id, nom: nom, thumb: icon.resized(to: side))
    }

    /// La case rognée de son cadre, puis réduite — comme les candidats.
    static func thumbnail(ofCell cell: LumaBitmap, inset: CGFloat = 0.08) -> LumaBitmap {
        let dx = CGFloat(cell.width) * inset, dy = CGFloat(cell.height) * inset
        return cell.cropped(to: CGRect(x: dx, y: dy, width: CGFloat(cell.width) - 2 * dx,
                                       height: CGFloat(cell.height) - 2 * dy)).resized(to: side)
    }

    static func identify(cell: LumaBitmap, among candidates: [Candidate]) -> Match? {
        guard !candidates.isEmpty else { return nil }
        let probe = thumbnail(ofCell: cell)
        let ranked = candidates
            .map { ($0, correlation(probe, $0.thumb)) }
            .sorted { $0.1 > $1.1 }
        let best = ranked[0]
        let second = ranked.count > 1 ? ranked[1].1 : -1
        return Match(id: best.0.id, nom: best.0.nom, score: best.1, runnerUp: second)
    }

    /// Corrélation normalisée (coefficient de Pearson) de deux imagettes de
    /// même taille. Une image uniforme n'a pas de forme : corrélation nulle.
    static func correlation(_ a: LumaBitmap, _ b: LumaBitmap) -> Double {
        guard a.pixels.count == b.pixels.count, !a.pixels.isEmpty else { return 0 }
        let n = Double(a.pixels.count)
        let meanA = a.pixels.reduce(0.0) { $0 + Double($1) } / n
        let meanB = b.pixels.reduce(0.0) { $0 + Double($1) } / n
        var cov = 0.0, varA = 0.0, varB = 0.0
        for i in 0..<a.pixels.count {
            let da = Double(a.pixels[i]) - meanA, db = Double(b.pixels[i]) - meanB
            cov += da * db; varA += da * da; varB += db * db
        }
        guard varA > 0, varB > 0 else { return 0 }
        return cov / (varA * varB).squareRoot()
    }
}
