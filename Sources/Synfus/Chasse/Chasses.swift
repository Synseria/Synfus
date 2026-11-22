import Combine
import Foundation

/// Les instances de chasse, une par perso : chacun mène la sienne — son
/// départ, sa direction, son indice, son résultat — et le panneau montre
/// celle du perso devant, qui reprend là où il en était quand on revient à
/// lui. Le perso devant vient de `WindowManager` (fenêtre au premier plan) :
/// la bascule y est immédiate, sans attendre le prochain tour de lecture.
/// Hors Dofus devant (réglages ouverts, autre app), l'instance courante reste.
@MainActor
final class Chasses: ObservableObject {
    static let shared = Chasses()

    /// L'instance montrée : celle du perso devant.
    @Published private(set) var courant: ChasseModele
    /// Le perso dont `courant` est l'instance (`nil` : l'instance partagée).
    @Published private(set) var perso: String?
    /// Une instance par perso, gérée pour la session.
    private var parPerso: [String: ChasseModele] = [:]
    private var abonnement: AnyCancellable?

    private init() {
        courant = .shared
        parPerso[""] = .shared
        let manager = WindowManager.shared
        abonnement = Publishers.CombineLatest3(manager.$frontmostPID, manager.$clients, manager.$frontmostIsDofus)
            .map { pid, clients, isDofus -> String? in
                guard isDofus, let pid else { return nil }
                return clients.first(where: { $0.pid == pid })?.name
            }
            .removeDuplicates()
            .sink { [weak self] perso in
                // `nil` : une autre app est devant — on garde le perso en cours.
                guard let perso else { return }
                MainActor.assumeIsolated { self?.basculer(perso: perso) }
            }
    }

    /// L'instance du perso devant ; une nouvelle est créée à sa première chasse.
    func basculer(perso: String?) {
        let cle = perso ?? ""
        self.perso = perso
        if parPerso[cle] == nil { parPerso[cle] = cle.isEmpty ? .shared : .nouveau() }
        courant = parPerso[cle]!
        // Une instance neuve reprend la position du perso devant comme départ,
        // lue à l'occasion si elle n'est pas connue.
        if courant.departX == nil { courant.reprendrePositionSiInconnue() }
    }

    /// Ouvre la chasse du perso devant.
    func ouvrir() {
        courant.ouvrir()
    }
}
