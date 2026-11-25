import Foundation
import SynseriaDesign

/// Les réglages de couleur d'avant le thème continu, relus une fois puis jamais plus écrits : coloris
/// ou couleur personnalisée, nuance et fond (`Jetons.Nuancier.migrer`), et, plus anciens, une couleur
/// parmi cinq ou une teinte et une apparence. Une valeur illisible n'est pas un choix : elle laisse le
/// défaut d'alors.
enum ConversionDuTheme {
    /// Ce que les sauvegardes d'avant écrivaient, en texte.
    struct Ancien: Equatable {
        /// `lagon`…, ou `personnalise:3FA9D8`.
        var theme: String?
        /// `jour`…, ou `systeme` ; absente, le système.
        var nuance: String?
        /// Absent : celui du thème ; sinon un fond nommé (`ardoise`…) ou `#3F7A80`.
        var fond: String?
        /// D'avant le nuancier : `jade`, `teinte:185`… ; `clair`, `sombre` ou `auto`.
        var couleurDeLApp: String?
        var apparence: String?
    }

    private static let prefixePersonnalise = "personnalise:"

    /// Le thème qu'écrivaient les préférences d'avant ; sans rien de lisible, celui d'alors (Lagon,
    /// avec le système) : l'app ne change pas de couleur à la mise à jour.
    static func relire(_ ancien: Ancien) -> Jetons.Theme {
        if let theme = ancien.theme {
            let personnalise = theme.hasPrefix(prefixePersonnalise) ? hex(theme.dropFirst(prefixePersonnalise.count)) : nil
            let coloris = personnalise == nil ? (Jetons.Parametres.Migration.themes[theme] != nil ? theme : defautDAlors) : nil
            return Jetons.Nuancier.migrer(coloris: coloris, personnalise: personnalise,
                                          nuance: ancien.nuance == "systeme" ? nil : ancien.nuance, fond: ancien.fond)
        }
        // D'avant le nuancier : `teinte:N` était déjà un angle OKLCH, la teinte d'aujourd'hui ; Clair et
        // Sombre imposés deviennent Jour et Pénombre, Auto suit le système.
        let nuance = ["clair": "jour", "sombre": "penombre"][ancien.apparence ?? ""]
        if let couleur = ancien.couleurDeLApp, couleur.hasPrefix("teinte:"), let t = Int(couleur.dropFirst(7)) {
            var theme = Jetons.Nuancier.migrer(coloris: nil, personnalise: nil, nuance: nuance, fond: nil)
            theme.teinte = ((t % 360) + 360) % 360
            return theme
        }
        let coloris = ancien.couleurDeLApp.flatMap { colorisDuPrereglage[$0] } ?? defautDAlors
        return Jetons.Nuancier.migrer(coloris: coloris, personnalise: nil, nuance: nuance, fond: nil)
    }

    /// Le coloris par défaut d'avant le thème continu.
    static let defautDAlors = "lagon"

    /// Le coloris le plus proche de chaque préréglage d'avant le nuancier.
    static let colorisDuPrereglage = [
        "azur": "bleuet", "jade": "lagon", "framboise": "cerise", "corail": "terracotta", "ardoise": "graphite",
    ]

    /// Une couleur écrite `RRGGBB` ; nil si illisible.
    private static func hex(_ texte: Substring) -> UInt32? {
        guard let couleur = UInt32(texte, radix: 16), couleur <= 0xFFFFFF else { return nil }
        return couleur
    }
}
