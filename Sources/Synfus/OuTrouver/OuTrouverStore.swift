import Foundation

/// Où trouver ce que demandent les quêtes : relu du disque à la première
/// demande, demandé à DofusDB pour un monstre ou un objet encore inconnu, ou
/// vu il y a plus de trente jours — qu'on montre en attendant. Un échec
/// garde ce qui est là. Et le trajet vers le repaire le plus proche.
@MainActor
final class OuTrouverStore: ObservableObject {
    static let shared = OuTrouverStore()

    @Published private(set) var cache = CacheOuTrouver()
    @Published private(set) var enCours: Set<OuTrouver.Sujet> = []
    @Published private(set) var echecs: Set<OuTrouver.Sujet> = []
    private var lu = false
    /// La demande en cours de chaque sujet, qu'attend `charge`.
    private var demandes: [OuTrouver.Sujet: Task<Void, Never>] = [:]

    private init() {}

    /// Lus tels quels : c'est `demander`, à l'apparition de la vue, qui relit
    /// le disque — une vue ne publie rien pendant qu'elle se dessine.
    func monstre(_ id: Int) -> FicheMonstre? {
        cache.monstres[String(id)]?.valeur
    }

    func objet(_ id: Int) -> SourcesObjet? {
        cache.objets[String(id)]?.valeur
    }

    /// Demande le sujet à DofusDB s'il manque ou a vieilli.
    func demander(_ sujet: OuTrouver.Sujet) {
        relire()
        guard demandes[sujet] == nil, DofusDB.perimee(depuis: date(sujet), maintenant: Date()) else { return }
        enCours.insert(sujet)
        echecs.remove(sujet)
        demandes[sujet] = Task {
            do {
                switch sujet {
                case .monstre(let id): ranger(monstre: try await OuTrouverDofusDB.monstre(id))
                case .objet(let id): ranger(objet: id, try await OuTrouverDofusDB.objet(id))
                }
                try? cache.garder()
            } catch {
                echecs.insert(sujet)
            }
            enCours.remove(sujet)
            demandes[sujet] = nil
        }
    }

    /// Le monstre, après la demande s'il le faut — pour copier tout de suite
    /// le trajet d'un objectif.
    func monstreCharge(_ id: Int) async -> FicheMonstre? {
        demander(.monstre(id))
        if monstre(id) == nil { await demandes[.monstre(id)]?.value }
        return monstre(id)
    }

    // MARK: - Repaires

    /// De quoi situer les repaires depuis la position du perso, le plus
    /// proche d'abord — carte et réglages lus une fois pour tous.
    func situeur(depuis perso: PositionCarte?) -> (FicheMonstre) -> [RepaireSitue] {
        let depart = ItineraireZaap.rejoindre(perso)
        let reseau = CarteStore.shared.reseau, lieux = CarteStore.shared.carte.lieux
        let cout = ZaapClipboard.shared.cout(depuis: perso)
        return { fiche in
            OuTrouver.situes(fiche.repaires, depuis: depart, reseau: reseau, lieux: lieux, cartes: { cout?($0) })
        }
    }

    /// Copie le trajet vers le repaire, zaap compris dans le Monde des Douze.
    func copierTrajet(_ repaire: RepaireSitue) {
        ZaapClipboard.shared.copierTrajet(vers: (repaire.situation.x, repaire.situation.y),
                                          monde: repaire.situation.monde)
    }

    /// Le trajet vers le repaire le plus proche du monstre ; `false` si rien
    /// ne le situe ou que DofusDB n'a pas répondu.
    func copierLePlusProche(monstre id: Int) async -> Bool {
        guard let fiche = await monstreCharge(id), let premier = situeur(depuis: LecteurEcran.shared.positionDuPersoDevant)(fiche).first else { return false }
        copierTrajet(premier)
        return true
    }

    // MARK: - Cache

    private func relire() {
        guard !lu else { return }
        lu = true
        cache = CacheOuTrouver.gardee()
    }

    private func date(_ sujet: OuTrouver.Sujet) -> Date? {
        switch sujet {
        case .monstre(let id): cache.monstres[String(id)]?.date
        case .objet(let id): cache.objets[String(id)]?.date
        }
    }

    private func ranger(monstre: FicheMonstre) {
        cache.monstres[String(monstre.id)] = .init(date: Date(), valeur: monstre)
    }

    /// Les lâcheurs viennent avec leurs repaires : autant de monstres connus.
    private func ranger(objet id: Int, _ sources: SourcesObjet) {
        let maintenant = Date()
        cache.objets[String(id)] = .init(date: maintenant, valeur: sources)
        for lacheur in sources.lacheurs {
            cache.monstres[String(lacheur.monstre.id)] = .init(date: maintenant, valeur: lacheur.monstre)
        }
    }
}
