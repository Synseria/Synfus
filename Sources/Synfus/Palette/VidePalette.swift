import Foundation

/// Ce que la palette dit quand elle n'a aucune ligne : la cause, pas un « Aucun résultat » unique.
/// Pur : l'état du moment en entrée, la raison en sortie.
enum VidePalette: Equatable, Sendable {
    case carteEnChargement
    case carteIndisponible
    case quetesEnChargement
    case iciSansLecture
    case iciPasEncoreLu
    case aucun

    /// Ce que ↵ fait sur cet état vide.
    var entree: Entree? {
        switch self {
        case .carteIndisponible: return .reessayer
        default: return nil
        }
    }

    enum Entree: Equatable, Sendable { case reessayer }

    static func de(carte: EtatCarte, requeteVide: Bool, filtre: FiltrePalette, positionConnue: Bool,
                   lectureAllumee: Bool, quetesEnChargement: Bool) -> VidePalette {
        if carte != .prete, requeteVide, filtre == .tout {
            return carte == .indisponible ? .carteIndisponible : .carteEnChargement
        }
        if quetesEnChargement { return .quetesEnChargement }
        if filtre == .ici, !positionConnue { return lectureAllumee ? .iciPasEncoreLu : .iciSansLecture }
        return .aucun
    }
}
