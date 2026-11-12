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
        case .ignore: return L("attention.ignorer")
        case .highlight: return L("attention.signaler")
        case .focus: return L("attention.basculer")
        }
    }

    var explanation: String {
        switch self {
        case .ignore:
            return L("attention.ignorer.aide")
        case .highlight:
            return L("attention.signaler.aide")
        case .focus:
            return L("attention.basculer.aide")
        }
    }

    /// Le Dock n'est relevé que s'il y a un perso à signaler et une suite à
    /// donner : sinon le minuteur ne tourne même pas.
    func veilleLeDock(persos: Int) -> Bool {
        self != .ignore && persos > 0
    }
}

/// Détecte les rebonds d'icône dans le Dock, à la cadence que le détecteur
/// demande (`BounceDetector.cadence`).
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

    /// Le lecteur du Dock, hors main, qui garde les éléments AX d'un tour à
    /// l'autre : en régime permanent, le tour ne relit que positions et tailles.
    private let dockReader = DockGeometryReader()
    private let diagnostics = AttentionDiagnostics.shared

    /// Persos triés par pid croissant, tenus à jour par abonnement plutôt que
    /// retriés à chaque tour : la liste ne change qu'à l'inventaire, bien
    /// moins souvent que ce tour ne passe.
    private var sortedClients: [DofusClient] = []
    /// Le réglage tel qu'émis : `@Published` publie avant d'affecter.
    private var action: AttentionAction = .ignore
    private var subscriptions: Set<AnyCancellable> = []

    /// Relevé du tour précédent. Les chaînes du Diagnostic ne sont recomposées
    /// que si les valeurs numériques ont bougé.
    private var lastInventory: DockInspector.Inventory?

    private var timer: Timer?
    /// Un relevé à la fois : un Dock lent fait sauter des tours plutôt que
    /// d'empiler des lectures.
    private var readInFlight = false
    private var detector = BounceDetector()
    private var lastTrigger: [String: Date] = [:]

    /// Un rebond dure environ une seconde et se répète tant que l'app n'est pas
    /// activée : sans ce délai de garde, un seul tour déclencherait en rafale.
    private let cooldown: TimeInterval = 4

    private init() {}

    func start() {
        // `@Published` émet la nouvelle valeur avant de l'affecter : c'est bien
        // elle que l'on trie, pas la précédente.
        WindowManager.shared.$clients.sink { [weak self] clients in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.sortedClients = clients.sorted { $0.pid < $1.pid }
                // Un perso qui se ferme en pleine alerte n'a plus de raison d'y
                // rester : sans cette purge, `alerting` grossirait d'un
                // `slotKey` mort à chaque fermeture pendant un rebond.
                let vivants = Set(clients.map(\.slotKey))
                let purge = self.alerting.intersection(vivants)
                if purge != self.alerting { self.alerting = purge }
                self.reviewArming()
            }
        }
        .store(in: &subscriptions)
        Preferences.shared.$attentionAction.removeDuplicates().sink { [weak self] action in
            MainActor.assumeIsolated {
                self?.action = action
                self?.reviewArming()
            }
        }
        .store(in: &subscriptions)
    }

    /// Le perso vient d'être regardé : on éteint son alerte.
    func clear(_ client: DofusClient) {
        guard alerting.contains(client.slotKey) else { return }
        alerting.remove(client.slotKey)
    }

    /// Sans perso connecté, ou réglage sur « Ignorer », le minuteur s'arrête :
    /// cinq réveils par seconde pour ne rien relever.
    private func reviewArming() {
        guard action.veilleLeDock(persos: sortedClients.count) else { return disarm() }
        guard timer == nil else { return }
        arm(every: detector.cadence)
    }

    /// La tolérance, un cinquième du pas, laisse le système grouper ce réveil
    /// sans rien manquer.
    private func arm(every interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = interval / 5
    }

    private func disarm() {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
        // Au réarmement, les positions de repos d'avant ne disent plus rien.
        detector = BounceDetector()
        lastInventory = nil
        diagnostics.update(pairing: [])
        diagnostics.update(pairingReliable: true)
        if !alerting.isEmpty { alerting.removeAll() }
    }

    private func tick() {
        guard !readInFlight else { return }
        readInFlight = true
        // Un processus, une icône : les processus vivants périment la structure
        // en cache dès qu'un client se lance ou se ferme. `clients` ne suffirait
        // pas : un client au login sur un autre bureau a une icône sans avoir
        // de perso, et le cache serait périmé à jamais.
        let pids = WindowManager.shared.liveDofusPIDs
        Task {
            let inventory = await dockReader.read(pids: pids)
            readInFlight = false
            // Désarmé pendant la lecture : plus rien à signaler.
            guard timer != nil else { return }
            ingest(inventory, pids: pids)
        }
    }

    private func ingest(_ inventory: DockInspector.Inventory, pids: Set<pid_t>) {
        let items = inventory.items

        // Les icônes du Dock s'ajoutent dans l'ordre de lancement des apps, tout
        // comme les pid croissent dans cet ordre : on apparie donc rang à rang.
        // C'est une hypothèse, d'où son affichage dans l'onglet Diagnostic — et
        // elle porte sur les **processus**, pas sur les persos : un client resté
        // à l'écran de connexion a son icône sans avoir de perso, et zipper les
        // deux listes décalait tous les rangs suivants (cf. `DockPairing`).
        //
        // Ce tour de boucle passe cinq à dix fois par seconde : rien n'est republié
        // sans avoir changé, et les chaînes du Diagnostic ne sont même pas
        // recomposées tant que le relevé est numériquement le même.
        let apparies = DockPairing.apparier(nombreIcones: items.count,
                                            pidsVivants: pids, clients: sortedClients)
        diagnostics.update(pairing: zip(items, apparies).map {
            AttentionDiagnostics.Pair(dock: $0.key, character: $1?.name ?? L("attention.appariement.sansPerso"))
        })
        diagnostics.update(pairingReliable: DockPairing.fiable(nombreIcones: items.count,
                                                               pidsVivants: pids))
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

        // Les clés des icônes disparues n'ont plus de délai de garde à porter :
        // sans cette purge, `lastTrigger` grossissait à chaque relance du Dock.
        let vivantes = Set(items.map(\.key))
        if lastTrigger.keys.contains(where: { !vivantes.contains($0) }) {
            lastTrigger = lastTrigger.filter { vivantes.contains($0.key) }
        }

        for rank in detector.ingest(snapshot, at: ProcessInfo.processInfo.systemUptime) where rank < items.count {
            guard let client = apparies[rank] else { continue }
            trigger(client, action: action, key: items[rank].key)
        }
        if let timer, timer.timeInterval != detector.cadence { arm(every: detector.cadence) }
    }

    /// Une ligne lisible : où est le bandeau, et de combien chaque icône s'en
    /// écarte. Au repos les écarts sont constants ; pendant un rebond, celui de
    /// l'icône qui saute — et lui seul — se creuse.
    private static func describe(_ inventory: DockInspector.Inventory) -> String {
        guard let strip = inventory.strip else {
            return L("attention.releve.sansBandeau")
        }
        let ecarts = inventory.items
            .map { String(format: "%+.0f\u{00A0}px", $0.position.y - strip.minY) }
            .joined(separator: ", ")
        return L("attention.releve.bandeau", strip.minY, strip.height)
            + (ecarts.isEmpty ? L("attention.releve.aucune") : ecarts)
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
        let y = LayoutComputer.flipY(mouse.y, hauteurPrincipale: reference.frame.maxY)
        return box.contains(CGPoint(x: mouse.x, y: y))
    }

    private func trigger(_ client: DofusClient, action: AttentionAction, key: String) {
        if let last = lastTrigger[key], Date().timeIntervalSince(last) < cooldown { return }
        lastTrigger[key] = Date()

        // Inutile de signaler le perso qu'on est déjà en train de regarder.
        guard !WindowManager.shared.isFrontmost(client) else { return }

        switch action {
        case .ignore:
            break
        case .highlight:
            alerting.insert(client.slotKey)
        case .focus:
            alerting.insert(client.slotKey)
            UsageStore.shared.compter(.basculeAttention)
            WindowManager.shared.focus(client)
        }
    }
}
