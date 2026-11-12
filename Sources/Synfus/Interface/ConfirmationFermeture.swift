// « Fermer » un ou plusieurs clients : la confirmation précède le geste.

import AppKit

@MainActor
enum ConfirmationFermeture {
    /// Le geste est irréversible, et il vit dans les menus juste au-dessus de « Quitter » : on demande
    /// confirmation avant de couper une session de huit comptes sur un clic de travers.
    static func fermerTous() {
        let manager = WindowManager.shared
        let nombre = manager.processusAFermer.count
        guard nombre > 0 else { return }
        Task {
            let demande = DemandeConfirmation(titre: L("fermeture.confirmation", nombre: nombre, nombre),
                                              detail: L("fermeture.confirmation.detail"), verbe: L("menu.fermer"))
            if await Confirmation.demander(demande) { manager.closeAll() }
        }
    }

    static func fermer(_ client: DofusClient) {
        Task {
            let demande = DemandeConfirmation(titre: L("fermeture.confirmation.client", client.name),
                                              detail: L("fermeture.confirmation.detail"), verbe: L("menu.fermer"))
            if await Confirmation.demander(demande) { WindowManager.shared.close(client) }
        }
    }
}
