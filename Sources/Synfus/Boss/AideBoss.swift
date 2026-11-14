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
    /// La fiche DofusDB de chaque boss déjà demandée, par monstre (`chargerFiche`).
    @Published private(set) var fiches: [Int: FicheCombat] = [:]

    /// Le dernier état de combat vu de chaque perso.
    private var combatsVus: [String: EtatCombat] = [:]
    private var abonnement: AnyCancellable?
    private var abonnementSalle: AnyCancellable?
    private var abonnementDonjons: AnyCancellable?
    /// La dernière zone lue du perso devant, relue quand la liste des donjons arrive.
    private var zone: String?
    /// Le donjon où la dernière position lue a mis le perso devant : son boss
    /// n'est choisi qu'en y entrant, un choix à la main dedans tient.
    private var donjonIci: Int?
    private var ficheDemandee: Set<Int> = []

    private init() {
        // Les valeurs émises, pas la propriété : `@Published` publie avant
        // d'affecter.
        abonnement = LecteurEcran.shared.$combats.sink { [weak self] combats in
            MainActor.assumeIsolated { self?.combats(combats) }
        }
        abonnementSalle = LecteurEcran.shared.$positions.sink { [weak self] positions in
            MainActor.assumeIsolated {
                let perso = LecteurEcran.shared.persoDevant
                self?.lire(zone: perso.flatMap { positions[$0] }?.zone)
            }
        }
        abonnementDonjons = DonjonsStore.shared.$donjons.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                self?.memoriserNom()
                self?.lire(zone: self?.zone)
            }
        }
    }

    /// Entrer dans un donjon choisit son boss : le panneau, ouvert ou rouvert,
    /// montre le bon. Jamais d'ouverture d'office. La liste des donjons se
    /// demande à la première zone lue.
    private func lire(zone: String?) {
        self.zone = zone
        guard let donjons = DonjonsStore.shared.donjons else {
            if zone != nil { DonjonsStore.shared.charger() }
            return
        }
        let ici = donjons.donjon(zone: zone)
        guard ici?.id != donjonIci else { return }
        donjonIci = ici?.id
        guard let ici, let premier = ici.boss.first else { return }
        let cible = CibleBoss.boss(premier, donjon: ici.id)
        if cible != boss { choisir(cible) }
    }

    /// Demande une fois par lancement la fiche DofusDB du boss ; muette en
    /// cas d'échec (la mécanique se passe d'elle).
    func chargerFiche(_ boss: CibleBoss) {
        let monstre = boss.monstre
        guard ficheDemandee.insert(monstre).inserted else { return }
        Task {
            guard let fiche = try? await FicheCombat.telecharger(monstre: monstre) else {
                ficheDemandee.remove(monstre)
                return
            }
            fiches[monstre] = fiche
        }
    }

    var boss: CibleBoss { Preferences.shared.bossChoisi }

    /// Le donjon du boss suivi : le sien pour un boss de donjon, celui que
    /// DofusDB lui donne pour un boss à mécanique.
    var donjon: Donjon? {
        let donjons = DonjonsStore.shared.donjons
        switch boss {
        case .special(let special): return donjons?.donjon(boss: special.monstre)
        case .donjon(_, let id): return donjons?.donjon(id: id)
        }
    }

    func choisir(_ boss: CibleBoss) {
        Preferences.shared.enUneEcriture {
            Preferences.shared.bossChoisi = boss
            Preferences.shared.nomsBossChoisi = boss.nomsDonjon(dans: DonjonsStore.shared.donjons)
        }
        BossPanel.shared.revoirLectures()
    }

    /// La liste des donjons arrivée, le nom du boss de donjon suivi est gardé
    /// pour titrer le panneau à la prochaine ouverture, hors ligne.
    private func memoriserNom() {
        guard let noms = boss.nomsDonjon(dans: DonjonsStore.shared.donjons),
              noms != Preferences.shared.nomsBossChoisi else { return }
        Preferences.shared.nomsBossChoisi = noms
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
        guard boss == .special(.harebourg), let vie = Harebourg.vie(lignes) else { return }
        suivi.vie(vie, perso: perso, le: Date())
    }

    func recevoirTchat(_ lignes: [String], perso: String) {
        switch boss.special {
        case .harebourg:
            let noms = WindowManager.shared.clients.map(\.name)
            suivi.tchat(lignes, fenetre: perso, persos: noms, le: Date())
        case .kimbo:
            if let etat = Kimbo.etat(lignes), etat != session.kimbo { session.kimbo = etat }
        case .toxoliath, .ilyzaelle, .talKasha, nil:
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

    /// Ce que le combat en cours a laissé : un tour compté, ou une note.
    var aDuNote: Bool { tour != nil || session != SessionBoss() }

    /// Repartir d'un panneau propre quand Synfus n'a pas lu le placement.
    func nouveauCombat() {
        session = SessionBoss()
        pourLePersoDevant { tours.recommencer(perso: $0) }
    }

    /// Un geste qui note quelque chose du combat en cours.
    func noter(_ modifier: (inout SessionBoss, Int?) -> Void) {
        var nouvelle = session
        modifier(&nouvelle, tour)
        if nouvelle != session { session = nouvelle }
    }
}
