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
