import AppKit

/// Enchaîner les persos au clic : un clic sur un client de jeu, une touche
/// tenue (`ClickModifier`, `fn` par défaut), et Synfus passe au perso suivant
/// une fois le clic relâché — comme si l'on avait pressé « perso suivant ».
///
/// Synfus **n'émet, ne rejoue et ne duplique aucun évènement**. Un clic reste un
/// clic, et il en faut toujours autant que de persos ; la seule chose
/// automatisée est le changement de fenêtre, que `cycleNext` fait déjà au
/// clavier. Un clic qui produirait N actions serait un multiplicateur, ce que
/// les conditions d'utilisation de Dofus interdisent — et ce que le dépôt refuse
/// au même titre qu'il refuse d'embarquer les visuels d'Ankama.
///
/// **C'est la touche qui porte l'intention, pas un mode.** La version
/// précédente était une bascule : mode actif, chaque clic nu enchaînait,
/// jusqu'à ce qu'on le coupe. À l'usage, personne ne s'en servait — on oubliait
/// de l'armer, on oubliait de le couper, et un clic anodin changeait de
/// fenêtre. Ici rien n'est armé : le geste dit ce qu'il veut, un clic ordinaire
/// reste un clic ordinaire.
///
/// Le jeu reçoit le clic **avec la touche dessus** — Synfus observe, il ne
/// réécrit pas ; retirer la touche de l'évènement demanderait exactement le
/// `CGEventTap` que le projet refuse. D'où `fn` par défaut : c'est la seule
/// touche que ni le jeu ni macOS n'interprètent sur un clic, là où un ⌘-clic,
/// mesuré, ne parlait plus aux PNJ.
///
/// L'observation est passive (`addGlobalMonitorForEvents`) et porte sur la
/// souris seule : rien n'est intercepté, rien n'est modifié, et le clavier reste
/// hors de vue — la touche tenue est lue sur les drapeaux du clic lui-même,
/// l'app ne voit toujours pas ce qui est tapé.
@MainActor
final class ClickAdvanceWatcher: ObservableObject {
    static let shared = ClickAdvanceWatcher()

    /// Nombre de clics captés sur un client de jeu depuis l'activation, touche
    /// tenue ou non, exposé aux réglages.
    ///
    /// C'est la réponse à la seule question que la documentation d'Apple laisse
    /// en suspens : un moniteur global de souris réclame-t-il l'autorisation
    /// « Surveillance de la saisie » ? S'il reste à zéro alors qu'on a cliqué
    /// dans le jeu, c'est que macOS ne nous livre rien.
    @Published private(set) var seenClicks = 0

    /// Les touches tenues au dernier clic capté — « fn », « ⌥ », « aucune ».
    /// C'est ainsi qu'on vérifie que ce clavier-là fait bien voir `fn` à macOS.
    @Published private(set) var lastModifiers: String?

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
        lastModifiers = nil
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
    }

    private func handle(_ flags: NSEvent.ModifierFlags) {
        let prefs = Preferences.shared
        guard prefs.advanceOnClick else { return }

        // Seulement sur un client de jeu : ailleurs, un clic reste un clic.
        guard WindowManager.shared.frontmostIsDofus else { return }

        seenClicks += 1
        lastModifiers = ClickModifier.describe(flags)

        // La touche choisie, et elle seule : ⌘-clic, ⇧-clic et consorts gardent
        // partout le sens que leur donnent macOS et le jeu.
        guard prefs.advanceModifier.isHeldAlone(in: flags) else { return }

        // Une pause fixe, le temps que le client traite le clic avant de perdre
        // le focus. Elle n'a pas d'autre rôle : ni cadence, ni variation.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
            MainActor.assumeIsolated { WindowManager.shared.cycle(by: 1) }
        }
    }

    private static let settleDelay: TimeInterval = 0.08
}
