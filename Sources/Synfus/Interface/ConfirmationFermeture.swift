// « Fermer tous les persos », précédé du seul dernier mot que l'app demande.

import AppKit

@MainActor
enum ConfirmationFermeture {
    /// Le geste est irréversible, et il vit dans les menus juste au-dessus de
    /// « Quitter » : on demande confirmation avant de couper une session de
    /// huit comptes sur un clic de travers.
    static func fermerTous() {
        let manager = WindowManager.shared
        let nombre = manager.processusAFermer.count
        guard nombre > 0, confirmer(nombre: nombre) else { return }
        manager.closeAll()
    }

    private static func confirmer(nombre: Int) -> Bool {
        let alerte = NSAlert()
        alerte.messageText = L("fermeture.confirmation", nombre: nombre, nombre)
        alerte.informativeText = L("fermeture.confirmation.detail")
        alerte.alertStyle = .warning
        let fermer = alerte.addButton(withTitle: L("menu.fermerTous"))
        let annuler = alerte.addButton(withTitle: L("commun.annuler"))
        // Entrée annule : le joueur qui tape Entrée pour ouvrir le tchat au
        // moment où l'alerte paraît ne doit pas fermer ses huit comptes.
        fermer.keyEquivalent = ""
        fermer.hasDestructiveAction = true
        annuler.keyEquivalent = "\r"
        // L'app tourne en accessory : sans activation, l'alerte s'ouvrirait
        // derrière le jeu, et Synfus paraîtrait ne rien faire.
        NSApp.activate(ignoringOtherApps: true)
        return alerte.runModal() == .alertFirstButtonReturn
    }
}
