import Foundation

/// Ce qui s'enregistre du thème (Réglages ▸ Thème), et la conversion des réglages d'avant le nuancier
/// (une couleur parmi cinq ou une teinte, une teinte des fonds, une apparence). Une valeur illisible
/// n'est pas un choix : le réglage retombe sur son défaut sans toucher au reste.
extension Jetons.Theme {
    private static let prefixePersonnalise = "personnalise:"

    /// `graphite`, ou `personnalise:3FA9D8`.
    var ecrit: String {
        switch self {
        case .coloris(let coloris): coloris.rawValue
        case .personnalise(let couleur): Self.prefixePersonnalise + String(format: "%06X", couleur)
        }
    }

    init?(ecrit: String) {
        if let coloris = Jetons.Coloris(rawValue: ecrit) {
            self = .coloris(coloris)
        } else if ecrit.hasPrefix(Self.prefixePersonnalise),
                  let couleur = UInt32(ecrit.dropFirst(Self.prefixePersonnalise.count), radix: 16), couleur <= 0xFFFFFF {
            self = .personnalise(couleur)
        } else {
            return nil
        }
    }

    var coloris: Jetons.Coloris? {
        if case .coloris(let coloris) = self { coloris } else { nil }
    }
}

enum ConversionDuTheme {
    /// La nuance écrite quand l'app suit le système.
    static let systeme = "systeme"

    struct Relu: Equatable {
        var theme = Jetons.themeParDefaut
        var nuance = Jetons.nuanceParDefaut
    }

    static func nuance(ecrite: String?) -> Jetons.Nuance? {
        ecrite == systeme ? nil : ecrite.flatMap(Jetons.Nuance.init(rawValue:)) ?? Jetons.nuanceParDefaut
    }

    /// Les réglages d'avant : une couleur restée au défaut d'alors (jade, fonds Auto) prend le thème
    /// d'aujourd'hui ; un préréglage, le coloris le plus proche ; une teinte, Personnalisé. Les fonds
    /// n'ont plus de réglage (la nuance porte le fond) ; Clair et Sombre imposés deviennent Jour et
    /// Pénombre, Auto suit toujours le système.
    static func relire(couleur: String?, fonds: String?, apparence: String?) -> Relu {
        var relu = Relu()
        switch apparence {
        case "clair": relu.nuance = .jour
        case "sombre": relu.nuance = .penombre
        default: break
        }
        guard let couleur, couleur != "jade" || fonds != nil else { return relu }
        if couleur.hasPrefix("teinte:"), let t = Int(couleur.dropFirst(7)) {
            relu.theme = .personnalise(personnalise(angleOklab: Double(((t % 360) + 360) % 360)))
        } else if let coloris = colorisDuPrereglage[couleur] {
            relu.theme = .coloris(coloris)
        }
        return relu
    }

    /// Le coloris le plus proche de chaque préréglage d'avant.
    static let colorisDuPrereglage: [String: Jetons.Coloris] = [
        "azur": .bleuet, "jade": .lagon, "framboise": .cerise, "corail": .terracotta, "ardoise": .graphite,
    ]

    /// `teinte:N` était un angle OKLCH (la table du SDS v1), pas une teinte TSL : lu en TSL, un
    /// bleu-vert de 240 devenait indigo (jusqu'à 50° d'écart). Personnalisé prend la teinte TSL
    /// dont l'angle OKLab est le plus proche.
    static func personnalise(angleOklab cible: Double) -> UInt32 {
        func ecart(_ couleur: UInt32) -> Double {
            let lab = Jetons.Oklab.lab(Jetons.Octets(couleur), nil)
            let d = abs((atan2(lab[2], lab[1]) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360) - cible)
            return min(d, 360 - d)
        }
        let candidates = (0..<360).map { aLaTeinte(Jetons.personnaliseParDefaut, $0) }
        return candidates.min { ecart($0) < ecart($1) } ?? Jetons.personnaliseParDefaut
    }

    /// Sa teinte TSL, en degrés entiers (0…359), celle que montre le curseur.
    static func teinte(_ couleur: UInt32) -> Int { Int(Jetons.Octets(couleur).tsl.0.rounded()) % 360 }

    /// La même couleur à une autre teinte : une couleur terne prend la saturation du curseur, sinon
    /// il ne changerait rien ; la clarté est bornée comme dans le nuancier.
    static func aLaTeinte(_ couleur: UInt32, _ teinte: Int) -> UInt32 {
        typealias P = Jetons.Parametres.Personnalise
        let (_, s, l) = Jetons.Octets(couleur).tsl
        let voulue = min(360, max(0, teinte)) % 360
        let (saturation, clarte) = (max(s, P.saturationCurseurMin), min(P.clarte[1], max(P.clarte[0], l)))
        // À l'octet, une couleur pâle ne tombe pas sur chaque degré : on cherche, à moins d'un degré
        // près, celle qui se relit à la teinte demandée, sinon le curseur sauterait d'un cran.
        let ecarts = [0.0] + stride(from: 0.1, through: 1, by: 0.1).flatMap { [$0, -$0] }
        let couleurs = ecarts.lazy.map {
            Jetons.Octets.tsl((Double(voulue) + $0 + 360).truncatingRemainder(dividingBy: 360), saturation, clarte).hex
        }
        return couleurs.first { Self.teinte($0) == voulue } ?? Jetons.Octets.tsl(Double(voulue), saturation, clarte).hex
    }
}
