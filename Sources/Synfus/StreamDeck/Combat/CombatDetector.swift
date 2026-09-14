import CoreGraphics
import Foundation

/// Décide « en combat » ou « hors combat » d'après un relevé de l'interface —
/// pur : on le nourrit d'une imagette et de deux références, il rend un
/// verdict, sans rien lire lui-même (comme `BounceDetector`).
///
/// Aucune API ne dit l'état du combat ; la seule voie est visuelle. Plutôt
/// qu'une signature figée du jeu — qui changerait à chaque mise à jour —, la
/// détection se **calibre** : l'utilisateur capture une fois l'interface en
/// combat, une fois hors combat, et chaque relevé est comparé aux deux par
/// corrélation. Le verdict ne bascule qu'après `confirmations` relevés
/// concordants : un écran de transition ne fait pas changer de page.
struct CombatDetector: Equatable, Sendable {
    /// Bande de la fenêtre observée, en fractions : le bas, où vivent la
    /// timeline des combattants et le bouton de fin de tour.
    static let region = CGRect(x: 0, y: 0.78, width: 1, height: 0.22)
    /// Taille de l'imagette comparée : assez grossière pour ignorer le
    /// contenu (quel sort, quel PNJ), assez fine pour voir la timeline.
    static let sampleWidth = 64
    static let sampleHeight = 14

    let enCombat: LumaBitmap
    let horsCombat: LumaBitmap
    var confirmations = 2
    /// Écart minimal entre les deux corrélations pour trancher.
    var minMargin = 0.08

    private(set) var verdict: Bool?
    private var pending: (value: Bool, count: Int)?

    init(enCombat: LumaBitmap, horsCombat: LumaBitmap) {
        self.enCombat = enCombat
        self.horsCombat = horsCombat
    }

    /// Réduit une capture de la bande à la taille de comparaison.
    static func sample(_ image: LumaBitmap) -> LumaBitmap {
        image.resized(width: sampleWidth, height: sampleHeight)
    }

    struct Reading: Equatable, Sendable {
        let correlationCombat: Double
        let correlationHors: Double
        var leaning: Bool? {
            abs(correlationCombat - correlationHors) < 1e-9 ? nil : correlationCombat > correlationHors
        }
    }

    /// Mesure un relevé sans changer l'état — pour le Diagnostic.
    func read(_ sample: LumaBitmap) -> Reading {
        Reading(correlationCombat: SpellRecognizer.correlation(sample, enCombat),
                correlationHors: SpellRecognizer.correlation(sample, horsCombat))
    }

    /// Consigne un relevé ; rend le verdict courant (inchangé tant que la
    /// bascule n'est pas confirmée).
    @discardableResult
    mutating func observe(_ sample: LumaBitmap) -> Bool? {
        let reading = read(sample)
        guard abs(reading.correlationCombat - reading.correlationHors) >= minMargin,
              let leaning = reading.leaning
        else { pending = nil; return verdict }
        if leaning == verdict { pending = nil; return verdict }
        if let pending, pending.value == leaning {
            self.pending = (leaning, pending.count + 1)
        } else {
            pending = (leaning, 1)
        }
        if let pending, pending.count >= confirmations {
            verdict = leaning
            self.pending = nil
        }
        return verdict
    }

    static func == (lhs: CombatDetector, rhs: CombatDetector) -> Bool {
        lhs.enCombat == rhs.enCombat && lhs.horsCombat == rhs.horsCombat && lhs.verdict == rhs.verdict
    }
}
