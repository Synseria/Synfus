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
        guard let position, !position.horsDuMondeDesDouze else { return nil }
        return (position.x, position.y)
    }

    /// Les cartes à pied du perso jusqu'à une case — `nil` si l'un ou l'autre
    /// est hors du Monde des Douze, ou la position inconnue : les coordonnées
    /// d'Incarnam recoupent celles d'Amakna sans en être.
    static func aPied(depuis position: PositionCarte?, vers cible: (x: Int, y: Int), dansLesDouze: Bool) -> Int? {
        guard dansLesDouze, let depart = rejoindre(position) else { return nil }
        return distance(depart, cible)
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

    private static func zaapLePlusProche(de cible: (x: Int, y: Int), parmi zaaps: [Zaap]) -> Zaap? {
        zaaps.min { distance(($0.x, $0.y), cible) < distance(($1.x, $1.y), cible) }
    }

    /// Les cartes que le zaap des sous-zones voisines doit épargner, jusqu'à
    /// la cible, pour l'emporter sur celui que désigne le jeu.
    static let ecartZaapDuJeu = 5

    /// Le zaap d'où rejoindre la cible. Le plus proche à vol d'oiseau peut
    /// être derrière une montagne : le plus proche en sous-zones traversées (à
    /// égalité, en cartes). Avec `zaapDuJeu`, plutôt celui que le jeu associe
    /// à la sous-zone de la cible, s'il est actif — l'autopilote connaît des
    /// raccourcis que la carte ne dit pas —, sauf si celui des sous-zones
    /// épargne au moins `ecartZaapDuJeu` cartes : une grande sous-zone peut se
    /// voir rattacher un zaap lointain. Sans sous-zone joignable — cible hors
    /// du Monde des Douze relevé, sous-zone isolée —, le plus proche à vol d'oiseau.
    static func zaap(vers cible: (x: Int, y: Int), parmi zaaps: ZaapsSitues, zaapDuJeu: Bool) -> Zaap? {
        guard let depart = zaaps.reseau.sousZone(cible.x, cible.y) else {
            return zaapLePlusProche(de: cible, parmi: zaaps.liste)
        }
        let voisin = parLesSousZones(depuis: depart, vers: cible, parmi: zaaps)
        if zaapDuJeu, let associe = zaaps.reseau.zaapAssocie(depart).flatMap(zaaps.zaap(carte:)) {
            // Le vol d'oiseau ne détrône pas le jeu : il ignore les montagnes.
            guard let voisin,
                  distance((associe.x, associe.y), cible) - distance((voisin.x, voisin.y), cible) >= ecartZaapDuJeu
            else { return associe }
            return voisin
        }
        return voisin ?? zaapLePlusProche(de: cible, parmi: zaaps.liste)
    }

    /// Le plus proche de la cible parmi les zaaps du premier cercle de
    /// sous-zones qui en a, depuis celle de la cible ; `nil` si aucun n'est joignable.
    private static func parLesSousZones(depuis depart: Int, vers cible: (x: Int, y: Int),
                                        parmi zaaps: ZaapsSitues) -> Zaap? {
        var vues: Set<Int> = [depart]
        var cercle = [depart]
        while !cercle.isEmpty {
            let atteints = cercle.flatMap(zaaps.zaaps(dans:))
            if !atteints.isEmpty { return zaapLePlusProche(de: cible, parmi: atteints) }
            cercle = cercle.flatMap(zaaps.reseau.voisines).filter { vues.insert($0).inserted }
        }
        return nil
    }

    /// Le zaap de la cible (`zaap(vers:)`), s'il épargne au moins
    /// `gainMinimal` cartes depuis `depart` ; `nil` : on y va à pied.
    static func zaapUtile(depuis depart: (x: Int, y: Int), vers cible: (x: Int, y: Int), zaap: Zaap?,
                          gainMinimal: Int) -> Zaap? {
        guard let zaap, distance(depart, cible) - distance((zaap.x, zaap.y), cible) >= gainMinimal else { return nil }
        return zaap
    }

    /// Un trajet copié : le zaap pris, s'il l'est, et les cartes à traverser.
    struct Trajet: Equatable, Sendable {
        let zaap: Zaap?
        let cartes: Int
    }

    /// Le trajet de `depart` à `cible`, par le zaap s'il est utile (`zaapUtile`).
    static func trajet(depuis depart: (x: Int, y: Int), vers cible: (x: Int, y: Int), zaap: Zaap?,
                       gainMinimal: Int) -> Trajet {
        let par = zaapUtile(depuis: depart, vers: cible, zaap: zaap, gainMinimal: gainMinimal)
        return Trajet(zaap: par, cartes: distance(par.map { ($0.x, $0.y) } ?? depart, cible))
    }

    /// Le trajet qu'un `/travel` vers `cible` copié depuis `position` suivrait
    /// (`reecrire`) ; `nil` hors du Monde des Douze ou sans position.
    static func trajet(vers cible: (x: Int, y: Int), depuis position: PositionCarte?, gainMinimal: Int,
                       zaaps: ZaapsSitues, zaapDuJeu: Bool) -> Trajet? {
        guard let depart = rejoindre(position) else { return nil }
        return trajet(depuis: depart, vers: cible, zaap: zaap(vers: cible, parmi: zaaps, zaapDuJeu: zaapDuJeu),
                      gainMinimal: gainMinimal)
    }

    /// Les cartes à traverser de `depart` à `cible` : le coût d'un trajet copié.
    static func cartes(depuis depart: (x: Int, y: Int), vers cible: (x: Int, y: Int), zaap: Zaap?,
                       gainMinimal: Int) -> Int {
        trajet(depuis: depart, vers: cible, zaap: zaap, gainMinimal: gainMinimal).cartes
    }

    /// `/zaap x,y ; /travel a,b` si le zaap retenu pour la cible (`zaap(vers:)`)
    /// épargne au moins `gainMinimal` cartes depuis `position` ; `nil` sinon.
    static func reecrire(
        _ texte: String, depuis position: PositionCarte?, gainMinimal: Int, zaaps: ZaapsSitues, zaapDuJeu: Bool
    ) -> String? {
        guard let cible = cible(dans: texte),
              let zaap = trajet(vers: cible, depuis: position, gainMinimal: gainMinimal, zaaps: zaaps,
                                zaapDuJeu: zaapDuJeu)?.zaap
        else { return nil }
        let travel = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        // L'espace avant le « ; » : sans elle, le jeu lit mal l'enchaînement.
        return "\(Self.zaap(zaap)) ; \(travel)"
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
