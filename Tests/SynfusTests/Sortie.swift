import Foundation

/// Les mesures des bancs (`RealCaptureTests`, `SimulationSuiviTests`), marquées
/// « ▸ » : `test.sh`, qui filtre la sortie de `swift test`, les laisse passer.
enum Sortie {
    static func dire(_ texte: String) {
        for ligne in texte.split(separator: "\n", omittingEmptySubsequences: false) { print("▸ \(ligne)") }
        // Redirigée vers un fichier, la sortie attendrait la fin d'un banc de plusieurs minutes.
        fflush(nil)
    }
}
