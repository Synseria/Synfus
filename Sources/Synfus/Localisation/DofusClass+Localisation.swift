import Foundation

/// Le nom de classe dans la langue de l'interface. À part de `DofusClass`,
/// que `Tools/fetch-ankama-assets.sh` compile seul, sans la localisation.
extension DofusClass.Breed {
    var nomLocalise: String { nom(langue: L10n.courante.langue.rawValue) }
}
