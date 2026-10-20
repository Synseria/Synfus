import Foundation

/// La confusion du Comte Harebourg : à chaque début de tour, les sorts d'un
/// perso tombent sur la case visée **tournée autour de lui** d'un quart de
/// tour, d'un demi-tour ou de trois quarts. Elle se constate au canal combat
/// (« 90° horaire », « contre horaire 3Pi/2 »…), ou se déduit du pourcentage
/// de vie au début du tour. Chaque ligne de dégâts portée au corps à corps la
/// tourne encore d'un quart de tour contre-horaire. Pur.
enum Harebourg {
    /// Une déviation en quarts de tour **horaires**, de 0 à 3 : le sort tombe
    /// sur la case visée tournée d'autant autour du lanceur.
    struct Confusion: Hashable, Sendable {
        let quarts: Int

        init(quarts: Int) { self.quarts = ((quarts % 4) + 4) % 4 }

        static let aucune = Confusion(quarts: 0)
        static let horaire = Confusion(quarts: 1)
        static let demiTour = Confusion(quarts: 2)
        static let contreHoraire = Confusion(quarts: 3)

        /// Après `lignes` lignes de dégâts au corps à corps, un quart de tour
        /// contre-horaire chacune.
        func apres(coups lignes: Int) -> Confusion { Confusion(quarts: quarts - lignes) }

        /// Où viser par rapport à la cible, vu du lanceur : la case qui, tournée
        /// de la confusion, retombe sur la cible.
        var visee: Visee {
            switch quarts {
            case 1: return .gauche
            case 2: return .opposee
            case 3: return .droite
            default: return .cible
            }
        }

        /// La case à viser pour toucher la cible, en cases depuis le lanceur
        /// (x vers la droite, y vers le bas de la grille) : la cible tournée
        /// à rebours de la confusion. La projection isométrique du jeu garde
        /// le sens de rotation : « horaire » l'est aussi à l'écran.
        func caseVisee(cible: (x: Int, y: Int)) -> (x: Int, y: Int) {
            var point = cible
            // Un quart de tour contre-horaire, y vers le bas : (x, y) → (y, −x).
            for _ in 0..<quarts { point = (point.y, -point.x) }
            return point
        }
    }

    /// Où viser, par rapport à la cible vue du lanceur.
    enum Visee: Sendable {
        case cible
        /// Un quart de tour contre-horaire : à gauche de la cible.
        case gauche
        /// Le demi-tour : la case symétrique de la cible par rapport au lanceur.
        case opposee
        case droite
    }

    // MARK: - Par les points de vie

    /// Ce que dit le pourcentage de vie au début du tour : la confusion de sa
    /// tranche et, tout près d'une limite, celle de la voisine — les joueurs
    /// relèvent que les tranches frontières donnent l'une ou l'autre.
    struct ParVie: Equatable, Sendable {
        let confusion: Confusion
        let voisine: Confusion?
    }

    /// Les tranches relevées par les joueurs (Papycha, Dofus pour les noobs) :
    /// 100–91 % horaire, 90–75 % contre-horaire, 74–46 % demi-tour, 45–31 %
    /// contre-horaire, 30–1 % horaire. Chaque plancher tombe entre deux
    /// pourcentages entiers.
    private static let tranches: [(plancher: Double, confusion: Confusion)] = [
        (90.5, .horaire), (74.5, .contreHoraire), (45.5, .demiTour), (30.5, .contreHoraire), (-.infinity, .horaire),
    ]

    /// À moins d'un point d'une limite, la tranche voisine est possible : le
    /// jeu arrondit le pourcentage qu'il montre, ses limites exactes ne sont
    /// pas publiées.
    static let margeFrontiere = 1.0

    static func parVie(pourcentage: Double) -> ParVie {
        let index = tranches.firstIndex { pourcentage > $0.plancher } ?? tranches.count - 1
        var voisine: Confusion?
        if index + 1 < tranches.count, pourcentage - tranches[index].plancher < margeFrontiere {
            voisine = tranches[index + 1].confusion
        } else if index > 0, tranches[index - 1].plancher - pourcentage < margeFrontiere {
            voisine = tranches[index - 1].confusion
        }
        return ParVie(confusion: tranches[index].confusion, voisine: voisine)
    }

    /// Ce que montre le cœur de vie du jeu : son pourcentage (un clic dessus
    /// le fait afficher), ou ses points, avec leur maximum s'il est écrit.
    enum Vie: Equatable, Sendable {
        case pourcentage(Double)
        case points(actuels: Int, max: Int?)

        /// Le pourcentage, s'il se sait — par le maximum lu ou retenu.
        func pourcentage(maxConnu: Int?) -> Double? {
            switch self {
            case .pourcentage(let valeur): return valeur
            case .points(let actuels, let max):
                guard let max = max ?? maxConnu, max > 0, actuels <= max else { return nil }
                return Double(actuels) / Double(max) * 100
            }
        }
    }

    /// Le cœur lu par l'OCR : « 57% », « 57 % », « 3 450 / 4 200 », « 3450 ».
    /// Les milliers peuvent être séparés d'une espace (fine ou non) ou d'un
    /// point. `nil` : rien de lisible.
    static func vie(_ lignes: [String]) -> Vie? {
        let texte = lignes.joined(separator: " ")
        if let match = texte.firstMatch(of: /(\d{1,3})\s*%/), let valeur = Double(match.1), valeur <= 100 {
            return .pourcentage(valeur)
        }
        let nombres = texte.matches(of: /\d{1,3}(?:[ \u{00A0}\u{202F}.,]\d{3})+|\d+/).compactMap { entier($0.output) }
        if let barre = texte.firstMatch(of: /(\d[\d \u{00A0}\u{202F}.,]*)\s*\/\s*(\d[\d \u{00A0}\u{202F}.,]*)/),
           let actuels = entier(barre.1), let max = entier(barre.2), max > 0 {
            return .points(actuels: actuels, max: max)
        }
        guard let actuels = nombres.first, actuels > 0 else { return nil }
        return .points(actuels: actuels, max: nil)
    }

