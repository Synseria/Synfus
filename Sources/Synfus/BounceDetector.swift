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
/// - **Un rebond se mesure par rapport au Dock, pas à l'écran.** Une icône qui
///   rebondit se détache du bandeau ; un Dock qui se masque ou se dévoile
///   emporte l'un et l'autre. Comparer l'icône au bandeau distingue donc les
///   deux mouvements, sans rien avoir à supposer de la visibilité.
///
///   C'est ce qui remplace la règle « un rebond a lieu Dock visible », qui
///   exigeait que le cadre de l'icône tienne entièrement dans un écran. Un relevé
///   réel l'a mise en défaut : avec le masquage automatique, les icônes reposent
///   *sous* le bord de l'écran — sur un 1728 × 1117, à y = 1117 pile. Aucune
///   position de repos n'était donc jamais retenue, et un rebond parfaitement
///   net — l'icône montait à y = 1055, soit 61 points — ne déclenchait rien du
///   tout. La règle protégeait des faux positifs en rendant la détection
///   impossible.
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
        /// Ordonnée du bandeau du Dock, quand l'Accessibilité la rend. Tout se
        /// mesure relativement à elle. Sans elle, on retombe sur des ordonnées
        /// absolues — la détection marche encore, mais un Dock qui glisse n'est
        /// plus distingué que par `isBlockTranslation` et `mouseInDock`.
        let dockTop: CGFloat?
        /// Le curseur survole le Dock. La magnification déplace et agrandit alors
        /// les icônes : tout relevé pris dans ces conditions est inexploitable.
        let mouseInDock: Bool

        /// Position de l'icône **dans** le Dock. C'est cette grandeur-là, et non
        /// l'ordonnée écran, que le détecteur suit d'un tour à l'autre.
        func offset(of key: String) -> CGFloat? {
            guard let y = y[key] else { return nil }
            return y - (dockTop ?? 0)
        }
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
            guard let size = snapshot.size[key],
                  let y = snapshot.offset(of: key)
            else {
                states[key] = .resting
                continue
            }

            // Première mesure : on ne fait que prendre la référence.
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

    /// Toutes les icônes se déplacent ensemble, de la même quantité : c'est le
    /// Dock qui bouge — changement d'écran, de taille —, pas une icône qui saute.
    ///
    /// Le filet ne sert plus que lorsque le bandeau n'a pas pu être lu : mesurées
    /// relativement à lui, les icônes d'un Dock qui glisse ne bougent pas du tout.
    private func isBlockTranslation(_ snapshot: Snapshot) -> Bool {
        var deltas: [CGFloat] = []
        for key in snapshot.keys {
            guard let baseline = restingY[key], let y = snapshot.offset(of: key) else { return false }
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
        for key in snapshot.keys {
            restingY[key] = snapshot.offset(of: key)
            restingSize[key] = snapshot.size[key]
        }
        markAllResting(snapshot)
    }

    private mutating func markAllResting(_ snapshot: Snapshot) {
        states = snapshot.keys.reduce(into: [:]) { $0[$1] = .resting }
    }
}
