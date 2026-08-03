import AppKit

/// Mode « enchaîner » : tant qu'il est actif, chaque clic sur un client de jeu
/// passe au perso suivant une fois le clic délivré.
///
/// Synfus **n'émet, ne rejoue et ne duplique aucun évènement**. Un clic reste un
/// clic, et il en faut toujours autant que de persos ; la seule chose
/// automatisée est le changement de fenêtre, que `cycleNext` fait déjà au
/// clavier. Un clic qui produirait N actions serait un multiplicateur, ce que
/// les conditions d'utilisation de Dofus interdisent — et ce que le dépôt refuse
/// au même titre qu'il refuse d'embarquer les visuels d'Ankama.
///
/// **Le clic est nu, et ce n'est pas un détail.** Une première version demandait
/// un clic modifié, ⌘-clic, pour n'agir que sur ces clics-là. Le client de jeu
/// reçoit bien ces clics, mais avec le drapeau dessus, et ne les traite pas
/// comme des clics ordinaires : déplacer un perso passait, parler à un PNJ non.
/// Synfus ne pouvait rien y faire — il observe, il ne réécrit pas ; retirer le
/// modificateur demanderait exactement le `CGEventTap` que le projet refuse.
/// D'où l'inversion : c'est le **mode** qui porte l'intention, et le jeu reçoit
/// le clic qu'il attend.
///
/// L'observation est passive (`addGlobalMonitorForEvents`) et porte sur la
/// souris seule : rien n'est intercepté, rien n'est modifié, et le clavier reste
/// hors de vue — l'app ne voit toujours pas ce qui est tapé.
@MainActor
final class ClickAdvanceWatcher: ObservableObject {
    static let shared = ClickAdvanceWatcher()

    /// Mode actif. Bascule franche : il reste ce qu'on en a fait jusqu'à ce
    /// qu'on le rebascule. La flèche verte de la barre est là pour qu'on ne
    /// l'oublie pas.
    @Published private(set) var armed = false

    /// Persos déjà visités depuis l'activation du mode, par `slotKey`. Sert la
    /// coche affichée dans la barre.
    @Published private(set) var visited: Set<String> = []

    /// Nombre de clics captés depuis l'activation, exposé aux réglages.
    ///
    /// C'est la réponse à la seule question que la documentation d'Apple laisse
    /// en suspens : un moniteur global de souris réclame-t-il l'autorisation
    /// « Surveillance de la saisie » ? S'il reste à zéro alors que le mode est
    /// actif et qu'on a cliqué, c'est que macOS ne nous livre rien.
    @Published private(set) var seenClicks = 0

    private var monitor: Any?

    private init() {}

    /// Aligne l'observation sur la préférence. À appeler au démarrage et à
    /// chaque bascule du réglage.
    func apply() {
        Preferences.shared.advanceOnClick ? start() : stop()
    }

    /// Active ou coupe le mode. Doublé d'un raccourci global : basculer depuis
    /// la barre oblige à y emmener la souris, ce qui est précisément le geste
    /// qu'on cherche à éviter.
    func toggleArmed() {
        guard Preferences.shared.advanceOnClick else { return }
        armed.toggle()
        visited.removeAll()
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
        visited.removeAll()
    }

    private func handle(_ flags: NSEvent.ModifierFlags) {
        guard armed, Preferences.shared.advanceOnClick else { return }

        // Un clic nu, et lui seul : ⌘-clic, ⌥-clic et consorts gardent partout
        // le sens que leur donnent macOS et le jeu.
        guard flags.intersection(.deviceIndependentFlagsMask).isEmpty else { return }

        // Et seulement sur un client de jeu : ailleurs, un clic reste un clic.
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
        guard armed, let index = manager.currentIndex else { return }

        visited = Self.nextVisited(
            visited,
            leaving: manager.clients[index].slotKey,
            among: Set(manager.clients.map(\.slotKey))
        )
        manager.cycle(by: 1)
    }

    /// État des coches au moment où l'on quitte `current`. Pure, donc testable
    /// sans clients ni fenêtres — c'est la règle qui décide de ce que la barre
    /// montre, elle mérite de l'être.
    ///
    /// Deux points valent la peine d'être fixés. Les persos fermés depuis le
    /// début du tour sont retirés, sans quoi un tour entamé à cinq ne se
    /// solderait jamais à trois. Et lorsque tout le monde est coché, le clic
    /// suivant ouvre un tour neuf plutôt que de laisser la barre pleine : une
    /// coche qui ne s'efface jamais ne renseigne plus sur rien.
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

    /// Décoche tout, sans attendre la fin du tour.
    func resetVisited() {
        guard !visited.isEmpty else { return }
        visited.removeAll()
    }
}
