import CoreGraphics
import Foundation

/// La chaîne complète, de la capture aux noms : localiser la barre, comparer
/// chaque case aux icônes de la classe. Un seul foyer, partagé par le banc
/// d'essai du Diagnostic et par « Reconnaître » dans l'onglet Sorts.
enum SpellRecognition {

    struct CellResult: Equatable, Sendable {
        let position: Int
        let match: SpellRecognizer.Match?
    }

    struct Analysis: Equatable, Sendable {
        let bar: SpellBarLocator.Bar?
        let candidateCount: Int
        let cells: [CellResult]
        let locateDuration: TimeInterval
        let matchDuration: TimeInterval

        var confidentCount: Int { cells.filter { $0.match?.isConfident == true }.count }
    }

    /// Les icônes d'une classe — de toutes si elle est inconnue —, réduites.
    /// À faire une fois par analyse, pas par case.
    static func candidates(forClass classe: String?) -> [SpellRecognizer.Candidate] {
        guard let index = SpellIndex.load() else { return [] }
        let key = classe.flatMap(DofusClass.key(for:))
        let entries = key.map { index.entries(forClass: $0) } ?? index.entries
        return entries.compactMap { entry in
            guard let url = AnkamaAssets.spellIconURL(fichier: entry.fichier),
                  let icon = LumaBitmap(contentsOf: url)
            else { return nil }
            return SpellRecognizer.candidate(id: entry.id, nom: entry.nom, icon: icon)
        }
    }

    static func analyze(_ image: LumaBitmap, classe: String?) -> Analysis {
        let start = Date()
        guard let bar = SpellBarLocator.locate(in: image) else {
            return Analysis(bar: nil, candidateCount: 0, cells: [],
                            locateDuration: Date().timeIntervalSince(start), matchDuration: 0)
        }
        let located = Date()
        let candidates = candidates(forClass: classe)
        let cells = bar.cells.enumerated().map { index, cell in
            CellResult(position: index,
                       match: SpellRecognizer.identify(cell: image.cropped(to: cell), among: candidates))
        }
        return Analysis(bar: bar, candidateCount: candidates.count, cells: cells,
                        locateDuration: located.timeIntervalSince(start),
                        matchDuration: Date().timeIntervalSince(located))
    }
}
