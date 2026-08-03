import CoreGraphics
import Foundation

/// Machine à états qui décide, relevé après relevé, si une icône du Dock rebondit.
///
/// Rien n'est lu ici : le détecteur est nourri d'un instantané par tour et rend
/// les rangs qui viennent d'achever un rebond. C'est ce qui le rend testable sans
/// Dock, sans Accessibilité et sans écran.
///
/// Deux règles gouvernent tout le reste :
///
/// - **Un rebond est un aller-retour.** Une simple montée ne suffit pas : le Dock
///   lui-même monte et descend d'un bloc — masquage automatique, changement de
///   résolution, redimensionnement. La version précédente ne regardait que la
///   montée, et prenait donc la réapparition d'un Dock masqué pour un appel
///   d'attention.
/// - **Un rebond a lieu Dock visible.** Un Dock en masquage automatique glisse
///   hors de l'écran, et le survol le fait remonter puis redescendre : c'est un
///   aller-retour parfait, que la géométrie de l'icône seule ne distingue pas
///   d'un saut. Seule la visibilité les sépare, d'où `onScreen`.
struct BounceDetector {

    /// Ce que le détecteur reçoit à chaque tour.
    struct Snapshot {
        /// Identités des icônes, dans l'ordre d'affichage. L'indice dans ce
        /// tableau est le rang rendu par `ingest`.
        let keys: [String]
        /// Ordonnée AX de chaque icône (l'axe descend : plus le y est grand, plus
        /// l'icône est basse à l'écran).
        let y: [String: CGFloat]
        let size: [String: CGSize]
        /// Icônes entièrement visibles à l'écran. Les autres appartiennent à un
        /// Dock masqué ou en cours de glissement : leurs positions ne veulent
        /// rien dire.
        let onScreen: Set<String>
        /// Le curseur survole le Dock. La magnification déplace et agrandit alors
        /// les icônes : tout relevé pris dans ces conditions est inexploitable.
        let mouseInDock: Bool
    }

    private enum State {
        case resting
        /// Montée détectée ; on attend le retour au repos pour conclure.
        case inFlight(sinceTick: Int)
    }

    /// Amplitude minimale du saut, en points. Le relevé montre une montée de plus
    /// de 50 points ; 6 suffit à écarter le tremblement de mesure.
    private let jumpThreshold: CGFloat = 6

    /// Tolérance sur le retour au repos, pour conclure le rebond sans exiger le
    /// pixel près.
    private let returnTolerance: CGFloat = 3

    /// Au-delà, la montée n'était pas un rebond mais un déplacement durable de
    /// l'icône : 1,5 s à 10 Hz, alors qu'un saut dure environ une seconde.
    private let maxFlightTicks = 15

    /// Écart maximal entre les déplacements de deux icônes pour les considérer
    /// solidaires, donc emportées par un mouvement du Dock entier.
    private let translationTolerance: CGFloat = 4

    /// Effectif observé au tour précédent, pour repérer un client lancé ou fermé.
    private var knownKeys: Set<String> = []
    private var restingY: [String: CGFloat] = [:]
    private var restingSize: [String: CGSize] = [:]
    private var states: [String: State] = [:]
    private var tick = 0

    /// Avale un relevé et rend les rangs dont le rebond vient de s'achever.
    mutating func ingest(_ snapshot: Snapshot) -> [Int] {
        tick += 1

        // Un client vient de se lancer ou de se fermer : les rangs se décalent, et
        // toutes les positions de repos deviennent caduques. On repart à zéro, les
        // références se reprendront au premier tour où les icônes seront visibles.
        if Set(snapshot.keys) != knownKeys {
            forgetAll(snapshot)
            return []
        }

        // Le survol agrandit les icônes et les fait monter : impossible de
        // distinguer un rebond dans ce bruit, on laisse simplement passer le tour
        // sans toucher aux positions de repos.
        if snapshot.mouseInDock {
            markAllResting(snapshot)
            return []
        }

        if isBlockTranslation(snapshot) {
            rebaseAll(snapshot)
            return []
        }

        var triggered: [Int] = []
        for (rank, key) in snapshot.keys.enumerated() {
            // Dock masqué ou en train de glisser : la position ne dit rien de
            // l'état de repos, et un vol commencé avant ne peut plus se conclure.
            guard snapshot.onScreen.contains(key),
                  let y = snapshot.y[key],
                  let size = snapshot.size[key]
            else {
                states[key] = .resting
                continue
            }

            // Première apparition à l'écran : on ne fait que prendre la référence.
            guard let baseline = restingY[key], let baseSize = restingSize[key] else {
                restingY[key] = y
                restingSize[key] = size
                states[key] = .resting
                continue
            }

            // Positif quand l'icône est montée par rapport à son repos.
            let delta = baseline - y

            switch states[key] ?? .resting {
            case .resting:
                if delta < -jumpThreshold {
                    // L'icône est descendue *sous* son repos, ce qu'un rebond ne
                    // fait jamais : le Dock a changé de taille ou d'écran. On
                    // recale, sans quoi la remontée passerait pour un saut.
                    restingY[key] = y
                    restingSize[key] = size
                } else if delta > jumpThreshold {
                    // La taille ne bouge qu'au survol ; elle écarte ce qui reste
                    // de magnification quand le curseur frôle le Dock sans y entrer.
                    if abs(size.height - baseSize.height) <= 1 {
                        states[key] = .inFlight(sinceTick: tick)
                    }
                } else {
                    // Repos : on suit le y le plus grand, donc la position la plus
                    // basse, et on rafraîchit la taille de référence.
                    restingY[key] = max(baseline, y)
                    restingSize[key] = size
                }

            case .inFlight(let since):
                if tick - since > maxFlightTicks {
                    // Trop long pour un saut : l'icône a été déplacée pour de bon.
                    restingY[key] = y
                    restingSize[key] = size
                    states[key] = .resting
                } else if delta <= returnTolerance {
                    // Montée puis retour : c'est bien un rebond.
                    triggered.append(rank)
                    restingY[key] = max(baseline, y)
                    states[key] = .resting
                }
            }
        }
        return triggered
    }

    /// Toutes les icônes visibles se déplacent ensemble, de la même quantité :
    /// c'est le Dock qui bouge — changement d'écran, de taille —, pas une icône
    /// qui saute.
    private func isBlockTranslation(_ snapshot: Snapshot) -> Bool {
        var deltas: [CGFloat] = []
        for key in snapshot.keys where snapshot.onScreen.contains(key) {
            guard let baseline = restingY[key], let y = snapshot.y[key] else { return false }
            let delta = baseline - y
            guard abs(delta) > jumpThreshold else { return false }
            deltas.append(delta)
        }
        guard deltas.count >= 2, let low = deltas.min(), let high = deltas.max() else { return false }
        return high - low <= translationTolerance
    }

    private mutating func forgetAll(_ snapshot: Snapshot) {
        knownKeys = Set(snapshot.keys)
        restingY = [:]
        restingSize = [:]
        markAllResting(snapshot)
    }

    private mutating func rebaseAll(_ snapshot: Snapshot) {
        for key in snapshot.keys where snapshot.onScreen.contains(key) {
            restingY[key] = snapshot.y[key]
            restingSize[key] = snapshot.size[key]
        }
        markAllResting(snapshot)
    }

    private mutating func markAllResting(_ snapshot: Snapshot) {
        states = snapshot.keys.reduce(into: [:]) { $0[$1] = .resting }
    }
}
