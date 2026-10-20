import Foundation

/// Ce que l'aide sait de la confusion de chaque perso au fil d'un combat
/// contre le Comte : les tours lus au bouton de combat, la vie lue au cœur,
/// les annonces du canal combat, les coups au corps à corps comptés à la
/// main. Pur : lectures et dates lui sont données.
struct SuiviConfusion: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        /// Annoncée au canal combat : elle suit déjà les coups au corps à
        /// corps, le jeu en annonce chaque changement.
        case tchat
        /// Déduite du pourcentage de vie, au début du tour ou, hors du tour,
        /// d'après la vie actuelle.
        case vie(pourcentage: Double)
        /// Choisie à la main, jusqu'à la fin du tour.
        case manuelle
    }

    struct Estimation: Equatable, Sendable {
        /// Coups au corps à corps compris.
        let confusion: Harebourg.Confusion
        let source: Source
        /// La tranche voisine, à une limite de pourcentage.
        let voisine: Harebourg.Confusion?
        let coups: Int
        /// Le tour du perso est en cours ; sinon, une prévision pour le
        /// prochain d'après sa vie actuelle.
        let enTour: Bool

        /// Les coups comptés à la main s'appliquent ; l'annonce du canal
        /// combat les compte déjà.
        var compteLesCoups: Bool { source != .tchat }
    }

    /// Une annonce du canal combat et le moment où elle a paru.
    private struct Annonce: Equatable, Sendable {
        let confusion: Harebourg.Confusion
        let vueLe: Date
    }

    /// La dernière annonce lue dans le tchat d'une fenêtre : son texte et le
    /// nombre de lignes écrites après elle. La même ligne ne fait que monter ;
    /// une ligne pareille plus bas est une annonce nouvelle.
    private struct Repere: Equatable, Sendable {
        let texte: String
        let apres: Int
    }

    private struct Perso: Equatable, Sendable {
        var debutTour: Date?
        /// La fin de son dernier tour : une annonce qui le nomme et date
        /// d'avant ne vaut plus.
        var finTour: Date?
        var vieDebutTour: Double?
        /// Le dernier pourcentage de vie connu.
        var vie: Double?
        /// La dernière vie lue, telle quelle — des points sans maximum ne
        /// donnent pas de pourcentage.
        var vieLue: Harebourg.Vie?
        var maxConnu: Int?
        var coups = 0
        var manuelle: Harebourg.Confusion?
        var annonce: Annonce?

        mutating func oublierLeTour() {
            debutTour = nil
            vieDebutTour = nil
            coups = 0
            manuelle = nil
        }
    }

    private var persos: [String: Perso] = [:]
    /// La dernière annonce qui ne nomme aucun perso connu.
    private var anonyme: Annonce?
    private var reperes: [String: Repere] = [:]

    /// Une annonce anonyme vue juste avant que le bouton de combat ne passe
    /// au perso compte pour son tour : le jeu l'écrit au début du tour, la
    /// lecture du bouton peut la suivre d'une seconde.
    static let toleranceDebut: TimeInterval = 2
    /// Une vie lue peu après le début du tour est encore celle du début du
    /// tour — la première lecture du tour peut venir juste après le bouton.
    static let delaiVieDebut: TimeInterval = 1.5
    /// Plus de lignes de dégâts au corps à corps que n'en compte un tour.
    static let coupsMax = 40

    // MARK: - Lectures

    /// L'état de combat lu chez `perso`, et celui d'avant : un nouveau tour
    /// (`EtatCombat.nouveauTour`) clôt le précédent, même sans bouton gris vu.
    mutating func combat(_ perso: String, avant: EtatCombat?, apres: EtatCombat, le date: Date) {
        var suivi = persos[perso] ?? Perso()
        if EtatCombat.nouveauTour(avant: avant, apres: apres) {
            if suivi.debutTour != nil { suivi.finTour = date }
            suivi.oublierLeTour()
            suivi.debutTour = date
            suivi.vieDebutTour = suivi.vie
        } else if !apres.enCombat || apres == .pasMonTour || apres == .placement {
            if suivi.debutTour != nil { suivi.finTour = date }
            suivi.oublierLeTour()
            if apres == .horsCombat { anonyme = nil }
        }
        persos[perso] = suivi
    }

    /// Le cœur de vie lu chez `perso`.
    mutating func vie(_ lue: Harebourg.Vie, perso: String, le date: Date) {
        var suivi = persos[perso] ?? Perso()
        if case .points(_, let max?) = lue { suivi.maxConnu = max }
        suivi.vieLue = lue
        if let pourcentage = lue.pourcentage(maxConnu: suivi.maxConnu) {
            suivi.vie = pourcentage
            if let debut = suivi.debutTour, date.timeIntervalSince(debut) <= Self.delaiVieDebut {
                suivi.vieDebutTour = pourcentage
            }
        }
        persos[perso] = suivi
    }

    /// Le tchat lu dans la fenêtre de `fenetre`, en lignes de haut en bas.
    mutating func tchat(_ lignes: [String], fenetre: String, persos noms: [String], le date: Date) {
        guard let lu = Harebourg.dernierConstat(lignes, persos: noms) else { return }
        let repere = Repere(texte: Ressemblance.normaliser(lignes[lu.ligne]), apres: lignes.count - 1 - lu.ligne)
        defer { reperes[fenetre] = repere }
        if let avant = reperes[fenetre], avant.texte == repere.texte, repere.apres >= avant.apres { return }
        let annonce = Annonce(confusion: lu.constat.confusion, vueLe: date)
        if let nomme = lu.constat.perso {
            persos[nomme, default: Perso()].annonce = annonce
        } else {
            anonyme = annonce
        }
    }

    // MARK: - Gestes

    /// Une ligne de dégâts de plus (ou de moins, pour se reprendre) au corps
    /// à corps.
    mutating func coup(_ pas: Int, perso: String) {
        var suivi = persos[perso] ?? Perso()
        suivi.coups = min(max(suivi.coups + pas, 0), Self.coupsMax)
        persos[perso] = suivi
    }

    /// La confusion constatée à l'œil, jusqu'à la fin du tour ; `nil` rend
    /// la main aux lectures. Les coups repartent de zéro : elle est celle de
    /// maintenant.
    mutating func choisir(_ confusion: Harebourg.Confusion?, perso: String) {
        var suivi = persos[perso] ?? Perso()
        suivi.manuelle = confusion
        suivi.coups = 0
        persos[perso] = suivi
    }

    // MARK: - Ce qu'il faut viser

    /// La confusion du perso : choisie à la main, sinon annoncée pour son
    /// tour, sinon déduite de sa vie au début du tour — ou, hors de son tour,
    /// prévue d'après sa vie actuelle. `nil` : rien de lu.
    func estimation(_ perso: String) -> Estimation? {
        let suivi = persos[perso] ?? Perso()
        let enTour = suivi.debutTour != nil
        if let manuelle = suivi.manuelle {
            return Estimation(confusion: manuelle.apres(coups: suivi.coups), source: .manuelle, voisine: nil,
                              coups: suivi.coups, enTour: enTour)
        }
        if let debut = suivi.debutTour {
            let nommee = suivi.annonce.flatMap { annonce in
                (suivi.finTour.map { annonce.vueLe > $0 } ?? true) ? annonce : nil
            }
            let anonyme = anonyme.flatMap { $0.vueLe >= debut.addingTimeInterval(-Self.toleranceDebut) ? $0 : nil }
            if let annonce = [nommee, anonyme].compactMap(\.self).max(by: { $0.vueLe < $1.vueLe }) {
                return Estimation(confusion: annonce.confusion, source: .tchat, voisine: nil, coups: 0, enTour: true)
            }
        }
        guard let vie = enTour ? suivi.vieDebutTour ?? suivi.vie : suivi.vie else { return nil }
        let coups = enTour ? suivi.coups : 0
        let parVie = Harebourg.parVie(pourcentage: vie)
        return Estimation(confusion: parVie.confusion.apres(coups: coups), source: .vie(pourcentage: vie),
                          voisine: parVie.voisine?.apres(coups: coups), coups: coups, enTour: enTour)
    }

    /// La dernière vie lue chez le perso, telle quelle.
    func vieLue(_ perso: String) -> Harebourg.Vie? { persos[perso]?.vieLue }
}
