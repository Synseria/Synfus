/// Ce que le menu dit d'un perso, un seul état par ligne : le plus pressant, dans l'ordre où l'on agit.
enum EtatPersoMenu: Equatable {
    case sonTour, appelle, enCombat, autreBureau

    /// `nil` quand tout est normal : la ligne reste sans marque.
    static func de(combat: EtatCombat?, appelle: Bool, dormant: Bool) -> EtatPersoMenu? {
        if case .monTour? = combat { return .sonTour }
        if appelle { return .appelle }
        if combat?.enCombat == true { return .enCombat }
        return dormant ? .autreBureau : nil
    }

    var libelle: String {
        switch self {
        case .sonTour: L("menu.etat.sonTour")
        case .appelle: L("menu.etat.appelle")
        case .enCombat: L("menu.etat.combat")
        case .autreBureau: L("menu.etat.autreBureau")
        }
    }
}
