import AppKit

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

    /// Une icône du Dock et le perso qu'on lui attribue. Un type nommé plutôt
    /// qu'un tuple, pour être `Equatable` — ce qui permet de ne republier
    /// l'appariement que lorsqu'il change réellement.
    struct Pair: Equatable {
        let dock: String
        let character: String
    }

    /// Correspondance icône du Dock → perso, exposée pour vérification dans
    /// l'onglet Diagnostic.
    @Published private(set) var pairing: [Pair] = []

    /// Dernier relevé du bandeau du Dock et de la première icône, exposé au
    /// Diagnostic. Toute la détection repose sur l'idée qu'un rebond éloigne
    /// l'icône de son bandeau alors qu'un Dock qui glisse les emporte ensemble :
    /// c'est une hypothèse, elle doit pouvoir se vérifier d'un coup d'œil.
    @Published private(set) var dockReading: String?

    private var timer: Timer?
    private var detector = BounceDetector()
    private var lastTrigger: [String: Date] = [:]

    /// Un rebond dure environ une seconde et se répète tant que l'app n'est pas
    /// activée : sans ce délai de garde, un seul tour déclencherait en rafale.
    private let cooldown: TimeInterval = 4

    private init() {}

    func start() {
        timer?.invalidate()
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
        let clients = WindowManager.shared.clients.sorted { $0.pid < $1.pid }
        guard !clients.isEmpty else {
            if !pairing.isEmpty { pairing = [] }
            if !alerting.isEmpty { alerting.removeAll() }
            return
        }

        let inventory = DockInspector.inventory()
        let items = inventory.items

        // Les icônes du Dock s'ajoutent dans l'ordre de lancement des apps, tout
        // comme les pid croissent dans cet ordre : on apparie donc rang à rang.
        // C'est une hypothèse, d'où son affichage dans l'onglet Diagnostic.
        //
        // L'égalité court-circuite la republication. Ce tour de boucle passe dix
        // fois par seconde : réassigner sans regarder invalidait la barre
        // flottante — qui observe ce watcher — à la même cadence, en permanence,
        // pour un appariement qui ne change qu'au lancement d'un client.
        let paired = zip(items, clients).map { Pair(dock: $0.key, character: $1.name) }
        if paired != pairing { pairing = paired }

        let reading = Self.describe(inventory)
        if reading != dockReading { dockReading = reading }

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
