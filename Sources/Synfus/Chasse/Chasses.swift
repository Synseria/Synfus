import Combine
import Foundation

/// Les instances de chasse, une par perso : chacun mène la sienne — son
/// départ, sa direction, son indice, son résultat — et le panneau montre
/// celle du perso devant, qui reprend là où il en était quand on revient à
/// lui. Sans perso lu, une seule instance partagée.
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
        abonnement = LecteurEcran.shared.$persoDevant
            .removeDuplicates()
            .sink { [weak self] perso in
                MainActor.assumeIsolated { self?.basculer(perso: perso) }
            }
    }

    /// L'instance du perso devant ; une nouvelle est créée à sa première chasse.
    func basculer(perso: String?) {
        let cle = perso ?? ""
        self.perso = perso
        if parPerso[cle] == nil { parPerso[cle] = cle.isEmpty ? .shared : .nouveau() }
        courant = parPerso[cle]!
        // Une instance neuve reprend la position du perso devant comme départ.
        if courant.departX == nil { courant.reprendrePosition() }
    }

    /// Ouvre la chasse du perso devant.
    func ouvrir() {
        courant.ouvrir()
    }
}
