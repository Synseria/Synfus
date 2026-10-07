import Foundation

/// Les commandes `/travel` et `/zaap`, et faut-il passer par un zaap pour aller
/// où dit un `/travel` ? Pur : on lui donne le texte et la position lue, il
/// rend le texte à poser — ou `nil`, et le presse-papiers reste intact.
///
/// Le presse-papiers n'est réécrit que s'il contient **exactement** une
/// commande `/travel x,y` : tout autre texte est ignoré, quel qu'il soit.
enum ItineraireZaap {
    static let gainParDefaut = 5
    static let gainsPossibles = 1...30

    static func travel(vers cible: (x: Int, y: Int)) -> String {
        "/travel \(cible.x),\(cible.y)"
    }

    static func zaap(_ zaap: Zaap) -> String {
        "/zaap \(zaap.x),\(zaap.y)"
    }

    /// La case où rejoindre un perso d'après sa position lue — `nil` hors du
    /// Monde des Douze : un `/travel` y viserait la case homonyme d'Amakna.
    static func rejoindre(_ position: PositionCarte?) -> (x: Int, y: Int)? {
        guard let position, !horsDuMondeDesDouze(position.zone) else { return nil }
        return (position.x, position.y)
    }

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

    static func zaapLePlusProche(de cible: (x: Int, y: Int), parmi zaaps: [Zaap]) -> Zaap? {
        zaaps.min { distance(($0.x, $0.y), cible) < distance(($1.x, $1.y), cible) }
    }

    /// `/zaap x,y; /travel a,b` si le zaap de `zaaps` le plus proche de la
    /// cible épargne au moins `gainMinimal` cartes depuis `position` ; `nil` sinon.
    static func reecrire(
        _ texte: String, depuis position: PositionCarte?, gainMinimal: Int, zaaps: [Zaap]
    ) -> String? {
        guard let cible = cible(dans: texte),
              let position, !horsDuMondeDesDouze(position.zone),
              let zaap = zaapLePlusProche(de: cible, parmi: zaaps)
        else { return nil }
        let gain = distance((position.x, position.y), cible) - distance((zaap.x, zaap.y), cible)
        guard gain >= gainMinimal else { return nil }
        let travel = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(Self.zaap(zaap)); \(travel)"
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
