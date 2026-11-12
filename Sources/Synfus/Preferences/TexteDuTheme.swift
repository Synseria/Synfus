import Foundation

/// Ce qui s'enregistre de la couleur et des fonds. Une valeur illisible (un préréglage retiré, une
/// teinte refusée) n'est pas un choix : le réglage retombe sur son défaut sans toucher au reste.
extension Jetons.Couleur {
    /// Sa teinte en degrés : d'où part « Autre… », pour la couleur comme pour les fonds.
    var degres: Int {
        switch self {
        case .prereglage(let p): p.teinte
        case .teinte(let t): ((t % 360) + 360) % 360
        }
    }

    /// `jade`, ou `teinte:123` pour « Autre… ».
    var ecrit: String {
        switch self {
        case .prereglage(let p): p.rawValue
        case .teinte(let t): "teinte:\(t)"
        }
    }

    init?(ecrit: String) {
        if let p = Jetons.Prereglage(rawValue: ecrit) {
            self = .prereglage(p)
        } else if ecrit.hasPrefix("teinte:"), let t = Int(ecrit.dropFirst(7)), Jetons.teinteAcceptee(t) {
            self = .teinte(((t % 360) + 360) % 360)
        } else {
            return nil
        }
    }
}

extension Jetons.Fonds {
    /// `primaire`, `nuit`, `neutre`, ou `teinte:123`.
    var ecrit: String {
        switch self {
        case .primaire: "primaire"
        case .nuit: "nuit"
        case .neutre: "neutre"
        case .teinte(let t): "teinte:\(t)"
        }
    }

    init?(ecrit: String) {
        switch ecrit {
        case "primaire": self = .primaire
        case "nuit": self = .nuit
        case "neutre": self = .neutre
        default:
            guard ecrit.hasPrefix("teinte:"), let t = Int(ecrit.dropFirst(7)) else { return nil }
            self = .teinte(((t % 360) + 360) % 360)
        }
    }
}
