import Combine
import Foundation

/// L'aide au combat contre le Comte Harebourg : reçoit les lectures de
/// l'écran (`LecteurEcran`, tant que `BossPanel` est montré) et les gestes du
/// panneau, tient le `SuiviConfusion` de chaque perso. Synfus ne fait que
/// lire et afficher : viser et lancer restent au joueur.
@MainActor
final class AideBoss: ObservableObject {
    static let shared = AideBoss()

    @Published private(set) var suivi = SuiviConfusion()

    /// Le dernier état de combat vu de chaque perso : seul un changement de
    /// tour compte.
    private var combatsVus: [String: EtatCombat] = [:]
    private var abonnement: AnyCancellable?

    private init() {
        // Les valeurs émises, pas la propriété : `@Published` publie avant
        // d'affecter.
        abonnement = LecteurEcran.shared.$combats.sink { [weak self] combats in
            MainActor.assumeIsolated { self?.combats(combats) }
        }
    }

    /// La confusion du perso devant, celui que le joueur joue.
    var estimation: SuiviConfusion.Estimation? {
        LecteurEcran.shared.persoDevant.flatMap { suivi.estimation($0) }
    }

    var vieLue: Harebourg.Vie? {
        LecteurEcran.shared.persoDevant.flatMap { suivi.vieLue($0) }
    }

    // MARK: - Lectures

    func recevoirVie(_ lignes: [String], perso: String) {
        guard let vie = Harebourg.vie(lignes) else { return }
        suivi.vie(vie, perso: perso, le: Date())
    }

    func recevoirTchat(_ lignes: [String], perso: String) {
        let noms = WindowManager.shared.clients.map(\.name)
        suivi.tchat(lignes, fenetre: perso, persos: noms, le: Date())
    }

    private func combats(_ combats: [String: EtatCombat]) {
        let maintenant = Date()
        for (perso, etat) in combats where combatsVus[perso].map({ !Self.memeGenre($0, etat) }) ?? true {
            suivi.combat(perso, etat: etat, le: maintenant)
        }
        combatsVus = combats
    }

    /// L'échéance d'un tour change à chaque relecture du décompte : le tour,
    /// lui, est le même.
    private static func memeGenre(_ a: EtatCombat, _ b: EtatCombat) -> Bool {
        switch (a, b) {
        case (.monTour, .monTour): return true
        default: return a == b
        }
    }

    // MARK: - Gestes du panneau

    func coup(_ pas: Int) {
        guard let perso = LecteurEcran.shared.persoDevant else { return }
        suivi.coup(pas, perso: perso)
    }

    func choisir(_ confusion: Harebourg.Confusion?) {
        guard let perso = LecteurEcran.shared.persoDevant else { return }
        suivi.choisir(confusion, perso: perso)
    }
}
