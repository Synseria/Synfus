// « Fermer » un ou plusieurs clients : la confirmation précède le geste.

import AppKit
import SynseriaDesign

@MainActor
enum ConfirmationFermeture {
    /// Le geste est irréversible, et il vit dans les menus juste au-dessus de « Quitter » : on demande
    /// confirmation avant de couper une session de huit comptes sur un clic de travers.
    static func fermerTous() {
        let manager = WindowManager.shared
        let nombre = manager.processusAFermer.count
        guard nombre > 0 else { return }
        if confirmer(L("fermeture.confirmation", nombre: nombre, nombre)) { manager.closeAll() }
    }

    static func fermer(_ client: DofusClient) {
        if confirmer(L("fermeture.confirmation.client", client.name)) { WindowManager.shared.close(client) }
    }

    private static func confirmer(_ titre: String) -> Bool {
        ConfirmationHorsVue.demander(titre: titre, detail: L("fermeture.confirmation.detail"), verbe: L("menu.fermer"))
    }
}

/// Un geste destructif lancé hors de toute vue (un menu, un panneau posé sur le jeu) : l'alerte de la
/// trousse (`Confirmation.demander`), au premier plan. Synfus est une app de barre de menus : sans
/// activation, l'alerte s'ouvrirait derrière le jeu.
@MainActor
enum ConfirmationHorsVue {
    static func demander(titre: String, detail: String? = nil, verbe: String) -> Bool {
        NSApp.activate()
        return Confirmation.demander(titre: titre, detail: detail, verbe: verbe, annuler: L("commun.annuler"))
    }
}
