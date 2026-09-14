import AppKit
import Combine

/// Ce que Synfus fait quand un perso réclame l'attention.
enum AttentionAction: String, Codable, CaseIterable, Identifiable {
    case ignore
    case highlight
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ignore: return "Ne rien faire"
        case .highlight: return "Le signaler dans la barre"
        case .focus: return "Basculer automatiquement dessus"
        }
    }

    var explanation: String {
        switch self {
        case .ignore:
            return "La détection reste inactive."
        case .highlight:
            return "Le perso concerné clignote dans la barre. Tu vois où aller sans être déplacé de force."
        case .focus:
            return "Synfus met le perso au premier plan de lui-même. Pratique en combat, "
                 + "déroutant si tu es en train d'écrire ailleurs."
        }
    }
}

/// Détecte les rebonds d'icône dans le Dock.
///
/// Aucune API publique ne signale qu'une *autre* app réclame l'attention. En
/// revanche le Dock anime l'icône, et il expose sa position animée via
/// l'Accessibilité : `AXPosition.y` chute le temps du saut, puis revient. C'est
/// ce mouvement, et rien d'autre, que l'on suit ici — le jeu lui-même n'est ni
/// lu ni sollicité.
@MainActor
final class AttentionWatcher: ObservableObject {
    static let shared = AttentionWatcher()

    /// Persos actuellement en train de réclamer l'attention.
    @Published private(set) var alerting: Set<String> = []

    /// Le lecteur du Dock, qui garde les éléments AX d'un tour à l'autre : en
    /// régime permanent, le tour ne relit que les positions et tailles.
    private let dockReader = DockGeometryReader()
    private let diagnostics = AttentionDiagnostics.shared

    /// Persos triés par pid croissant, tenus à jour par abonnement plutôt que
    /// retriés à chaque tour : la liste ne change qu'à l'inventaire, dix fois
    /// moins souvent que ce tour ne passe.
    private var sortedClients: [DofusClient] = []
    private var clientsSubscription: AnyCancellable?

    /// Relevé du tour précédent. Les chaînes du Diagnostic ne sont recomposées
    /// que si les valeurs numériques ont bougé.
    private var lastInventory: DockInspector.Inventory?

    private var timer: Timer?
    private var detector = BounceDetector()
    private var lastTrigger: [String: Date] = [:]

    /// Un rebond dure environ une seconde et se répète tant que l'app n'est pas
    /// activée : sans ce délai de garde, un seul tour déclencherait en rafale.
    private let cooldown: TimeInterval = 4

    private init() {}

    func start() {
        timer?.invalidate()
        // `@Published` émet la nouvelle valeur avant de l'affecter : c'est bien
        // elle que l'on trie, pas la précédente.
        clientsSubscription = WindowManager.shared.$clients.sink { [weak self] clients in
            MainActor.assumeIsolated {
                self?.sortedClients = clients.sorted { $0.pid < $1.pid }
            }
        }
        // 0,1 s : le saut dure environ une seconde, on le voit largement.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        alerting.removeAll()
    }

    /// Le perso vient d'être regardé : on éteint son alerte.
    func clear(_ client: DofusClient) {
        alerting.remove(client.slotKey)
    }

    private func tick() {
        let action = Preferences.shared.attentionAction
        guard action != .ignore else {
            if !alerting.isEmpty { alerting.removeAll() }
            return
        }

        // Sans perso à signaler, il n'y a rien à détecter : inutile d'aller
        // interroger le Dock par l'Accessibilité dix fois par seconde alors que
        // Dofus n'est même pas lancé.
        let clients = sortedClients
        guard !clients.isEmpty else {
            diagnostics.update(pairing: [])
            if !alerting.isEmpty { alerting.removeAll() }
            return
        }

        // Un processus, une icône : le compte de processus vivants périme la
        // structure en cache dès qu'un client se lance ou se ferme. Celui de
        // `clients` ne suffirait pas : un client au login sur un autre bureau
        // a une icône sans avoir de perso, et le cache serait périmé à jamais.
        let processes = WindowManager.shared.liveDofusPIDs.count
        let inventory = dockReader.read(dofusProcesses: processes)
        let items = inventory.items

        // Les icônes du Dock s'ajoutent dans l'ordre de lancement des apps, tout
        // comme les pid croissent dans cet ordre : on apparie donc rang à rang.
        // C'est une hypothèse, d'où son affichage dans l'onglet Diagnostic.
        //
        // Ce tour de boucle passe dix fois par seconde : rien n'est republié
        // sans avoir changé, et les chaînes du Diagnostic ne sont même pas
        // recomposées tant que le relevé est numériquement le même.
        diagnostics.update(pairing: zip(items, clients).map {
            AttentionDiagnostics.Pair(dock: $0.key, character: $1.name)
        })
        if inventory != lastInventory {
            lastInventory = inventory
            diagnostics.update(reading: Self.describe(inventory))
        }

        let snapshot = BounceDetector.Snapshot(
            keys: items.map(\.key),
            y: items.reduce(into: [:]) { $0[$1.key] = $1.position.y },
            size: items.reduce(into: [:]) { $0[$1.key] = $1.size },
            dockTop: inventory.strip?.minY,
            mouseInDock: isMouseOverDock(inventory)
        )

        for rank in detector.ingest(snapshot) where rank < items.count {
            trigger(index: rank, clients: clients, action: action, key: items[rank].key)
        }
    }

    /// Une ligne lisible : où est le bandeau, et de combien chaque icône s'en
    /// écarte. Au repos les écarts sont constants ; pendant un rebond, celui de
    /// l'icône qui saute — et lui seul — se creuse.
    private static func describe(_ inventory: DockInspector.Inventory) -> String {
        guard let strip = inventory.strip else {
            return "bandeau illisible — mesure sur l'ordonnée écran"
        }
        let ecarts = inventory.items
            .map { String(format: "%+.0f", $0.position.y - strip.minY) }
            .joined(separator: ", ")
        return String(format: "bandeau y=%.0f h=%.0f · écarts des icônes : ", strip.minY, strip.height)
            + (ecarts.isEmpty ? "aucune" : ecarts)
    }

    /// Le curseur survole-t-il le Dock ?
    ///
    /// `NSEvent.mouseLocation` compte depuis le bas de l'écran principal, alors
    /// que l'Accessibilité compte depuis le haut : il faut retourner l'ordonnée
    /// avant de comparer les deux.
    private func isMouseOverDock(_ inventory: DockInspector.Inventory) -> Bool {
        guard let box = inventory.mouseZone, let reference = NSScreen.screens.first
        else { return false }

        let mouse = NSEvent.mouseLocation
        return box.contains(CGPoint(x: mouse.x, y: reference.frame.maxY - mouse.y))
    }

    private func trigger(index: Int, clients: [DofusClient], action: AttentionAction, key: String) {
        if let last = lastTrigger[key], Date().timeIntervalSince(last) < cooldown { return }
        lastTrigger[key] = Date()

        guard index < clients.count else { return }
        let client = clients[index]

        // Inutile de signaler le perso qu'on est déjà en train de regarder.
        guard !WindowManager.shared.isFrontmost(client) else { return }

        switch action {
        case .ignore:
            break
        case .highlight:
            alerting.insert(client.slotKey)
        case .focus:
            alerting.insert(client.slotKey)
            WindowManager.shared.focus(client)
        }
    }
}
