import Foundation

/// D'où la palette tire distances et trajets, et ce qui manque quand elle ne le sait pas : la
/// cause décide du geste que l'en-tête propose. Pur.
enum OriginePalette: Equatable, Sendable {
    case connue
    case lectureEteinte
    case sansAutorisation
    /// La lecture tourne mais n'a encore rien rendu pour le perso devant.
    case inconnue

    static func de(positionConnue: Bool, lectureAllumee: Bool, autorise: Bool) -> OriginePalette {
        if positionConnue { return .connue }
        if !lectureAllumee { return .lectureEteinte }
        return autorise ? .inconnue : .sansAutorisation
    }
}
