import Foundation

/// Faut-il passer par un zaap pour aller où dit le `/travel` copié ? Pur : on
/// lui donne le texte du presse-papiers et la position lue, il rend le texte à
/// poser — ou `nil`, et le presse-papiers reste intact.
///
/// Le presse-papiers n'est réécrit que s'il contient **exactement** une
/// commande `/travel x,y` : tout autre texte est ignoré, quel qu'il soit.
enum ItineraireZaap {
    static let gainParDefaut = 5
    static let gainsPossibles = 1...30

    /// La case visée par `/travel x,y` — aussi `x y`, `[x,y]` ou `x, y`, les
    /// formes que copient les sites de cartes. Rien d'autre sur la ligne.
    static func cible(dans texte: String) -> (x: Int, y: Int)? {
        let ligne = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ligne.hasPrefix("/travel "), !ligne.contains(where: \.isNewline) else { return nil }
        var reste = ligne.dropFirst("/travel ".count).trimmingCharacters(in: .whitespaces)
        if reste.hasPrefix("["), reste.hasSuffix("]") {
            reste = String(reste.dropFirst().dropLast())
        }
        let morceaux = reste.split(whereSeparator: { $0 == "," || $0 == " " })
        guard morceaux.count == 2,
              let x = Int(morceaux[0]), let y = Int(morceaux[1]),
              abs(x) <= PositionCarte.borne, abs(y) <= PositionCarte.borne
        else { return nil }
        return (x, y)
    }

    /// Le nombre de cartes à traverser : l'autopilote va de carte voisine en
    /// carte voisine, jamais en diagonale.
    static func distance(_ a: (x: Int, y: Int), _ b: (x: Int, y: Int)) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    static func zaapLePlusProche(de cible: (x: Int, y: Int)) -> Zaap? {
        Zaap.tous.min { distance(($0.x, $0.y), cible) < distance(($1.x, $1.y), cible) }
    }

    /// `/zaap x,y; /travel a,b` si le zaap le plus proche de la cible épargne
    /// au moins `gainMinimal` cartes depuis `position` ; `nil` sinon.
    static func reecrire(_ texte: String, depuis position: PositionCarte?, gainMinimal: Int) -> String? {
        guard let cible = cible(dans: texte),
              let position, !horsDuMondeDesDouze(position.zone),
              let zaap = zaapLePlusProche(de: cible)
        else { return nil }
        let gain = distance((position.x, position.y), cible) - distance((zaap.x, zaap.y), cible)
        guard gain >= gainMinimal else { return nil }
        let travel = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        return "/zaap \(zaap.x),\(zaap.y); \(travel)"
    }

    /// Les régions dont les coordonnées ne sont pas celles du Monde des Douze
    /// (DofusDB, `superAreaId` ≠ 0), en fr, en et es : depuis Incarnam, « -2,0 »
    /// n'est pas à deux cartes du zaap d'Amakna. Le nom lu commence par la
    /// région : « Incarnam (Pâturages) ».
    private static let regionsAilleurs = [
        "Incarnam", "Convention", "Convención", "Enutrosor", "Enurado", "Anutropía",
        "Srambad", "Sramvil", "Xélorium", "Xelorium", "Ecaflipus", "Zurcalia",
        "Domaine des fils d'Ecaflip", "Realm of the Sons of Ecaflip", "Dominio de los hijos de Zurcarák",
        "Externam", "Dimension Obscure", "Lost Dimension", "Dimensión obscura",
        "Ingloriom", "Inglorium", "Rêve du Monde des Douze", "Dream of the World of Twelve",
        "Sueño del Mundo de los Doce", "Éther", "Ether", "Éter",
        "Plan Astral", "Astral Plane", "Plano astral",
    ]

    static func horsDuMondeDesDouze(_ zone: String?) -> Bool {
        guard let zone else { return false }
        return regionsAilleurs.contains {
            zone.range(of: $0, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
