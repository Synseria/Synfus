import ApplicationServices

/// Une fenêtre de client Dofus, c'est-à-dire un perso connecté.
struct DofusClient: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let slotKey: String
    /// Poignée de la fenêtre — ou de l'application pour un dormant. Traverse
    /// la frontière de l'acteur d'inventaire, d'où `AXHandle`.
    let axWindow: AXHandle
    let rawTitle: String
    let name: String
    /// Classe du perso, lue dans le titre de la fenêtre
    /// (« Syn-App - Feca - 3.6.7.7 - Release » → « Feca »).
    let characterClass: String?
    /// Perso connu de mémoire, dont l'Accessibilité ne rend plus la fenêtre —
    /// en pratique, un client dans un espace plein écran qui n'est pas actif.
    /// Il reste cliquable : l'activation du processus suffit à y basculer.
    let dormant: Bool

    var id: String { slotKey }

    /// Le même perso, tel qu'on se le rappelle une fois sa fenêtre hors de vue.
    func remembered() -> DofusClient {
        DofusClient(
            pid: pid, slotKey: slotKey, axWindow: axWindow, rawTitle: rawTitle,
            name: name, characterClass: characterClass, dormant: true
        )
    }

    static func == (lhs: DofusClient, rhs: DofusClient) -> Bool {
        lhs.slotKey == rhs.slotKey && lhs.name == rhs.name && lhs.dormant == rhs.dormant
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(slotKey)
    }
}
