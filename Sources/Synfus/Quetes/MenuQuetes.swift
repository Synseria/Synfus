import Foundation

/// Le menu de l'en-tête du panneau des quêtes, décrit sans AppKit : les
/// quêtes épinglées, la montrée cochée, puis le suivi du jeu lu à l'écran.
/// Il tient sur une ligne quel que soit le nombre de quêtes — des pastilles
/// prenaient la moitié du panneau dès trois quêtes.
enum MenuQuetes {
    enum Element: Equatable {
        case titre(String)
        /// Une quête épinglée : la choisir la montre.
        case epinglee(id: Int, nom: String, montree: Bool)
        case lireSuivi(enCours: Bool)
        /// Une quête du suivi : la choisir l'épingle et la montre à l'étape lue.
        case reconnue(SuiviQuetes.Reconnue, titre: String, epinglee: Bool)
        /// Ce que la dernière lecture a donné, faute de quête.
        case message(String)
        case separateur
    }

    static func elements(epinglees: [Int], montree: Int?, reconnues: [SuiviQuetes.Reconnue],
                         etat: LectureSuivi.Etat, nom: (Int) -> String) -> [Element] {
        var elements: [Element] = [.titre(L("quete.menu.epinglees"))]
        elements += epinglees.isEmpty
            ? [.message(L("quete.menu.aucune"))]
            : epinglees.map { .epinglee(id: $0, nom: nom($0), montree: $0 == montree) }
        elements += [.separateur, .titre(L("quete.menu.suivi")), .lireSuivi(enCours: etat == .enCours)]
        elements += reconnues.map { reconnue in
            let titre = reconnue.etape.map { L("quete.menu.reconnueEtape", nom(reconnue.id), $0 + 1) } ?? nom(reconnue.id)
            return .reconnue(reconnue, titre: titre, epinglee: epinglees.contains(reconnue.id))
        }
        if let message = message(etat, reconnues: reconnues) { elements.append(.message(message)) }
        return elements
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
        case .sansQuetes: return L("palette.quetes.chargement")
        case .lu: return reconnues.isEmpty ? L("quete.suivi.rien") : nil
        }
    }
}
