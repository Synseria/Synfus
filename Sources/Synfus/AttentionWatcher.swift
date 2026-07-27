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
    private var restingY: [String: CGFloat] = [:]
    private var restingSize: [String: CGSize] = [:]
    private var lastTrigger: [String: Date] = [:]

    /// Amplitude minimale du saut, en points. Le relevé montre une montée de
    /// plus de 50 points ; 6 suffit à écarter le tremblement de mesure.
    private let jumpThreshold: CGFloat = 6

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

        for (index, item) in items.enumerated() {
            let key = item.key

            guard let baseline = restingY[key], let baseSize = restingSize[key] else {
                restingY[key] = item.position.y
                restingSize[key] = item.size
                continue
            }

            // Le survol du Dock agrandit les icônes et les fait monter, ce qui
            // ressemble à un rebond. La taille, elle, ne change que dans ce
            // cas-là : elle sert donc à écarter les faux positifs.
            let magnified = abs(item.size.height - baseSize.height) > 1
            let jumped = baseline - item.position.y > jumpThreshold

            if jumped && !magnified {
                trigger(index: index, clients: clients, action: action, key: key)
            } else if !magnified {
                // Le repos est la position la plus basse à l'écran, donc le y le
                // plus grand : on suit ce maximum pour absorber un Dock déplacé.
                restingY[key] = max(baseline, item.position.y)
            }
        }

        // Oublie les icônes disparues (client fermé), sinon leur repos périmé
        // ferait diverger la détection au prochain lancement.
        let present = Set(items.map(\.key))
        restingY = restingY.filter { present.contains($0.key) }
        restingSize = restingSize.filter { present.contains($0.key) }
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
