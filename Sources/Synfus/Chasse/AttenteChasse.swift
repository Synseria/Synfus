import Foundation

/// Ce que le champ de l'indice attend, dans l'ordre où la chasse se conduit.
enum AttenteChasse: Equatable {
    case depart
    case direction
    case indice

    init(departConnu: Bool, directionChoisie: Bool) {
        if !departConnu {
            self = .depart
        } else if !directionChoisie {
            self = .direction
        } else {
            self = .indice
        }
    }

    var libelle: String {
        switch self {
        case .depart: return L("chasse.depart.saisir")
        case .direction: return L("chasse.direction.choisir")
        case .indice: return L("chasse.indice")
        }
    }
}

/// La phase où en est la chasse, pour dire ce qu'il reste à faire : poser le
/// départ, lire l'étape à l'écran, aller à la carte trouvée, la valider dans
/// le jeu. Pur.
enum PhaseChasse: Equatable {
    case depart
    case lire
    case aller(x: Int, y: Int)
    case valider(x: Int, y: Int)

    init(departConnu: Bool, cible: (x: Int, y: Int)?, position: (x: Int, y: Int)?) {
        guard departConnu else { self = .depart; return }
        guard let cible else { self = .lire; return }
        if let position, position == cible {
            self = .valider(x: cible.x, y: cible.y)
        } else {
            self = .aller(x: cible.x, y: cible.y)
        }
    }

    var symbole: String {
        switch self {
        case .depart: return "location"
        case .lire: return "text.viewfinder"
        case .aller: return "arrow.up.right"
        case .valider: return "checkmark.seal"
        }
    }

    var libelle: String {
        switch self {
        case .depart: return L("chasse.depart.reprendre")
        case .lire: return L("chasse.phase.lire")
        case .aller(let x, let y): return L("chasse.phase.aller", Coordonnees.texte(x, y))
        case .valider: return L("chasse.phase.valider")
        }
    }
}
