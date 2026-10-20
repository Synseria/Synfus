/// Ce qui se passe sur la case du perso : les quêtes qui y commencent, les PNJ
/// que les quêtes y placent. Pur : la position lue, les quêtes, la carte.
enum QuetesIci {
    /// Sur la case lue, et dans le même monde : depuis Incarnam, la case
    /// homonyme d'Amakna n'est pas ici. La sous-zone le dit (`ReseauSousZones`) ;
    /// sans elle, ou la carte pas encore lue, les coordonnées seules.
    static func ici(_ position: PNJ.Position, sousZone: Int?, perso: PositionCarte, reseau: ReseauSousZones) -> Bool {
        guard position.x == perso.x, position.y == perso.y else { return false }
        guard sousZone != nil, reseau.estLu else { return true }
        return reseau.horsDesDouze(sousZone) == perso.horsDuMondeDesDouze
    }

    /// Une quête commence ici si l'un de ses départs y est.
    static func commenceIci(_ quete: Quete, perso: PositionCarte, reseau: ReseauSousZones) -> Bool {
        quete.departs.contains { ici($0.position, sousZone: $0.sousZone, perso: perso, reseau: reseau) }
    }

    /// La plus basse d'abord.
    static func quetes(_ quetes: Quetes, perso: PositionCarte, reseau: ReseauSousZones) -> [Quete] {
        quetes.quetes.filter { commenceIci($0, perso: perso, reseau: reseau) }
            .sorted { ($0.niveau, $0.id) < ($1.niveau, $1.id) }
    }

    /// Les PNJ dont un passage est ici, dans l'ordre de la liste.
    static func pnjs(_ quetes: Quetes, perso: PositionCarte, reseau: ReseauSousZones) -> [PNJ] {
        quetes.pnjs.filter { pnj in
            pnj.passages.contains { ici($0.position, sousZone: $0.sousZone, perso: perso, reseau: reseau) }
        }
    }
}
