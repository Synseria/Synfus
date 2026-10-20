import Foundation

/// Où trouver ce que demandent les quêtes : relu du disque à la première
/// demande, demandé à DofusDB pour un monstre ou un objet encore inconnu, ou
/// vu il y a plus de trente jours — qu'on montre en attendant. Un échec
/// garde ce qui est là. Et le trajet vers le repaire le plus proche. Le
/// disque se lit et s'écrit hors du fil principal : le cache grossit avec
/// les fiches vues.
@MainActor
final class OuTrouverStore: ObservableObject {
    static let shared = OuTrouverStore()

    @Published private(set) var cache = CacheOuTrouver()
    @Published private(set) var enCours: Set<OuTrouver.Sujet> = []
    @Published private(set) var echecs: Set<OuTrouver.Sujet> = []
    /// La lecture du disque, faite une fois ; chaque demande l'attend.
    private var lecture: Task<Void, Never>?
    /// L'écriture en cours : la suivante l'attend, le fichier garde la
    /// dernière version.
    private var ecriture: Task<Void, Never>?
    /// La demande en cours de chaque sujet, qu'attend `charge`.
    private var demandes: [OuTrouver.Sujet: Task<Void, Never>] = [:]
    /// Par monstre (`repaires`).
    private var repairesGardes: [Int: DernierCalcul<CleRepaires, [RepaireSitue]>] = [:]

    private init() {}

    /// Lus tels quels : c'est `demander`, à l'apparition de la vue, qui relit
    /// le disque — une vue ne publie rien pendant qu'elle se dessine.
    func monstre(_ id: Int) -> FicheMonstre? {
        cache.monstres[String(id)]?.valeur
    }

    func objet(_ id: Int) -> SourcesObjet? {
        cache.objets[String(id)]?.valeur
    }

    /// Demande le sujet à DofusDB s'il manque ou a vieilli, une fois le
    /// disque relu.
    func demander(_ sujet: OuTrouver.Sujet) {
        guard demandes[sujet] == nil else { return }
        demandes[sujet] = Task {
            defer { demandes[sujet] = nil }
            await relu()
            guard DofusDB.perimee(depuis: date(sujet), maintenant: Date()) else { return }
            enCours.insert(sujet)
            echecs.remove(sujet)
            do {
                let maintenant = Date()
                var nouveau = cache
                switch sujet {
                case .monstre(let id): nouveau.ranger(monstre: try await OuTrouverDofusDB.monstre(id), le: maintenant)
                case .objet(let id): nouveau.ranger(objet: id, try await OuTrouverDofusDB.objet(id), le: maintenant)
                }
                // Ce qui est arrivé pendant la demande reste ; une seule publication.
                var fusion = cache.sous(nouveau)
                fusion.oublier(vuesAvant: maintenant.addingTimeInterval(-CacheOuTrouver.oubli))
                cache = fusion
                garder()
            } catch {
                echecs.insert(sujet)
            }
            enCours.remove(sujet)
        }
    }

    /// Le monstre, après la demande s'il le faut — pour copier tout de suite
    /// le trajet d'un objectif.
    func monstreCharge(_ id: Int) async -> FicheMonstre? {
        demander(.monstre(id))
        await demandes[.monstre(id)]?.value
        return monstre(id)
    }

    // MARK: - Repaires

    /// Les repaires du monstre situés depuis la position du perso, le plus
    /// proche d'abord. La vue les redemande à chaque rendu, pour chaque
    /// lâcheur : gardés sous la fiche, la case du perso et la révision des
    /// trajets (réglages, carte).
    func repaires(_ fiche: FicheMonstre, depuis perso: PositionCarte?) -> [RepaireSitue] {
        let depart = ItineraireZaap.rejoindre(perso)
        let cle = CleRepaires(fiche: fiche, depart: depart.map { PNJ.Position(x: $0.x, y: $0.y) },
                              revision: ZaapClipboard.shared.revisionTrajets)
        return repairesGardes[fiche.id, default: DernierCalcul()].valeur(pour: cle) {
            let cout = ZaapClipboard.shared.cout(depuis: perso)
            return OuTrouver.situes(fiche.repaires, depuis: depart, reseau: CarteStore.shared.reseau,
                                    reperes: CarteStore.shared.reperes, cartes: { cout?($0) })
        }
    }

    /// Toute la clé de `DernierCalcul`.
    private struct CleRepaires: Equatable {
        // periphery:ignore - lu par l'Equatable synthétisé, que Periphery ne voit pas
        let fiche: FicheMonstre
        // periphery:ignore - lu par l'Equatable synthétisé
        let depart: PNJ.Position?
        // periphery:ignore - lu par l'Equatable synthétisé
        let revision: Int
    }

    /// Copie le trajet vers le repaire, zaap compris dans le Monde des Douze.
    func copierTrajet(_ repaire: RepaireSitue) {
        ZaapClipboard.shared.copierTrajet(vers: (repaire.situation.x, repaire.situation.y),
                                          dansLesDouze: repaire.situation.monde == Zaap.mondeDesDouze)
    }

    /// Le trajet vers le repaire le plus proche du monstre ; `false` si rien
    /// ne le situe ou que DofusDB n'a pas répondu.
    func copierLePlusProche(monstre id: Int) async -> Bool {
        guard let fiche = await monstreCharge(id),
              let premier = repaires(fiche, depuis: LecteurEcran.shared.positionDuPersoDevant).first
        else { return false }
        copierTrajet(premier)
        return true
    }

    // MARK: - Cache

    private func relu() async {
        if lecture == nil {
            lecture = Task {
                let gardee = await Task.detached(priority: .userInitiated) { CacheOuTrouver.gardee() }.value
                cache = gardee.sous(cache)
            }
        }
        await lecture?.value
    }

    private func garder() {
        let aGarder = cache, precedente = ecriture
        ecriture = Task.detached(priority: .utility) {
            await precedente?.value
            try? aGarder.garder()
        }
    }

    private func date(_ sujet: OuTrouver.Sujet) -> Date? {
        switch sujet {
        case .monstre(let id): cache.monstres[String(id)]?.date
        case .objet(let id): cache.objets[String(id)]?.date
        }
    }

}

private extension CacheOuTrouver {
    mutating func ranger(monstre: FicheMonstre, le date: Date) {
        monstres[String(monstre.id)] = .init(date: date, valeur: monstre)
    }

    /// Les lâcheurs viennent avec leurs repaires : autant de monstres connus.
    mutating func ranger(objet id: Int, _ sources: SourcesObjet, le date: Date) {
        objets[String(id)] = .init(date: date, valeur: sources)
        for lacheur in sources.lacheurs {
            monstres[String(lacheur.monstre.id)] = .init(date: date, valeur: lacheur.monstre)
        }
    }
}
