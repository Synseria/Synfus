import Foundation

/// Ce que le panneau des quêtes propose hors de la fiche, décrit sans AppKit
/// ni SwiftUI : la liste qui prend la place de la fiche (`liste` — les quêtes
/// du panneau, ce qui commence sur la case du perso, le suivi du jeu lu à
/// l'écran) et le menu « ⋯ » de l'en-tête (`reglages`).
enum MenuQuetes {
    enum Element: Equatable {
        case titre(String)
        /// Une quête du panneau : la choisir la montre, sa croix la retire.
        case epinglee(id: Int, nom: String, montree: Bool)
        /// Retirer toutes les quêtes du panneau ; la liste reste ouverte.
        case toutDesepingler
        /// Une quête qui commence sur la case du perso : la choisir l'ajoute.
        case ici(id: Int, titre: String)
        /// L'en-tête replié de la section « Ici », toujours en dernier : le
        /// nombre de quêtes à épingler tient à droite de la ligne.
        case iciEnTete(coordonnees: String, nombre: Int)
        /// Chercher une quête à ajouter (la palette, sur `/quete`).
        case chercher
        case lireSuivi(enCours: Bool)
        /// Une quête du suivi que le panneau n'a pas : la choisir l'ajoute et la montre à l'étape lue.
        case reconnue(SuiviQuetes.Reconnue, titre: String)
        /// Ce que la dernière lecture a donné, faute de quête.
        case message(String)
        /// Le geste qui lève la cause d'un suivi illisible.
        case geste(Geste)
        /// Un interrupteur de l'affichage, coché quand il est actif.
        case option(Option, actif: Bool)
        /// Le sous-menu qui range les interrupteurs.
        case affichage([Element])
        /// Cache le panneau ; les quêtes restent épinglées.
        case fermer
        case separateur
    }

    /// Ce que le joueur fait pour que le suivi se lise.
    enum Geste: Equatable {
        case autoriser, calibrer, reessayer, relire

        var titre: String {
            switch self {
            case .autoriser: L("autorisation.autoriser")
            case .calibrer: L("quete.suivi.calibrer")
            case .reessayer, .relire: L("commun.reessayer")
            }
        }
    }

    /// Pourquoi le suivi ne s'est pas lu : la cause que la lecture a portée, et son geste, s'il y en a un.
    enum Probleme: Equatable {
        case sansAutorisation, sansPerso, captureImpossible, zone, indisponible

        var titre: String {
            switch self {
            case .sansAutorisation: L("quete.suivi.sansAutorisation")
            case .sansPerso: L("quete.suivi.sansPerso")
            case .captureImpossible: L("quete.suivi.captureImpossible")
            case .zone: L("quete.suivi.zone")
            case .indisponible: L("quete.indisponible")
            }
        }

        var geste: Geste? {
            switch self {
            case .sansAutorisation: .autoriser
            case .sansPerso: nil
            case .captureImpossible: .relire
            case .zone: .calibrer
            case .indisponible: .reessayer
            }
        }

        /// `autorise` : l'enregistrement de l'écran est permis maintenant — une autorisation donnée depuis
        /// l'échec ne s'affiche plus comme manquante.
        static func de(_ etat: LectureSuivi.Etat, autorise: Bool) -> Probleme? {
            switch etat {
            case .jamaisLu, .enCours, .lu: nil
            case .sansQuetes: .indisponible
            case .illisible(.sansAutorisation): autorise ? nil : .sansAutorisation
            case .illisible(.sansPerso): .sansPerso
            case .illisible(.captureImpossible): .captureImpossible
            case .illisible(.texteIllisible): .zone
            }
        }
    }

    /// Les interrupteurs repris de l'onglet Quêtes, rangés au sous-menu « Affichage » (`affichage`, dans l'ordre).
    enum Option: CaseIterable {
        case compact, consigne, masquerObjets, cocherSuivi

        static let affichage: [Option] = [.cocherSuivi, .compact, .consigne, .masquerObjets]

        var titre: String {
            switch self {
            case .compact: L("quetes.compact")
            case .consigne: L("quetes.consigne")
            case .masquerObjets: L("quetes.masquerObjets")
            case .cocherSuivi: L("quetes.cocherSuivi")
            }
        }
    }

    /// La case du perso, les quêtes qui y commencent et les PNJ qui s'y
    /// tiennent (`QuetesIci`).
    struct Ici: Equatable {
        struct QueteIci: Equatable {
            let id: Int
            let nom: String
            let niveau: Int
        }

        let coordonnees: String
        let quetes: [QueteIci]
        let pnjs: [String]

        /// Les quêtes qui commencent ici et que le panneau n'a pas encore.
        func aEpingler(_ epinglees: [Int]) -> [QueteIci] { quetes.filter { !epinglees.contains($0.id) } }
    }

