import AppKit
import ApplicationServices

/// Achève les clients gelés à la fermeture, même quand elle n'est pas passée
/// par Synfus.
///
/// Le scénario : l'utilisateur ferme la fenêtre du client par le jeu lui-même,
/// le processus gèle — systématiquement chez certains joueurs — et il faut
/// « Forcer à quitter » à la main. Vu d'ici, ce client est un processus vivant
/// qui ne rend plus aucune fenêtre… exactement comme un client sain dont
/// l'espace plein écran est inactif. Ce qui les distingue est la **réponse** :
/// un client sain répond à l'Accessibilité (une liste vide est une réponse),
/// un client gelé laisse la question expirer.
///
/// D'où la règle, volontairement stricte pour ne jamais abattre un vivant :
/// un processus est achevé s'il est **sans fenêtre** et **muet à trois sondes
/// consécutives** espacées d'au moins `probeInterval` — soit une quinzaine de
/// secondes de silence complet. Un client occupé qui charge une carte a une
/// fenêtre ; un dormant sain répond en quelques millisecondes.
///
/// La sonde borne son attente par `AXUIElementSetMessagingTimeout` : sans elle,
/// interroger un processus gelé bloquerait Synfus plusieurs secondes.
@MainActor
final class FreezeWatcher: ObservableObject {
    static let shared = FreezeWatcher()

    /// Un client achevé — montré dans le Diagnostic : tuer un processus est le
    /// geste le plus lourd de l'app, il doit laisser une trace.
    struct Abattu: Identifiable {
        let date: Date
        let pid: pid_t
        let nom: String
        var id: String { "\(pid)-\(date.timeIntervalSince1970)" }
    }

    @Published private(set) var journal: [Abattu] = []

    /// Espacement minimal entre deux sondes d'un même processus.
    static let probeInterval: TimeInterval = 5
    /// Sondes muettes consécutives avant le coup de grâce.
    static let strikesRequired = 3
    /// Attente maximale d'une réponse — c'est aussi le temps que Synfus accepte
    /// de bloquer sur un processus gelé, une fois toutes les `probeInterval`.
    static let probeTimeout: Float = 0.3

    private var strikes: [pid_t: Int] = [:]
    private var lastProbe: [pid_t: Date] = [:]

    private init() {}

    /// À appeler après chaque inventaire, avec les processus vivants qui ne
    /// rendent aucune fenêtre et un nom à mettre au journal le cas échéant.
    func inspect(silentPIDs: Set<pid_t>, names: [pid_t: String]) {
        // Un processus redevenu bavard ou disparu repart de zéro.
        strikes = strikes.filter { silentPIDs.contains($0.key) }
        lastProbe = lastProbe.filter { silentPIDs.contains($0.key) }

        for pid in silentPIDs {
            if let derniere = lastProbe[pid],
               Date().timeIntervalSince(derniere) < Self.probeInterval { continue }
            lastProbe[pid] = Date()

            if responds(pid) {
                strikes[pid] = 0
                continue
            }

            let compte = strikes[pid, default: 0] + 1
            strikes[pid] = compte
            guard compte >= Self.strikesRequired else { continue }

            NSRunningApplication(processIdentifier: pid)?.forceTerminate()
            journal.append(Abattu(date: Date(), pid: pid,
                                  nom: names[pid] ?? "pid \(pid)"))
            strikes[pid] = nil
            lastProbe[pid] = nil
        }
    }

    /// Le processus répond-il encore à l'Accessibilité ? La question posée est
    /// `kAXWindows` — la même que l'inventaire — et une liste vide vaut oui :
    /// seule l'expiration du délai vaut non.
    private func responds(_ pid: pid_t) -> Bool {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.probeTimeout)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
        return error != .cannotComplete
    }
}
