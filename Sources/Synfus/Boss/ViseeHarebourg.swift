import CoreGraphics

/// La visée contre le Comte Harebourg : la case du lanceur (le pivot), marquée
/// par perso, et où retombe le sort visé sur la case survolée, dans la zone du
/// sort ou hors d'elle. Le calque (`ViseePanel`) ne fait que dessiner ce que
/// ceci décide. Pur.
struct ViseeHarebourg: Equatable, Sendable {
    private var lanceurs: [String: GrilleIso.Case] = [:]

    mutating func marquer(_ position: GrilleIso.Case, perso: String) {
        lanceurs[perso] = position
    }

    func lanceur(_ perso: String) -> GrilleIso.Case? { lanceurs[perso] }

    // MARK: - Arrivée

    struct Arrivee: Equatable, Sendable {
        let position: GrilleIso.Case
        /// La confusion estimée ; sinon celle de la tranche voisine.
        let principale: Bool
        /// Sur une case bleuie par le sort (foncée ou claire), ou couverte : le
        /// sort y porte. Sinon il part hors de la zone, dans le vide.
        var dansLaZone = true
    }

    /// Où tombe le sort visé sur `survolee` : la case tournée de la confusion
    /// autour du lanceur, puis, à une limite de tranche, celle de la voisine
    /// si elle tombe ailleurs. L'estimation compte déjà les coups au corps à corps.
    static func arrivees(survolee: GrilleIso.Case, lanceur: GrilleIso.Case,
                         estimation: SuiviConfusion.Estimation, portee: PorteeSort) -> [Arrivee] {
        let ecart = survolee - lanceur
        func arrivee(_ confusion: Harebourg.Confusion) -> GrilleIso.Case {
            let (x, y) = confusion.caseAtteinte(visee: (ecart.x, ecart.y))
            return lanceur + GrilleIso.Case(x, y)
        }
        func dansLaZone(_ position: GrilleIso.Case) -> Bool { portee.teinte(position) != .libre }
        let principale = arrivee(estimation.confusion)
        var resultat = [Arrivee(position: principale, principale: true, dansLaZone: dansLaZone(principale))]
        if let voisine = estimation.voisine.map(arrivee), voisine != principale {
            resultat.append(Arrivee(position: voisine, principale: false, dansLaZone: dansLaZone(voisine)))
        }
        return resultat
    }

    /// La case visée peut-elle recevoir le sort ? Bleu foncé, ou couverte (un
    /// perso, la cible) ; le bleu clair est sans ligne de vue.
    static func visable(_ teinte: PorteeSort.Teinte) -> Bool { [.portee, .inconnue].contains(teinte) }

    // MARK: - Quand dessiner

    /// Pourquoi le calque ne dessine rien, dans l'ordre où la chaîne casse.
    enum Inactive: Equatable, Sendable, CaseIterable {
        case reglage, pasHarebourg, panneauCache, pasSonTour, grilleAbsente, sansLanceur, sansConfusion,
             sansSort, horsDuJeu, horsPortee
    }

    struct Entrees: Equatable, Sendable {
        var reglage = false
        var harebourg = false
        var panneauMontre = false
        var sonTour = false
        var grille: GrilleIso?
        /// La taille du contenu de la fenêtre du perso devant ; `nil` : Dofus n'est pas devant.
        var contenu: CGSize?
        var lanceur: GrilleIso.Case?
        var confusion = false
        /// Des cases sont bleuies : un sort est préparé.
        var sortPrepare = false
        /// Le pointeur est sur le contenu du jeu, pas sur un panneau de Synfus.
        var pointeurSurLeJeu = false
        /// La case sous le pointeur peut recevoir le sort (`visable`).
        var survoleeVisable = false
    }

    /// La raison à dire au Diagnostic : celle d'à l'instant si Dofus est devant
    /// ou si elle se juge hors du jeu ; sinon la dernière relevée en jeu —
    /// réglages devant, Dofus n'est pas au premier plan, ce n'est pas la cause.
    static func raisonAffichee(_ raison: Inactive?, avant: Inactive?, dofusDevant: Bool) -> Inactive? {
        dofusDevant || [.reglage, .pasHarebourg].contains(raison) ? raison : avant
    }

    /// `nil` : le calque dessine.
    static func inactive(_ e: Entrees) -> Inactive? {
        if !e.reglage { return .reglage }
        if !e.harebourg { return .pasHarebourg }
        if !e.panneauMontre { return .panneauCache }
        if !e.sonTour { return .pasSonTour }
        if e.grille == nil { return .grilleAbsente }
        if e.lanceur == nil { return .sansLanceur }
        if !e.confusion { return .sansConfusion }
        if !e.sortPrepare { return .sansSort }
        if e.contenu == nil || !e.pointeurSurLeJeu { return .horsDuJeu }
        if !e.survoleeVisable { return .horsPortee }
        return nil
    }
}
