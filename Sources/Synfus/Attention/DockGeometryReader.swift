import AppKit
import ApplicationServices

/// Décide, à chaque tour de la détection d'attention, s'il faut refaire la
/// découverte structurelle du Dock ou se contenter du relevé géométrique.
///
/// Logique pure, sans Accessibilité, donc testée : c'est elle qui fixe le coût
/// de la boucle à 5 Hz (10 Hz quand un rebond se prépare).
enum DockRefreshPolicy {

    /// Âge au-delà duquel une structure est redécouverte quoi qu'il arrive. Un
    /// filet seulement : les icônes Dofus ne changent qu'avec les processus
    /// (`pids`), un Dock relancé fait échouer la lecture légère, et une icône
    /// déplacée par l'utilisateur garde son élément — le rang se recalcule
    /// à chaque relevé.
    static let maxAge: TimeInterval = 30

    /// Une structure qui ne compte pas une icône par processus — client qui se
    /// lance, dont l'icône n'est pas encore « lancée » — se retente à ce
    /// rythme : à chaque tour, un écart durable coûterait le tour complet cinq
    /// fois par seconde.
    static let incompleteRetry: TimeInterval = 1

    /// - Parameters:
    ///   - cachedItems: nombre d'icônes en cache, `nil` sans structure (premier
    ///     tour, ou tour précédent sans Dock).
    ///   - builtFor: les processus Dofus pour lesquels la structure a été bâtie.
    ///   - pids: les processus Dofus vivants connus de `WindowManager` —
    ///     chaque processus lancé a son icône.
    ///   - age: ancienneté de la structure.
    static func needsFullTour(cachedItems: Int?, builtFor: Set<pid_t>, pids: Set<pid_t>,
                              age: TimeInterval) -> Bool {
        guard let cachedItems else { return true }
        // Un client lancé, fermé, ou l'un remplacé par l'autre : les rangs changent.
        if builtFor != pids { return true }
        if cachedItems != pids.count { return age >= incompleteRetry }
        return age >= maxAge
    }
}

/// Lit la géométrie du Dock hors du main actor, en réutilisant d'un tour à
/// l'autre les éléments AX découverts au tour complet précédent.
///
/// En régime permanent, un tour ne coûte qu'un aller-retour par icône Dofus et
/// un pour le bandeau ; le tour complet en coûte plusieurs dizaines. Chacun est
/// un IPC synchrone vers le Dock, borné à 1 s : sur main, un Dock occupé — une
/// animation d'espace, Mission Control — figeait la barre et les raccourcis
/// dix fois par seconde. Exécuteur propre, comme `ClientInventoryEngine` : ces
/// attentes n'ont rien à faire sur le pool coopératif.
///
/// Il n'en sort que des valeurs (`DockInspector.Inventory`) ; la structure en
/// cache, éléments AX compris, ne quitte jamais l'acteur.
actor DockGeometryReader {
    private let queue = DispatchSerialQueue(label: "fr.synseria.synfus.dock", qos: .userInitiated)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private var structure: DockInspector.Structure?

    /// Le relevé du tour. `pids` périme la structure sans attendre le filet :
    /// un client lancé ou fermé change les icônes, et les rangs avec.
    func read(pids: Set<pid_t>, now: Date = Date()) -> DockInspector.Inventory {
        let age = structure.map { now.timeIntervalSince($0.date) } ?? .infinity

        if !DockRefreshPolicy.needsFullTour(cachedItems: structure?.items.count,
                                            builtFor: structure?.pids ?? [], pids: pids, age: age),
           let structure,
           let inventory = DockInspector.geometry(of: structure) {
            return inventory
        }

        // Tour complet — premier tour, processus changés, structure incomplète
        // ou trop vieille, ou lecture légère en échec : un élément invalidé ne
        // répond plus, et il faut le retrouver plutôt que le réinterroger.
        structure = DockInspector.discoverStructure(pids: pids, now: now)
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

    /// Y a-t-il exactement une icône par processus Dofus vivant ? Sinon
    /// l'appariement rang ↔ processus n'est plus fondé, et le Diagnostic doit
    /// le dire plutôt que d'afficher une correspondance à laquelle se fier.
    @Published private(set) var pairingReliable = true

    /// Dernier relevé du bandeau du Dock et des icônes. Toute la détection repose
    /// sur l'idée qu'un rebond éloigne l'icône de son bandeau alors qu'un Dock
    /// qui glisse les emporte ensemble : c'est une hypothèse, elle doit pouvoir
    /// se vérifier d'un coup d'œil.
    @Published private(set) var dockReading: String?

    private init() {}

    func update(pairing paired: [Pair]) {
        if paired != pairing { pairing = paired }
    }

    func update(pairingReliable fiable: Bool) {
        if fiable != pairingReliable { pairingReliable = fiable }
    }

    func update(reading: String?) {
        if reading != dockReading { dockReading = reading }
    }
}
