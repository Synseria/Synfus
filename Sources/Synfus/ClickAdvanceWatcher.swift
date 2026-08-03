import AppKit

/// Modificateur qui, associé à un clic, fait avancer d'un perso.
///
/// Configurable, et pas figé sur ⌘ : rien ne garantit que le client de jeu
/// traite un ⌘-clic comme un clic ordinaire, et le savoir demande d'essayer.
enum ClickModifier: String, Codable, CaseIterable, Identifiable {
    case command, option, control, shift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .command: return "⌘ Commande"
        case .option: return "⌥ Option"
        case .control: return "⌃ Contrôle"
        case .shift: return "⇧ Majuscule"
        }
    }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}

/// Enchaîne les persos au clic : un clic modifié sur un client Dofus passe au
/// suivant une fois le clic délivré.
///
/// Synfus **n'émet aucun évènement** : il ne rejoue pas le clic, ne le duplique
/// pas, ne le retarde pas. L'utilisateur clique une fois par perso, comme il le
/// ferait à la main ; la seule chose automatisée est le changement de fenêtre,
/// qui est le métier de l'app et que ⌘@ fait déjà au clavier. Ce raccourci-ci
/// épargne la frappe, rien de plus — un clic reste un clic, et il en faut
/// toujours autant que de persos.
///
/// L'observation est **passive** (`addGlobalMonitorForEvents`), et porte sur la
/// souris seule. C'est ce qui la distingue du `CGEventTap` que
/// [HotKeyManager] refuse : rien n'est intercepté, rien n'est modifié, et le
/// clavier reste hors de vue — l'app ne voit toujours pas ce qui est tapé.
@MainActor
final class ClickAdvanceWatcher: ObservableObject {
    static let shared = ClickAdvanceWatcher()

    /// Persos déjà visités dans la passe en cours, par `slotKey`. Sert la
    /// coche affichée dans la barre.
    @Published private(set) var visited: Set<String> = []

    /// Mode amorcé : le **clic nu** enchaîne, sans modificateur.
    ///
    /// C'est la parade au cas où le client de jeu ignore les clics modifiés — ce
    /// qu'il fait, pour ⌘ au moins : le clic lui parvient, mais avec le drapeau
    /// dessus, et il ne le traite pas comme un clic ordinaire. Synfus ne peut
    /// rien y faire, il ne fait qu'observer ; retirer le modificateur de
    /// l'évènement demanderait de l'intercepter et de le réécrire, c'est-à-dire
    /// le `CGEventTap` que le projet refuse.
    ///
    /// D'où l'inversion : plutôt que de marquer chaque clic, on arme la série.
    /// Le jeu reçoit alors exactement ce qu'il attend. L'amorce retombe d'elle-
    /// même une fois le tour bouclé, pour qu'un mode oublié ne transforme pas la
    /// partie suivante en carrousel.
    @Published private(set) var armed = false

    /// Nombre de clics captés depuis l'activation, exposé au Diagnostic.
    ///
    /// C'est la réponse à la seule question que la documentation d'Apple laisse
    /// en suspens : un moniteur global de souris réclame-t-il l'autorisation
    /// « Surveillance de la saisie » ? S'il reste à zéro alors que la fonction
    /// est active et qu'on a cliqué, c'est que macOS ne nous livre rien.
    @Published private(set) var seenClicks = 0

    private var monitor: Any?

    private init() {}

    /// Aligne l'observation sur la préférence. À appeler au démarrage et à
    /// chaque bascule du réglage.
    func apply() {
        Preferences.shared.advanceOnClick ? start() : stop()
    }

    private func start() {
        guard monitor == nil else { return }
        seenClicks = 0
        // Le relâchement, et non l'appui : à ce moment le clic est entièrement
        // délivré au jeu. Prendre le focus entre l'appui et le relâchement
        // laisserait le client avec un bouton jamais relâché.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { event in
            // L'évènement ne peut pas franchir la frontière du main actor sous
            // concurrence stricte : on en tire tout de suite la seule valeur
            // utile, qui est un simple jeu de drapeaux.
            let flags = event.modifierFlags
            MainActor.assumeIsolated {
                ClickAdvanceWatcher.shared.handle(flags)
            }
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        armed = false
        if !visited.isEmpty { visited.removeAll() }
    }

    /// Amorce ou désamorce la série. Doublé d'un raccourci global : amorcer
    /// depuis la barre oblige à y emmener la souris, ce qui est précisément le
    /// geste qu'on cherche à éviter.
    func toggleArmed() {
        guard Preferences.shared.advanceOnClick else { return }
        armed.toggle()
        if armed { visited.removeAll() }
    }

    private func handle(_ flags: NSEvent.ModifierFlags) {
        let prefs = Preferences.shared
        guard prefs.advanceOnClick else { return }

        // Amorcé, c'est le clic nu qui enchaîne — celui que le jeu comprend à
        // coup sûr. Sinon, exactement le modificateur choisi et lui seul :
        // ⇧⌘-clic ne doit pas déclencher ce qu'un ⌘-clic déclenche.
        let pressed = flags.intersection(.deviceIndependentFlagsMask)
        let matches = armed ? pressed.isEmpty : pressed == prefs.advanceModifier.flag
        guard matches else { return }

        // Et seulement sur un client de jeu : ailleurs, un clic garde le sens
        // que lui donnent macOS et les autres applications.
        guard WindowManager.shared.frontmostIsDofus else { return }

        seenClicks += 1

        // Une pause fixe, le temps que le client traite le clic avant de perdre
        // le focus. Elle n'a pas d'autre rôle : ni cadence, ni variation.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
            MainActor.assumeIsolated { ClickAdvanceWatcher.shared.advance() }
        }
    }

    private static let settleDelay: TimeInterval = 0.08

    private func advance() {
        let manager = WindowManager.shared
        guard let index = manager.currentIndex else { return }

        let alive = Set(manager.clients.map(\.slotKey))
        let marked = Self.nextVisited(
            visited, leaving: manager.clients[index].slotKey, among: alive
        )
        visited = marked

        // Tour bouclé : l'amorce retombe. Un mode resté armé transformerait le
        // moindre clic de la partie suivante en changement de fenêtre.
        if armed, marked.count >= alive.count { armed = false }

        manager.cycle(by: 1)
    }

    /// État des coches au moment où l'on quitte `current`. Pure, donc testable
    /// sans clients ni fenêtres — c'est la règle qui décide de ce que la barre
    /// montre, elle mérite de l'être.
    ///
    /// Deux points valent la peine d'être fixés. Les persos fermés depuis la
    /// dernière passe sont retirés, sans quoi une passe entamée à cinq ne se
    /// solderait jamais à trois. Et lorsque tout le monde est coché, le clic
    /// suivant ouvre une passe neuve plutôt que de laisser la barre pleine :
    /// une coche qui ne s'efface jamais ne renseigne plus sur rien.
    static func nextVisited(
        _ visited: Set<String>,
        leaving current: String,
        among alive: Set<String>
    ) -> Set<String> {
        var marked = visited.intersection(alive)
        if marked.count >= alive.count { marked.removeAll() }
        marked.insert(current)
        return marked
    }

    /// Décoche tout, sans attendre la fin de la passe.
    func resetVisited() {
        guard !visited.isEmpty else { return }
        visited.removeAll()
    }
}