    private static func entier(_ texte: Substring) -> Int? {
        let chiffres = texte.filter { $0.isASCII && $0.isNumber }
        return chiffres.count <= 7 ? Int(chiffres) : nil
    }

    // MARK: - Au canal combat

    /// Une confusion lue au canal combat, et le perso qu'elle vise quand la
    /// ligne le nomme (« [14:04] Syn-App : … »).
    struct Constat: Equatable, Sendable {
        let confusion: Confusion
        let perso: String?
    }

    /// La dernière confusion annoncée dans les lignes du tchat, de la plus
    /// récente (en bas) à la plus ancienne, et l'index de sa ligne. Une ligne
    /// trop longue se replie : l'angle peut passer sur la suivante, que le jeu
    /// écrit sans heure.
    static func dernierConstat(_ lignes: [String], persos: [String]) -> (constat: Constat, ligne: Int)? {
        for index in lignes.indices.reversed() {
            let ligne = lignes[index]
            // La suite d'une ligne repliée : son début, au-dessus, porte le nom.
            let entiere = index > 0 && heure(ligne) == nil ? lignes[index - 1] + " " + ligne : ligne
            guard let confusion = confusion(ligne) ?? confusion(entiere) else { continue }
            return (Constat(confusion: confusion, perso: perso(entiere, parmi: persos)), index)
        }
        return nil
    }

    /// La confusion dite par une ligne : un angle — en degrés (« 90° ») ou en
    /// fraction de Pi (« 3Pi/2 », « 1/2 pi », « π ») — et son sens
    /// (« horaire », « contre horaire »), que le jeu écrit toujours, demi-tour
    /// compris : sans lui, un nombre suivi d'un degré n'est pas une confusion.
    static func confusion(_ ligne: String) -> Confusion? {
        let texte = " " + ligne.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        guard let sens = sens(texte), let demis = demiTours(texte) else { return nil }
        let quarts = demis * 2
        guard quarts > 0, quarts == quarts.rounded(), quarts < 100 else { return nil }
        return Confusion(quarts: sens * Int(quarts))
    }

    /// L'angle d'une ligne, en demi-tours (90° → 0,5). Le caractère qui
    /// précède le nombre est consommé plutôt que regardé en arrière : « 14:04 »
    /// ou « 1% » ne donnent pas d'angle.
    private static func demiTours(_ texte: String) -> Double? {
        // « 90° », « 270 ° » ; l'OCR lit parfois le degré comme un « º ».
        if let match = texte.firstMatch(of: /[^\d.,:](\d{2,3})\s*(?:°|º|˚|deg)/), let degres = Double(match.1) {
            return degres / 180
        }
        // « 1/2 pi », « 1/2π » : la fraction devant.
        if let match = texte.firstMatch(of: /[^\d\/](\d)\s*\/\s*(\d)\s*(?:pi|π)(?![a-z])/),
           let haut = Double(match.1), let bas = Double(match.2), bas > 0 {
            return haut / bas
        }
        // « 3Pi/2 », « Pi/2 », « π ».
        if let match = texte.firstMatch(of: /[^a-z\d](\d)?\s*(?:pi|π)(?![a-z])(?:\s*\/\s*(\d))?/) {
            let haut = match.1.flatMap { Double($0) } ?? 1
            let bas = match.2.flatMap { Double($0) } ?? 1
            return bas > 0 ? haut / bas : nil
        }
        return nil
    }

    /// +1 horaire, −1 contre-horaire ; `nil` sans sens lisible. Les sens de
    /// l'anglais et de l'espagnol aussi : le jeu se joue dans les trois.
    private static func sens(_ texte: String) -> Int? {
        if texte.contains(/(contre|anti)[\s-]*(horaire|clockwise|horario)|counter[\s-]*clockwise/) { return -1 }
        if texte.contains(/horaire|clockwise|horario/) { return 1 }
        return nil
    }

    /// L'heure qui ouvre chaque ligne du tchat, « [14:04] » ; l'OCR mange
    /// parfois les crochets.
    static func heure(_ ligne: String) -> Substring? {
        ligne.firstMatch(of: /^\s*\[?\s*\d{1,2}\s*[:h.]\s*\d{2}\s*\]?/).map { ligne[$0.range] }
    }

    /// Le perso qu'une ligne nomme avant ses deux-points (« [14:04] Syn-App :
    /// … »), parmi les noms connus, à une faute près.
    static func perso(_ ligne: String, parmi persos: [String]) -> String? {
        let reste = heure(ligne).map { ligne[$0.endIndex...] } ?? Substring(ligne)
        guard let deuxPoints = reste.firstIndex(of: ":") else { return nil }
        let lu = Ressemblance.normaliser(String(reste[..<deuxPoints]))
        guard !lu.isEmpty else { return nil }
        let proches = persos.map { ($0, fautes(lu, $0)) }.filter { $0.1 <= 1 }
        return proches.min { $0.1 < $1.1 }?.0
    }

    /// Les fautes entre un nom lu et un nom connu, d'un bout à l'autre.
    private static func fautes(_ lu: String, _ perso: String) -> Int {
        let attendu = Ressemblance.normaliser(perso)
        guard abs(attendu.count - lu.count) <= 1 else { return Int.max }
        return Ressemblance.distanceDansTexte(attendu, lu) + max(0, lu.count - attendu.count)
    }
}
