import Combine
import Foundation

/// L'aide aux boss : reçoit les lectures de l'écran (`LecteurEcran`, tant que
/// `BossPanel` est montré) et les gestes du panneau, compte les tours, tient
/// le `SuiviConfusion` du Comte et la `SessionBoss` du combat en cours.
/// Synfus ne fait que lire et afficher : viser et lancer restent au joueur.
@MainActor
final class AideBoss: ObservableObject {
    static let shared = AideBoss()

    @Published private(set) var suivi = SuiviConfusion()
    @Published private(set) var tours = ToursCombat()
    @Published private(set) var session = SessionBoss()

    /// Le dernier état de combat vu de chaque perso.
    private var combatsVus: [String: EtatCombat] = [:]
    private var abonnement: AnyCancellable?

    private init() {
        // Les valeurs émises, pas la propriété : `@Published` publie avant
        // d'affecter.
        abonnement = LecteurEcran.shared.$combats.sink { [weak self] combats in
            MainActor.assumeIsolated { self?.combats(combats) }
        }
    }

    var boss: Boss { Preferences.shared.bossChoisi }

    func choisir(_ boss: Boss) {
        Preferences.shared.bossChoisi = boss
        BossPanel.shared.revoirLectures()
    }

    /// La confusion du perso devant, celui que le joueur joue.
    var estimation: SuiviConfusion.Estimation? {
        LecteurEcran.shared.persoDevant.flatMap { suivi.estimation($0) }
    }

    var vieLue: Harebourg.Vie? {
        LecteurEcran.shared.persoDevant.flatMap { suivi.vieLue($0) }
    }

    /// Le tour du combat, compté chez le perso devant.
    var tour: Int? {
        LecteurEcran.shared.persoDevant.flatMap { tours.tour($0) }
    }

    // MARK: - Lectures

    func recevoirVie(_ lignes: [String], perso: String) {
        guard boss == .harebourg, let vie = Harebourg.vie(lignes) else { return }
        suivi.vie(vie, perso: perso, le: Date())
    }

    func recevoirTchat(_ lignes: [String], perso: String) {
        switch boss {
        case .harebourg:
            let noms = WindowManager.shared.clients.map(\.name)
            suivi.tchat(lignes, fenetre: perso, persos: noms, le: Date())
        case .kimbo:
            if let etat = Kimbo.etat(lignes), etat != session.kimbo { session.kimbo = etat }
        case .toxoliath, .ilyzaelle, .talKasha:
            break
        }
    }

    private func combats(_ combats: [String: EtatCombat]) {
        let maintenant = Date()
        for (perso, etat) in combats where combatsVus[perso] != etat {
            let avant = combatsVus[perso]
            // Un placement ouvre un combat. Pas une première lecture en combat :
            // chaque perso est lu quand il passe devant, souvent bien après.
            if etat == .placement, avant != .placement { session = SessionBoss() }
            suivi.combat(perso, avant: avant, apres: etat, le: maintenant)
            tours.combat(perso, avant: avant, apres: etat)
        }
        combatsVus = combats
    }

    // MARK: - Gestes du panneau

    private func pourLePersoDevant(_ geste: (String) -> Void) {
        guard let perso = LecteurEcran.shared.persoDevant else { return }
        geste(perso)
    }

    func coup(_ pas: Int) { pourLePersoDevant { suivi.coup(pas, perso: $0) } }

    func choisir(_ confusion: Harebourg.Confusion?) { pourLePersoDevant { suivi.choisir(confusion, perso: $0) } }

    func corrigerTour(_ pas: Int) { pourLePersoDevant { tours.corriger(pas, perso: $0) } }

    /// Un geste qui note quelque chose du combat en cours.
    func noter(_ modifier: (inout SessionBoss, Int?) -> Void) {
        var nouvelle = session
        modifier(&nouvelle, tour)
        if nouvelle != session { session = nouvelle }
    }
}
