// Fermeture des clients — l’escalade de `ClientTerminator`, un processus à la fois.

import AppKit

extension WindowManager {
    /// Ferme un client — l'escalade de `ClientTerminator`.
    ///
    /// Le client gèle systématiquement à la fermeture chez certains joueurs, et
    /// il faut alors passer par « Forcer à quitter » : on automatise ce geste.
    func close(_ client: DofusClient) {
        let pid = client.pid
        guard NSRunningApplication(processIdentifier: pid) != nil else { return }
        closingPIDs.insert(pid)
        // La pastille reste affichée le temps de la fermeture (cf. la mémoire),
        // mais son aperçu, lui, n'a plus lieu d'être : on le retire tout de
        // suite plutôt que d'attendre un `mouseExited` que le menu contextuel a
        // déjà consommé.
        PreviewPanelController.shared.reconcile(with: clients.filter { $0.pid != pid })

        ClientTerminator.close(pid) { WindowManager.shared.refreshSoon() }
        refreshSoon()
    }

    /// Les processus qu'un « Fermer tous » viserait : ceux des persos
    /// affichés, moins ceux déjà en cours de fermeture.
    var processusAFermer: Set<pid_t> {
        Set(clients.map(\.pid)).subtracting(closingPIDs)
    }

    /// Ferme tous les clients, chacun avec la même escalade. Le geste de fin
    /// de session — sans lui, c'est autant de « Forcer à quitter » que de persos.
    /// La confirmation appartient à l'interface (`ConfirmationFermeture`).
    ///
    /// Un **processus** à la fois : `clients` porte un perso par fenêtre, et
    /// deux persos d'un même client auraient déclenché deux escalades sur le
    /// même pid — deux Apple Events, deux échéances, deux coups de grâce.
    func closeAll() {
        let pids = processusAFermer
        guard !pids.isEmpty else { return }
        for client in clients where pids.contains(client.pid) && !closingPIDs.contains(client.pid) {
            close(client)
        }
    }
}
