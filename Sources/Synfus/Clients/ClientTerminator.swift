import AppKit

/// L'unique escalade de fermeture d'un client : poliment d'abord, de force
/// s'il ne répond plus. `WindowManager.close` et `FreezeWatcher` passent tous
/// deux ici — deux copies de cette escalade, c'est une correction sur l'une
/// que l'autre n'a pas.
///
/// C'est une opération de **processus**, pas une saisie : la règle « Synfus
/// n'émet aucun évènement » reste entière.
@MainActor
enum ClientTerminator {

    /// Délai de grâce entre la demande polie et le coup de grâce. Mesuré à
    /// l'usage : un client sain s'éteint bien avant 2 s, et un client gelé ne
    /// changera pas d'avis — attendre 6 s ne faisait que ralentir le geste.
    static let gracePeriod: TimeInterval = 2

    /// Quit Apple Event (`terminate()`), puis `forceTerminate()` si le
    /// processus est toujours là à l'échéance — un client gelé ignore les
    /// Apple Events. `onDeadline` est appelé à l'échéance, que le coup de grâce
    /// ait été nécessaire ou non.
    ///
    /// L'envoi du Quit Apple Event peut bloquer plusieurs secondes quand le
    /// client est déjà gelé — c'est lui qui figeait Synfus au moment de
    /// fermer. Il part donc d'un fil secondaire ; le coup de grâce, lui, est un
    /// signal, il ne bloque jamais.
    static func close(_ pid: pid_t, onDeadline: @escaping @MainActor () -> Void) {
        Task.detached(priority: .userInitiated) {
            NSRunningApplication(processIdentifier: pid)?.terminate()
        }
        Timer.scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { _ in
            MainActor.assumeIsolated {
                kill(pid)
                onDeadline()
            }
        }
    }

    /// Le coup de grâce seul — SIGKILL, jamais bloquant. Sans effet si le
    /// processus est déjà mort.
    static func kill(_ pid: pid_t) {
        guard let survivant = NSRunningApplication(processIdentifier: pid),
              !survivant.isTerminated
        else { return }
        survivant.forceTerminate()
    }
}
