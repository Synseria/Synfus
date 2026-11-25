import Foundation

/// Ce qui s'enregistre du thème (Réglages ▸ Thème), et la conversion des réglages d'avant le nuancier
/// (une couleur parmi cinq ou une teinte, une teinte des fonds, une apparence). Une valeur illisible
/// n'est pas un choix : le réglage retombe sur son défaut sans toucher au reste.
extension Jetons.Theme.Primaire {
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
        } else if ecrit.hasPrefix(Self.prefixePersonnalise), let couleur = ConversionDuTheme.hex(ecrit.dropFirst(Self.prefixePersonnalise.count)) {
            self = .personnalise(couleur)
        } else {
            return nil
        }
    }
}

extension Jetons.Fond {
    /// `ardoise`, ou `#3F7A80` pour une couleur à soi.
    var ecrit: String {
        switch self {
        case .nomme(let nomme): nomme.rawValue
        case .personnalise(let couleur): String(format: "#%06X", couleur)
        }
    }

    init?(ecrit: String) {
        if let nomme = Jetons.FondNomme(rawValue: ecrit) {
            self = .nomme(nomme)
        } else if ecrit.hasPrefix("#"), let couleur = ConversionDuTheme.hex(ecrit.dropFirst()) {
            self = .personnalise(couleur)
        } else {
            return nil
        }
    }
}

extension Jetons.Theme {
    var coloris: Jetons.Coloris? {
        if case .coloris(let coloris) = primaire { coloris } else { nil }
    }

    /// Le thème avec cette primaire : un fond choisi reste, celui du thème suit la primaire. Toute
    /// écriture de la couleur passe par ici : `.coloris(_:)` seul effacerait le fond choisi.
    func avecLaPrimaire(_ nouvelle: Primaire) -> Jetons.Theme { Jetons.Theme(nouvelle, fond: fond) }

    /// Le thème avec ce fond ; choisir celui de la primaire revient à le suivre (nil) : changer de
    /// couleur changera alors le fond aussi, ce qu'un fond choisi ne fait jamais.
    func avecLeFond(_ choisi: Jetons.Fond?) -> Jetons.Theme {
        Jetons.Theme(primaire, fond: choisi == .nomme(fondParDefaut) ? nil : choisi)
    }

    /// Le fond appliqué : le choisi, sinon celui du thème.
    var fondApplique: Jetons.Fond { fond ?? .nomme(fondParDefaut) }

    /// Un coloris sur un fond nommé (ou le sien) : aucune couleur à soi.
    var estNomme: Bool {
        if case .personnalise = fond { return false }
        return coloris != nil
    }
}

enum ConversionDuTheme {
    /// La nuance écrite quand l'app suit le système.
    static let systeme = "systeme"

    struct Relu: Equatable {
        var theme = Jetons.themeParDefaut
        var nuance = Jetons.nuanceParDefaut
    }

    /// Une couleur écrite `RRGGBB` ; nil si illisible.
    static func hex(_ texte: Substring) -> UInt32? {
        guard let couleur = UInt32(texte, radix: 16), couleur <= 0xFFFFFF else { return nil }
        return couleur
    }

    static func nuance(ecrite: String?) -> Jetons.Nuance? {
        ecrite == systeme ? nil : ecrite.flatMap(Jetons.Nuance.init(rawValue:)) ?? Jetons.nuanceParDefaut
    }

    /// Les réglages d'avant : un préréglage prend le coloris le plus proche (jade, le défaut d'alors,
    /// devient Lagon, celui d'aujourd'hui) ; une teinte, Personnalisé. La teinte des fonds d'alors
    /// (`fondsDeLApp`) n'a pas d'équivalent : le fond du thème la remplace. Clair et Sombre imposés
    /// deviennent Jour et Pénombre, Auto suit toujours le système.
    static func relire(couleur: String?, apparence: String?) -> Relu {
        var relu = Relu()
        switch apparence {
        case "clair": relu.nuance = .jour
        case "sombre": relu.nuance = .penombre
        default: break
        }
        guard let couleur else { return relu }
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
