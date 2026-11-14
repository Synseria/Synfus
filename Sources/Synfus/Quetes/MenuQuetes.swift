import Foundation

/// Le menu de l'en-tête du panneau des quêtes, décrit sans AppKit : les
/// quêtes épinglées, la montrée cochée, ce qui commence sur la case du perso,
/// puis le suivi du jeu lu à l'écran.
/// Il tient sur une ligne quel que soit le nombre de quêtes — des pastilles
/// prenaient la moitié du panneau dès trois quêtes.
enum MenuQuetes {
    enum Element: Equatable {
        case titre(String)
        /// Une quête épinglée : la choisir la montre.
        case epinglee(id: Int, nom: String, montree: Bool)
        /// Retirer la quête montrée — une quête finie n'a plus rien à faire là.
        case desepingler(id: Int, nom: String)
        /// Retirer toutes les quêtes épinglées, le panneau avec.
        case toutDesepingler
        /// Une quête qui commence sur la case du perso : la choisir l'épingle.
        case ici(id: Int, titre: String, epinglee: Bool)
        /// Épingler d'un coup les quêtes du suivi que le panneau n'a pas.
        case toutEpingler
        case lireSuivi(enCours: Bool)
        /// Une quête du suivi : la choisir l'épingle et la montre à l'étape lue.
        case reconnue(SuiviQuetes.Reconnue, titre: String, epinglee: Bool)
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

    /// `coches` : les objectifs que la dernière lecture du suivi a cochés ;
    /// `actives` : les options allumées ; `ici` : rien quand rien ne commence
    /// sur la case, ou qu'elle est inconnue.
    static func elements(epinglees: [Int], montree: Int?, reconnues: [SuiviQuetes.Reconnue],
                         etat: LectureSuivi.Etat, coches: Int, actives: Set<Option>, ici: Ici? = nil,
                         autorise: Bool = true, nom: (Int) -> String) -> [Element] {
        // Une quête qui commence ici et que le panneau n'a pas : la section passe en tête.
        let iciEnTete = ici?.aEpingler(epinglees).isEmpty == false
        var elements: [Element] = []
        if iciEnTete, let ici { elements += section(ici, epinglees: epinglees) + [.separateur] }
        elements.append(.titre(L("quete.menu.epinglees")))
        elements += epinglees.isEmpty
            ? [.message(L("quete.menu.aucune"))]
            : epinglees.map { .epinglee(id: $0, nom: nom($0), montree: $0 == montree) }
        if let montree, epinglees.contains(montree) { elements.append(.desepingler(id: montree, nom: nom(montree))) }
        if epinglees.count > 1 { elements.append(.toutDesepingler) }
        if !iciEnTete, let ici, !ici.quetes.isEmpty || !ici.pnjs.isEmpty {
            elements += [.separateur] + section(ici, epinglees: epinglees)
        }
        elements += [.separateur, .titre(L("quete.menu.suivi"))]
        if aEpingler(reconnues, epinglees: epinglees).count > 1 { elements.append(.toutEpingler) }
        elements.append(.lireSuivi(enCours: etat == .enCours))
        elements += reconnues.map { reconnue in
            let titre = reconnue.etape.map { L("quete.menu.reconnueEtape", nom(reconnue.id), $0 + 1) } ?? nom(reconnue.id)
            return .reconnue(reconnue, titre: titre, epinglee: epinglees.contains(reconnue.id))
        }
        if let probleme = Probleme.de(etat, autorise: autorise) {
            elements.append(.message(probleme.titre))
            if let geste = probleme.geste { elements.append(.geste(geste)) }
        } else if etat == .lu, reconnues.isEmpty {
            elements.append(.message(L("quete.suivi.rien")))
        }
        if etat == .lu, coches > 0 { elements.append(.message(L("quete.suivi.coches", nombre: coches, coches))) }
        let options = Option.affichage.map { Element.option($0, actif: actives.contains($0)) }
        return elements + [.separateur, .affichage(options), .separateur, .fermer]
    }

    /// « Ici, en [x,y] » : les quêtes qui commencent sur la case et les PNJ qui s'y tiennent ; vide sans l'un ni l'autre.
    private static func section(_ ici: Ici, epinglees: [Int]) -> [Element] {
        guard !ici.quetes.isEmpty || !ici.pnjs.isEmpty else { return [] }
        var elements: [Element] = [.titre(L("quete.menu.ici", ici.coordonnees))]
        elements += ici.quetes.map {
            .ici(id: $0.id, titre: L("quete.menu.iciQuete", $0.nom, $0.niveau), epinglee: epinglees.contains($0.id))
        }
        if !ici.pnjs.isEmpty { elements.append(.message(L("quete.menu.iciPNJ", ici.pnjs.joined(separator: ", ")))) }
        return elements
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
