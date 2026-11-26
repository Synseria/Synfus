import CoreGraphics
import Foundation

/// La visée contre le Comte Harebourg : la case du lanceur (le pivot), marquée
/// par perso, et où retombe le sort visé sur la case survolée. Le calque
/// (`ViseePanel`) ne fait que dessiner ce que ceci décide. Pur.
struct ViseeHarebourg: Equatable, Sendable {
    struct Marque: Equatable, Sendable {
        let position: GrilleIso.Case
        let le: Date
    }

    private var lanceurs: [String: Marque] = [:]

    mutating func marquer(_ position: GrilleIso.Case, perso: String, le: Date) {
        lanceurs[perso] = Marque(position: position, le: le)
    }

    /// Au placement d'un combat : la case d'avant ne vaut plus.
    mutating func oublier(perso: String) {
        lanceurs[perso] = nil
    }

    func lanceur(_ perso: String) -> Marque? { lanceurs[perso] }

    // MARK: - Arrivée

    struct Arrivee: Equatable, Sendable {
        let position: GrilleIso.Case
        /// La confusion estimée ; sinon celle de la tranche voisine.
        let principale: Bool
    }

    /// Où tombe le sort visé sur `survolee` : la case tournée de la confusion
    /// autour du lanceur, puis, à une limite de tranche, celle de la voisine
    /// si elle tombe ailleurs. L'estimation compte déjà les coups au corps à corps.
    static func arrivees(survolee: GrilleIso.Case, lanceur: GrilleIso.Case,
                         estimation: SuiviConfusion.Estimation) -> [Arrivee] {
        let ecart = survolee - lanceur
        func arrivee(_ confusion: Harebourg.Confusion) -> GrilleIso.Case {
            let (x, y) = confusion.caseAtteinte(visee: (ecart.x, ecart.y))
            return lanceur + GrilleIso.Case(x, y)
        }
        let principale = arrivee(estimation.confusion)
        var resultat = [Arrivee(position: principale, principale: true)]
        if let voisine = estimation.voisine.map(arrivee), voisine != principale {
            resultat.append(Arrivee(position: voisine, principale: false))
        }
        return resultat
    }

    // MARK: - Quand dessiner

    /// Pourquoi le calque ne dessine rien, dans l'ordre où la chaîne casse.
    enum Inactive: Equatable, Sendable, CaseIterable {
        case reglage, pasHarebourg, panneauCache, pasSonTour, grilleAbsente, grilleInvalide,
             sansLanceur, sansConfusion, horsDuJeu
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
        /// Le pointeur est sur le contenu du jeu, pas sur un panneau de Synfus.
        var pointeurSurLeJeu = false
    }

    /// `nil` : le calque dessine.
    static func inactive(_ e: Entrees) -> Inactive? {
        if !e.reglage { return .reglage }
        if !e.harebourg { return .pasHarebourg }
        if !e.panneauMontre { return .panneauCache }
        if !e.sonTour { return .pasSonTour }
        guard let grille = e.grille else { return .grilleAbsente }
        if let contenu = e.contenu, !grille.valable(pour: contenu) { return .grilleInvalide }
        if e.lanceur == nil { return .sansLanceur }
        if !e.confusion { return .sansConfusion }
        if e.contenu == nil || !e.pointeurSurLeJeu { return .horsDuJeu }
        return nil
    }
}