    /// La liste du panneau. Une quête déjà au panneau n'y paraît qu'une fois, en tête : « Ici » et le
    /// suivi ne proposent que celles qu'il n'a pas. `ici` : en dernier, replié d'office — l'en-tête compte les quêtes, un clic
    /// déplie ; rien quand rien ne commence sur la case, ou qu'elle est inconnue.
    static func liste(epinglees: [Int], montree: Int?, reconnues: [SuiviQuetes.Reconnue],
                      etat: LectureSuivi.Etat, ici: Ici? = nil,
                      autorise: Bool = true, nom: (Int) -> String) -> [Element] {
        var elements: [Element] = epinglees.isEmpty
            ? [.message(L("quete.menu.aucune"))]
            : epinglees.map { .epinglee(id: $0, nom: nom($0), montree: $0 == montree) }
        elements.append(.chercher)
        let nouvelles = aEpingler(reconnues, epinglees: epinglees)
        elements.append(.titre(L("quete.menu.suivi")))
        // Sans l'autorisation d'écran, rien à lire : le geste qui la donne, pas un bouton qui échoue.
        if autorise { elements.append(.lireSuivi(enCours: etat == .enCours)) }
        elements += nouvelles.map { reconnue in
            .reconnue(reconnue, titre: reconnue.etape.map { L("quete.menu.reconnueEtape", nom(reconnue.id), $0 + 1) } ?? nom(reconnue.id))
        }
        if let probleme = autorise ? Probleme.de(etat, autorise: true) : .sansAutorisation {
            elements.append(.message(probleme.titre))
            if let geste = probleme.geste { elements.append(.geste(geste)) }
        } else if etat == .lu, reconnues.isEmpty {
            elements.append(.message(L("quete.suivi.rien")))
        }
        // « Ici » en dernier, replié : la section n'encombre plus le haut de la liste.
        if let ici { elements += sectionIci(ici, epinglees: epinglees) }
        return elements
    }

    /// Le menu « ⋯ » de l'en-tête : chercher une quête, l'affichage, tout retirer, cacher le panneau.
    /// `actives` : les options allumées.
    static func reglages(epinglees: Int, actives: Set<Option>) -> [Element] {
        let options = Option.affichage.map { Element.option($0, actif: actives.contains($0)) }
        return [.chercher, .separateur, .affichage(options)] + (epinglees > 1 ? [.toutDesepingler] : []) + [.separateur, .fermer]
    }

    /// « Ici, en [x,y] », en dernier et replié d'office : l'en-tête avec le
    /// nombre de quêtes à épingler, puis — déplié — les quêtes qui commencent
    /// sur la case et les PNJ qui s'y tiennent ; vide sans l'un ni l'autre.
    private static func sectionIci(_ ici: Ici, epinglees: [Int]) -> [Element] {
        let quetes = ici.aEpingler(epinglees)
        guard !quetes.isEmpty || !ici.pnjs.isEmpty else { return [] }
        var elements: [Element] = [.iciEnTete(coordonnees: ici.coordonnees, nombre: quetes.count)]
        elements += quetes.map { .ici(id: $0.id, titre: L("quete.menu.iciQuete", $0.nom, $0.niveau)) }
        if !ici.pnjs.isEmpty { elements.append(.message(L("quete.menu.iciPNJ", ici.pnjs.joined(separator: ", ")))) }
        return elements
    }

    /// Une quête choisie dans la palette, ou à la suite d'une autre, prend la place de la montrée
    /// au lieu de s'ajouter : le panneau ne s'allonge que de ce que le joueur y ajoute exprès.
    static func remplacer(_ epinglees: [Int], montree: Int?, par id: Int) -> [Int] {
        guard !epinglees.contains(id) else { return epinglees }
        guard let montree, let rang = epinglees.firstIndex(of: montree) else { return epinglees + [id] }
        var apres = epinglees
        apres[rang] = id
        return apres
    }

    /// Les quêtes que le suivi montre et que le panneau n'a pas encore : ce
    /// que l'en-tête signale sur le menu.
    static func nouvelles(_ reconnues: [SuiviQuetes.Reconnue], epinglees: [Int]) -> Int {
        aEpingler(reconnues, epinglees: epinglees).count
    }

    /// Les quêtes du suivi que le panneau n'a pas encore, dans l'ordre du suivi.
    static func aEpingler(_ reconnues: [SuiviQuetes.Reconnue], epinglees: [Int]) -> [SuiviQuetes.Reconnue] {
        reconnues.filter { !epinglees.contains($0.id) }
    }
}

/// Le menu des étapes d'une quête : toutes, l'étape montrée cochée, celles dont
/// tous les objectifs sont faits marquées.
enum MenuEtapes {
    struct Entree: Equatable {
        let rang: Int
        let titre: String
        let montree: Bool
        let faite: Bool
    }

    /// `etapes` : le nom de chaque étape et si tous ses objectifs sont cochés.
    static func entrees(_ etapes: [(nom: String, faite: Bool)], montree: Int) -> [Entree] {
        etapes.enumerated().map { rang, etape in
            Entree(rang: rang, titre: L("quete.etapes.item", rang + 1, etape.nom), montree: rang == montree, faite: etape.faite)
        }
    }
}
