import Foundation

/// Ce que la zone du bouton de fin de tour dit du combat — pur : on lui donne
/// les lignes lues et la part de rose de l'image, il rend un constat.
///
/// Le jeu n'expose rien de l'état du combat ; le bouton, lui, le montre. Hors
/// combat il n'existe pas. En combat il porte « Fin de tour » : **rose** quand
/// c'est le tour du perso, **gris** sinon, avec au-dessus le décompte du tour
/// (« 29s »). En phase de placement il invite à se déclarer prêt.
///
/// La couleur se mesure (`ratioRose`), le texte se lit : un texte « tour »
/// sur fond rose, c'est mon tour ; le même sur fond gris, celui d'un autre.
/// Le décompte n'est lu qu'au changement d'état — le chiffre est vert,
/// sous le seuil de l'`EmpreinteTexte`, et ne relance pas l'OCR chaque
/// seconde : l'échéance est calculée une fois, le compte à rebours est local.
enum LectureCombat {
    enum Genre: Equatable, Sendable {
        case horsCombat
        case placement
        case monTour
        case pasMonTour
    }

    struct Constat: Equatable, Sendable {
        let genre: Genre
        /// Secondes restantes lues sur le décompte, s'il y en avait un.
        let secondes: Int?
    }

    /// Part de pixels roses au-delà de laquelle le bouton est « à moi ».
    /// Mesuré : le bouton actif couvre ~ 21 % de la zone par défaut.
    static let seuilRose = 0.12

    /// Mots qui signent le bouton, dans les trois langues du jeu, sans
    /// accents ni espaces — l'OCR en mange parfois.
    private static let motsTour = ["FINDETOUR", "ENDTURN", "FINDETURNO", "FINDELTURNO", "TOUR", "TURN"]
    private static let motsPret = ["PRET", "READY", "LISTO"]

    static func classer(lignes: [String], rose: Double) -> Constat {
        let textes = lignes.map(normaliser)
        let secondes = lignes.lazy.compactMap(decompte).first
        if textes.contains(where: { t in motsPret.contains { t.contains($0) } }) {
            return Constat(genre: .placement, secondes: secondes)
        }
        guard textes.contains(where: { t in motsTour.contains { t.contains($0) } }) else {
            return Constat(genre: .horsCombat, secondes: nil)
        }
        return Constat(genre: rose >= seuilRose ? .monTour : .pasMonTour, secondes: secondes)
    }

    /// « 29s », « 29 s », « 5S » → 29, 29, 5.
    static func decompte(_ ligne: String) -> Int? {
        let propre = ligne.trimmingCharacters(in: .whitespaces)
        guard let dernier = propre.last, dernier == "s" || dernier == "S" else { return nil }
        let chiffres = propre.dropLast().trimmingCharacters(in: .whitespaces)
        guard !chiffres.isEmpty, chiffres.count <= 3, chiffres.allSatisfy({ $0.isASCII && $0.isNumber })
        else { return nil }
        return Int(chiffres)
    }

    private static func normaliser(_ texte: String) -> String {
        texte.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .uppercased()
            .filter { $0.isLetter }
    }

    /// Part des pixels d'une image RGBA (8 bits, 4 octets par pixel) dont la
    /// teinte est le rose du bouton : 280°–340°, assez saturée, assez claire.
    /// Le liseré sombre du bouton (v < 0,35) et le fond gris n'y entrent pas.
    static func ratioRose(rgba: [UInt8]) -> Double {
        let total = rgba.count / 4
        guard total > 0 else { return 0 }
        var roses = 0
        for i in stride(from: 0, to: total * 4, by: 4) {
            let r = Double(rgba[i]) / 255, g = Double(rgba[i + 1]) / 255, b = Double(rgba[i + 2]) / 255
            let maxi = max(r, g, b), mini = min(r, g, b)
            guard maxi >= 0.35, maxi > 0, (maxi - mini) / maxi >= 0.3 else { continue }
            let delta = maxi - mini
            var teinte: Double
            switch maxi {
            case r: teinte = 60 * ((g - b) / delta)
            case g: teinte = 60 * ((b - r) / delta + 2)
            default: teinte = 60 * ((r - g) / delta + 4)
            }
            if teinte < 0 { teinte += 360 }
            if teinte >= 280, teinte <= 340 { roses += 1 }
        }
        return Double(roses) / Double(total)
    }
}

/// L'état de combat d'un perso, tel que la barre l'affiche.
enum EtatCombat: Equatable, Sendable {
    case horsCombat
    case placement
    /// `fin` : l'échéance du décompte, si on l'a lu.
    case monTour(fin: Date?)
    case pasMonTour

    var enCombat: Bool { self != .horsCombat }

    /// Le constat d'une lecture, compte tenu de l'état d'avant : un tour qui
    /// continue garde son échéance si le décompte n'a pas été relu.
    static func depuis(_ constat: LectureCombat.Constat, avant: EtatCombat?, maintenant: Date) -> EtatCombat {
        switch constat.genre {
        case .horsCombat: return .horsCombat
        case .placement: return .placement
        case .pasMonTour: return .pasMonTour
        case .monTour:
            if let secondes = constat.secondes {
                return .monTour(fin: maintenant.addingTimeInterval(TimeInterval(secondes)))
            }
            if case .monTour(let fin) = avant { return .monTour(fin: fin) }
            return .monTour(fin: nil)
        }
    }
}
