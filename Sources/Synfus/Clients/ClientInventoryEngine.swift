import ApplicationServices
import Foundation

/// Ce que le main actor confie à l'acteur d'inventaire — rien que des valeurs.
struct InventoryRequest: Sendable {
    let generation: Int
    /// Tous les processus Dofus vivants, dans l'ordre de `runningApplications` :
    /// c'est cet ordre qui suffixe les homonymes, il ne doit pas changer d'un
    /// tour à l'autre.
    let pids: [pid_t]
    /// Vivants mais jamais interrogés ce tour-ci — en fermeture, ou suspects
    /// dont la sonde n'est pas due. Ils comptent parmi les vivants, pas parmi
    /// les bavards : la mémoire les affiche atténués.
    let skippedPIDs: Set<pid_t>
    /// Pids sans aucune mémoire dont la lecture CGWindowList est due. L'acteur
    /// ne la fait que pour ceux d'entre eux qui se révèlent silencieux.
    let crossSpaceCandidates: Set<pid_t>
}

/// Ce que l'acteur rapporte. Tout est constaté, rien n'est décidé : les
/// décisions (mémoire, strikes, tri) se prennent sur main, avec l'état courant.
struct InventoryResult: Sendable, Equatable {
    let generation: Int
    /// Persos vus, non dormants, noms déjà suffixés pour les homonymes.
    let found: [DofusClient]
    let livePIDs: Set<pid_t>
    /// Ont rendu au moins une fenêtre : joignables, et sans perso s'ils n'en
    /// livrent aucun — retournés à l'écran de connexion.
    let talkativePIDs: Set<pid_t>
    /// Ont laissé expirer `kAXWindows` : le mutisme que compte le veilleur.
    let mutePIDs: Set<pid_t>
    /// Effectivement interrogés — `pids` moins `skippedPIDs`. C'est ce fait, et
    /// non l'échéance au moment d'appliquer, qui autorise à blanchir un suspect.
    let probedPIDs: Set<pid_t>
    /// Titres lus à travers les espaces, et pids pour lesquels la lecture a été
    /// faite — même sans résultat, ils sont datés.
    let crossSpaceTitles: [pid_t: String]
    let crossSpaceProbed: Set<pid_t>
    let duration: TimeInterval
}

/// Un inventaire à la fois, jamais deux : la règle de lancement, pure.
///
/// Une demande pendant un inventaire en vol n'en lance pas un second — elle
/// note qu'un tour de plus est dû, et il part à la fin de celui-ci. Une rafale
/// (timer + notifications + « Rafraîchir ») coûte donc au plus un inventaire
/// en vol et un différé. Un résultat d'une génération dépassée est ignoré.
struct InventoryScheduling: Equatable {
    private(set) var generation = 0
    private(set) var inFlight = false
    private(set) var requested = false

    enum Request: Equatable {
        case launch(generation: Int)
        case coalesce
    }

    enum Completion: Equatable {
        /// D'une génération dépassée, ou sans lancement connu : à jeter.
        case stale
        /// À appliquer ; puis relancer, si un tour a été demandé entre-temps.
        case apply(relaunch: Int?)
    }

    /// La génération qui sera appliquée après cette demande — celle à attendre.
    var nextToApply: Int { inFlight && requested ? generation + 1 : generation }

    mutating func request() -> Request {
        if inFlight {
            requested = true
            return .coalesce
        }
        generation += 1
        inFlight = true
        return .launch(generation: generation)
    }

    mutating func completed(generation done: Int) -> Completion {
        guard inFlight, done == generation else { return .stale }
        inFlight = false
        guard requested else { return .apply(relaunch: nil) }
        requested = false
        generation += 1
        inFlight = true
        return .apply(relaunch: generation)
    }
}

/// L'inventaire Accessibilité, hors du main actor.
///
/// Chaque question à un client est un IPC synchrone, borné à 1 s ; un client
/// gelé — à la fermeture, typiquement — la laisse expirer, et l'inventaire
/// passe toutes les 2 s. Sur main, c'était la barre, le menu et les raccourcis
/// qui se figeaient au rythme des sondes. Ici, seul l'acteur attend.
///
/// L'acteur a son **exécuteur propre** : des IPC bloquants d'une seconde n'ont
/// rien à faire sur le pool coopératif de Swift Concurrency, qu'ils
/// affameraient. Et `inventory(_:)` ne contient aucun `await` : pas de
/// réentrance, un inventaire à la fois par construction.
///
/// Il n'y entre que des valeurs (`InventoryRequest`), il n'en sort que des
/// valeurs (`InventoryResult`) ; les éléments AX voyagent en `AXHandle`.
actor ClientInventoryEngine {
    private let queue = DispatchSerialQueue(label: "fr.synseria.synfus.inventaire", qos: .userInitiated)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    func inventory(_ request: InventoryRequest) -> InventoryResult {
        let start = Date()
        var found: [DofusClient] = []
        var usedNames: [String: Int] = [:]
        var talkativePIDs: Set<pid_t> = []
        var mutePIDs: Set<pid_t> = []

        for pid in request.pids where !request.skippedPIDs.contains(pid) {
            let windows: [AXHandle]
            switch AccessibilityReader.windows(of: .application(pid)) {
            case .windows(let list): windows = list
            case .mute: mutePIDs.insert(pid); continue
            case .failed: continue
            }

            // Un client qui rend au moins une fenêtre est joignable : s'il n'en
            // ressort aucun perso, c'est qu'il est retourné à l'écran de
            // connexion, et non qu'il se cache sur un autre bureau.
            if !windows.isEmpty { talkativePIDs.insert(pid) }

            for (index, window) in windows.enumerated() {
                // Un seul aller-retour par fenêtre pour les trois attributs.
                let facts = AccessibilityReader.windowFacts(window)
                guard AccessibilityReader.isGameWindow(subrole: facts.subrole, size: facts.size) else { continue }

                let rawTitle = facts.title ?? ""
                guard WindowTitle.isCharacterWindow(title: rawTitle) else { continue }

                var name = WindowTitle.characterName(fromTitle: rawTitle)

                // Deux persos peuvent porter un titre identique (ou vide) : on les
                // distingue visuellement plutôt que de les laisser se confondre.
                let seen = usedNames[name, default: 0] + 1
                usedNames[name] = seen
                if seen > 1 { name = "\(name) (\(seen))" }

                found.append(DofusClient(
                    pid: pid,
                    slotKey: "\(pid)#\(index)",
                    axWindow: window,
                    rawTitle: rawTitle,
                    name: name,
                    characterClass: WindowTitle.characterClass(fromTitle: rawTitle),
                    dormant: false
                ))
            }
        }

        // Le tour de toutes les fenêtres du système, lui aussi hors main — pour
        // les seuls candidats qui viennent de se révéler silencieux.
        let livePIDs = Set(request.pids)
        let silentPIDs = livePIDs.subtracting(talkativePIDs)
        let toRead = request.crossSpaceCandidates.intersection(silentPIDs)
        let titles = toRead.isEmpty ? [:] : CrossSpaceTitles.read(pids: toRead)

        return InventoryResult(
            generation: request.generation,
            found: found,
            livePIDs: livePIDs,
            talkativePIDs: talkativePIDs,
            mutePIDs: mutePIDs,
            probedPIDs: livePIDs.subtracting(request.skippedPIDs),
            crossSpaceTitles: titles,
            crossSpaceProbed: toRead,
            duration: Date().timeIntervalSince(start)
        )
    }
}
