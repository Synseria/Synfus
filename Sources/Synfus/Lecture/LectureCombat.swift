import CoreGraphics
import Foundation

/// Ce que la zone du bouton de fin de tour dit du combat — pur : on lui donne
/// les lignes lues et la part de couleur du bouton, il rend un constat.
///
/// Le jeu n'expose rien de l'état du combat ; le bouton, lui, le montre. Hors
/// combat il n'existe pas. En combat il porte « Fin de tour » : **en
/// couleur** quand c'est le tour du perso — rose par défaut, mais les thèmes
/// du jeu la changent —, **gris** sinon, toujours : c'est ce gris qui fait
/// foi. Au-dessus, le décompte du tour (« 29s »). En phase de placement il
/// invite à se déclarer prêt.
///
/// La couleur se mesure (`ratioColore`, sur le seul corps du bouton,
/// `corpsDuBouton`), le texte se lit : « tour » sur un bouton coloré, c'est
/// mon tour ; sur un bouton gris, celui d'un autre.
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

    /// Part de pixels colorés du corps du bouton au-delà de laquelle il est
    /// « à moi ». Mesuré : bouton rose ≫ seuil, bouton grisé à 0 %.
    static let seuilBouton = 0.25
    /// Part colorée de la zone entière dont le franchissement relance l'OCR :
    /// le même « Fin de tour » blanc passe du gris à la couleur sans qu'un
    /// pixel clair ne bouge. Mesuré : ~ 21 % à son tour (rose), 0 % grisé.
    static let seuilSignature = 0.10

    /// Mots qui signent le bouton, dans les trois langues du jeu, sans
    /// accents ni espaces — l'OCR en mange parfois.
    private static let motsTour = ["FINDETOUR", "ENDTURN", "FINDETURNO", "FINDELTURNO", "TOUR", "TURN"]
    private static let motsPret = ["PRET", "READY", "LISTO"]

    static func classer(lignes: [String], couleur: Double) -> Constat {
        let textes = lignes.map(normaliser)
        let secondes = lignes.lazy.compactMap(decompte).first
        if textes.contains(where: { t in motsPret.contains { t.contains($0) } }) {
            return Constat(genre: .placement, secondes: secondes)
        }
        guard textes.contains(where: { t in motsTour.contains { t.contains($0) } }) else {
            return Constat(genre: .horsCombat, secondes: nil)
        }
        return Constat(genre: couleur >= seuilBouton ? .monTour : .pasMonTour, secondes: secondes)
    }

    /// Le texte qui signe le bouton de fin de tour ou de placement.
    static func estBouton(_ ligne: String) -> Bool {
        let t = normaliser(ligne)
        return (motsTour + motsPret).contains { t.contains($0) }
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

    /// Part des pixels **colorés** d'une image RGBA (8 bits, 4 octets par
    /// pixel), dans le rectangle donné (en pixels, origine en haut à gauche ;
    /// l'image entière par défaut) : assez saturés, assez clairs, quelle que
    /// soit la teinte. Le liseré sombre (v < 0,35), le gris et le blanc du
    /// texte n'y entrent pas, pas plus que la lavande pâle des icônes voisines
    /// (s ≈ 0,16, mesuré).
    static func ratioColore(rgba: [UInt8], largeur: Int, dans rect: CGRect? = nil) -> Double {
        let hauteur = largeur > 0 ? rgba.count / 4 / largeur : 0
        guard largeur > 0, hauteur > 0 else { return 0 }
        let cadre = (rect ?? CGRect(x: 0, y: 0, width: largeur, height: hauteur))
            .intersection(CGRect(x: 0, y: 0, width: largeur, height: hauteur)).integral
        guard !cadre.isNull, cadre.width > 0, cadre.height > 0 else { return 0 }
        var colores = 0, total = 0
        for y in Int(cadre.minY)..<min(Int(cadre.maxY), hauteur) {
            for x in Int(cadre.minX)..<min(Int(cadre.maxX), largeur) {
                let i = (y * largeur + x) * 4
                let r = Double(rgba[i]), g = Double(rgba[i + 1]), b = Double(rgba[i + 2])
                let maxi = max(r, g, b), mini = min(r, g, b)
                total += 1
                if maxi >= 0.35 * 255, (maxi - mini) / maxi >= 0.3 { colores += 1 }
            }
        }
        return total == 0 ? 0 : Double(colores) / Double(total)
    }

    /// Le corps du bouton autour de son texte : la boîte du texte lu,
    /// élargie de part et d'autre, bornée à l'image. C'est là que la couleur
    /// se mesure — la zone entière contient aussi le décompte (vert à son
    /// tour) et un bout de décor.
    static func corpsDuBouton(texte: CGRect, image: CGSize) -> CGRect {
        texte.insetBy(dx: -texte.width * 0.2, dy: -texte.height * 0.9)
            .intersection(CGRect(origin: .zero, size: image))
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
