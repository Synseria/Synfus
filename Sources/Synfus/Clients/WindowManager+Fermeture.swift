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

    /// Ferme tous les clients, chacun avec la même escalade. Le geste de fin
    /// de session — sans lui, c'est autant de « Forcer à quitter » que de persos.
    ///
    /// Un **processus** à la fois : `clients` porte un perso par fenêtre, et
    /// deux persos d'un même client auraient déclenché deux escalades sur le
    /// même pid — deux Apple Events, deux échéances, deux coups de grâce.
    ///
    /// Le geste est irréversible, et il vit dans les menus juste au-dessus de
    /// « Quitter » : on demande confirmation avant de couper une session de
    /// huit comptes sur un clic de travers.
    func closeAll() {
        let pids = Set(clients.map(\.pid)).subtracting(closingPIDs)
        guard !pids.isEmpty else { return }
        guard confirmerFermeture(nombre: pids.count) else { return }
        for client in clients where pids.contains(client.pid) && !closingPIDs.contains(client.pid) {
            close(client)
        }
    }

    /// L'alerte de « Fermer tous les persos ». Séparée pour que `closeAll`
    /// reste lisible, et parce que c'est le seul endroit de l'app qui demande
    /// un dernier mot.
    private func confirmerFermeture(nombre: Int) -> Bool {
        let alerte = NSAlert()
        alerte.messageText = L("fermeture.confirmation", nombre)
        alerte.informativeText = L("fermeture.confirmation.detail")
        alerte.alertStyle = .warning
        alerte.addButton(withTitle: L("menu.fermerTous"))
        alerte.addButton(withTitle: L("commun.annuler"))
        // L'app tourne en accessory : sans activation, l'alerte s'ouvrirait
        // derrière le jeu, et Synfus paraîtrait ne rien faire.
        NSApp.activate(ignoringOtherApps: true)
        return alerte.runModal() == .alertFirstButtonReturn
    }
}
