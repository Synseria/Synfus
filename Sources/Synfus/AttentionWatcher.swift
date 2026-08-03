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

    /// Correspondance icône du Dock → perso, exposée pour vérification dans
    /// l'onglet Diagnostic.
    @Published private(set) var pairing: [(dock: String, character: String)] = []

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

        let items = DockInspector.dofusItems()
        let clients = WindowManager.shared.clients.sorted { $0.pid < $1.pid }

        // Les icônes du Dock s'ajoutent dans l'ordre de lancement des apps, tout
        // comme les pid croissent dans cet ordre : on apparie donc rang à rang.
        // C'est une hypothèse, d'où son affichage dans l'onglet Diagnostic.
        pairing = zip(items, clients).map { ($0.key, $1.name) }

        let screens = Self.screenFramesInAXSpace()
        let snapshot = BounceDetector.Snapshot(
            keys: items.map(\.key),
            y: items.reduce(into: [:]) { $0[$1.key] = $1.position.y },
            size: items.reduce(into: [:]) { $0[$1.key] = $1.size },
            onScreen: Set(items.filter { item in
                screens.contains { $0.contains(item.frame) }
            }.map(\.key)),
            mouseInDock: isMouseOverDock(items)
        )

        for rank in detector.ingest(snapshot) where rank < items.count {
            trigger(index: rank, clients: clients, action: action, key: items[rank].key)
        }
    }

    /// Cadres des écrans dans le repère de l'Accessibilité — origine en haut à
    /// gauche de l'écran principal, ordonnée vers le bas —, alors que `NSScreen`
    /// compte depuis le bas. Sert à savoir si une icône est réellement affichée :
    /// un Dock en masquage automatique glisse ses icônes hors de l'écran.
    private static func screenFramesInAXSpace() -> [CGRect] {
        guard let primary = NSScreen.screens.first else { return [] }
        return NSScreen.screens.map { screen in
            CGRect(
                x: screen.frame.minX,
                y: primary.frame.maxY - screen.frame.maxY,
                width: screen.frame.width,
                // Un point de marge en bas : le Dock déployé pose ses icônes au
                // ras du bord, et un arrondi de mesure les ferait passer pour
                // masquées.
                height: screen.frame.height + 1
            )
        }
    }

    /// Le curseur survole-t-il le Dock ?
    ///
    /// `NSEvent.mouseLocation` compte depuis le bas de l'écran principal, alors
    /// que l'Accessibilité compte depuis le haut : il faut retourner l'ordonnée
    /// avant de comparer les deux.
    private func isMouseOverDock(_ items: [DockInspector.Item]) -> Bool {
        guard let box = DockInspector.boundingFrame(items),
              let reference = NSScreen.screens.first
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
