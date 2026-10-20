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
        case lireSuivi(enCours: Bool)
        /// Une quête du suivi : la choisir l'épingle et la montre à l'étape lue.
        case reconnue(SuiviQuetes.Reconnue, titre: String, epinglee: Bool)
        /// Ce que la dernière lecture a donné, faute de quête.
        case message(String)
        /// Un interrupteur de l'affichage, coché quand il est actif.
        case option(Option, actif: Bool)
        case separateur
    }

    /// Les interrupteurs repris de l'onglet Quêtes : celui du suivi dans sa
    /// section, ceux de l'affichage en pied (`affichage`, dans l'ordre).
    enum Option: CaseIterable {
        case compact, consigne, masquerObjets, cocherSuivi

        static let affichage: [Option] = [.compact, .consigne, .masquerObjets]

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
    }

    /// `coches` : les objectifs que la dernière lecture du suivi a cochés ;
    /// `actives` : les options allumées ; `ici` : rien quand rien ne commence
    /// sur la case, ou qu'elle est inconnue.
    static func elements(epinglees: [Int], montree: Int?, reconnues: [SuiviQuetes.Reconnue],
                         etat: LectureSuivi.Etat, coches: Int, actives: Set<Option>, ici: Ici? = nil,
                         nom: (Int) -> String) -> [Element] {
        var elements: [Element] = [.titre(L("quete.menu.epinglees"))]
        elements += epinglees.isEmpty
            ? [.message(L("quete.menu.aucune"))]
            : epinglees.map { .epinglee(id: $0, nom: nom($0), montree: $0 == montree) }
        if let montree, epinglees.contains(montree) { elements.append(.desepingler(id: montree, nom: nom(montree))) }
        if epinglees.count > 1 { elements.append(.toutDesepingler) }
        if let ici, !ici.quetes.isEmpty || !ici.pnjs.isEmpty {
            elements += [.separateur, .titre(L("quete.menu.ici", ici.coordonnees))]
            elements += ici.quetes.map {
                .ici(id: $0.id, titre: L("quete.menu.iciQuete", $0.nom, $0.niveau), epinglee: epinglees.contains($0.id))
            }
            if !ici.pnjs.isEmpty { elements.append(.message(L("quete.menu.iciPNJ", ici.pnjs.joined(separator: ", ")))) }
        }
        elements += [.separateur, .titre(L("quete.menu.suivi")), .lireSuivi(enCours: etat == .enCours),
                     .option(.cocherSuivi, actif: actives.contains(.cocherSuivi))]
        elements += reconnues.map { reconnue in
            let titre = reconnue.etape.map { L("quete.menu.reconnueEtape", nom(reconnue.id), $0 + 1) } ?? nom(reconnue.id)
            return .reconnue(reconnue, titre: titre, epinglee: epinglees.contains(reconnue.id))
        }
        if let message = message(etat, reconnues: reconnues) { elements.append(.message(message)) }
        if etat == .lu, coches > 0 { elements.append(.message(L("quete.suivi.coches", nombre: coches, coches))) }
        return elements + [.separateur] + Option.affichage.map { .option($0, actif: actives.contains($0)) }
    }

    /// Les quêtes que le suivi montre et que le panneau n'a pas encore : ce
    /// que l'en-tête signale sur le menu.
    static func nouvelles(_ reconnues: [SuiviQuetes.Reconnue], epinglees: [Int]) -> Int {
        reconnues.count { !epinglees.contains($0.id) }
    }

    private static func message(_ etat: LectureSuivi.Etat, reconnues: [SuiviQuetes.Reconnue]) -> String? {
        switch etat {
        case .jamaisLu, .enCours: return nil
        case .illisible: return L("quete.suivi.illisible")
        case .sansQuetes: return L("quete.suivi.sansQuetes")
        case .lu: return reconnues.isEmpty ? L("quete.suivi.rien") : nil
        }
    }
}
