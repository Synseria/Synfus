// Équipes : l’effectif, `clients` restreint à l’équipe active.

import AppKit

extension WindowManager {
    // MARK: - Équipes

    /// Le seul foyer de calcul de l'effectif. Les équipes sont passées
    /// explicitement par l'abonnement aux préférences — qui les reçoit avant
    /// qu'elles soient affectées — et lues sinon. Un index d'équipe devenu
    /// orphelin ramène à « Tous ».
    func republierEffectif(equipes: [Equipe]? = nil) {
        let equipes = equipes ?? prefs.equipes
        let active = Equipes.activeValide(equipeActive, nombre: equipes.count)
        if active != equipeActive { equipeActive = active }
        let nouveau = Equipes.filtre(clients, equipe: active.map { equipes[$0] })
        if nouveau != effectif { effectif = nouveau }
    }

    /// Active une équipe — `nil` pour « Tous ». Sans effet si l'index n'existe pas.
    func activerEquipe(_ index: Int?) {
        let borne = Equipes.activeValide(index, nombre: prefs.equipes.count)
        guard borne == index else { return }
        equipeActive = index
        republierEffectif()
    }

    /// Tous → 1 → … → Tous, le geste du raccourci.
    func equipeSuivante() {
        activerEquipe(Equipes.suivante(apres: equipeActive, nombre: prefs.equipes.count))
    }
}
