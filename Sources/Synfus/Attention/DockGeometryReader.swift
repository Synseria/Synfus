import AppKit
import ApplicationServices

/// Décide, à chaque tour de la détection d'attention, s'il faut refaire la
/// découverte structurelle du Dock ou se contenter du relevé géométrique.
///
/// Logique pure, sans Accessibilité, donc testée : c'est elle qui fixe le coût
/// de la boucle à 10 Hz.
enum DockRefreshPolicy {

    /// Âge au-delà duquel une structure est redécouverte quoi qu'il arrive.
    /// Un filet : la structure devrait déjà se périmer par le compte de
    /// processus ou par une lecture qui échoue, mais un Dock relancé ou une
    /// icône réordonnée par l'utilisateur ne préviennent pas.
    static let maxAge: TimeInterval = 2

    /// - Parameters:
    ///   - cachedItems: nombre d'icônes en cache, `nil` sans structure (premier
    ///     tour, ou tour précédent sans Dock).
    ///   - dofusProcesses: nombre de pids Dofus distincts connus de
    ///     `WindowManager` — chaque processus lancé a son icône.
    ///   - age: ancienneté de la structure.
    static func needsFullTour(cachedItems: Int?, dofusProcesses: Int, age: TimeInterval,
                              maxAge: TimeInterval = maxAge) -> Bool {
        guard let cachedItems else { return true }
        if cachedItems != dofusProcesses { return true }
        return age >= maxAge
    }
}

/// Lit la géométrie du Dock en réutilisant, d'un tour à l'autre, les éléments
/// AX découverts au tour complet précédent.
///
/// En régime permanent, un tour ne coûte plus qu'un aller-retour par icône
/// Dofus et un pour le bandeau, contre plusieurs dizaines quand `inventory()`
/// refaisait toute la découverte — dix fois par seconde, cela se sentait dans
/// les raccourcis et la barre.
@MainActor
final class DockGeometryReader {
    private var structure: DockInspector.Structure?

    /// Le relevé du tour. `dofusProcesses` sert à périmer la structure sans
    /// attendre le filet des deux secondes : un client lancé ou fermé change le
    /// nombre d'icônes, et les rangs avec.
    func read(dofusProcesses: Int, now: Date = Date()) -> DockInspector.Inventory {
        let cachedItems = structure?.items.count
        let age = structure.map { now.timeIntervalSince($0.date) } ?? .infinity

        if !DockRefreshPolicy.needsFullTour(cachedItems: cachedItems,
                                            dofusProcesses: dofusProcesses, age: age),
           let structure,
           let inventory = DockInspector.geometry(of: structure) {
            return inventory
        }

        // Tour complet — premier tour, effectif changé, structure trop vieille, ou
        // lecture légère en échec : un élément invalidé ne répond plus, et il
        // faut le retrouver plutôt que le réinterroger en boucle.
        structure = DockInspector.discoverStructure(now: now)
        guard let structure, let inventory = DockInspector.geometry(of: structure)
        else { return DockInspector.Inventory(items: [], strip: nil) }
        return inventory
    }
}

/// Ce que la détection d'attention expose à l'onglet Diagnostic.
///
/// Tenu à part de `AttentionWatcher` pour une raison de coût : la barre
/// flottante observe le watcher pour `alerting`, et tout `@Published` du même
/// objet la réévaluait aussi. Or `dockReading` change à chaque mouvement du
/// Dock — un rebond, une magnification. Ici, seuls les réglages observent.
@MainActor
final class AttentionDiagnostics: ObservableObject {
    static let shared = AttentionDiagnostics()

    /// Une icône du Dock et le perso qu'on lui attribue. Un type nommé plutôt
    /// qu'un tuple, pour être `Equatable` — ce qui permet de ne republier
    /// l'appariement que lorsqu'il change réellement.
    struct Pair: Equatable {
        let dock: String
        let character: String
    }

    /// Correspondance icône du Dock → perso, exposée pour vérification :
    /// l'appariement rang ↔ pid est une hypothèse.
    @Published private(set) var pairing: [Pair] = []

    /// Dernier relevé du bandeau du Dock et des icônes. Toute la détection repose
    /// sur l'idée qu'un rebond éloigne l'icône de son bandeau alors qu'un Dock
    /// qui glisse les emporte ensemble : c'est une hypothèse, elle doit pouvoir
    /// se vérifier d'un coup d'œil.
    @Published private(set) var dockReading: String?

    private init() {}

    func update(pairing paired: [Pair]) {
        if paired != pairing { pairing = paired }
    }

    func update(reading: String?) {
        if reading != dockReading { dockReading = reading }
    }
}
