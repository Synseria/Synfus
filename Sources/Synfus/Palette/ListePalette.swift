/// La liste de la palette une fois classée : ce qui ferait doublon s'y réunit. Pur.
enum ListePalette {
    /// Un donjon et ses boss ouvrent la même fiche (`.donjon(id)`) : seule la mieux classée de leurs
    /// lignes reste. Un boss qui l'emporte prend la case de son donjon (position, vue, trajet), pas sa clé :
    /// un boss ne s'étiquette pas.
    static func fusionnerDonjons(_ entrees: [EntreePalette]) -> [EntreePalette] {
        var gardees: [EntreePalette] = []
        gardees.reserveCapacity(entrees.count)
        var rangDuDonjon: [Int: Int] = [:]
        for entree in entrees {
            guard case .donjon(let id) = entree.effet else {
                gardees.append(entree)
                continue
            }
            guard let rang = rangDuDonjon[id] else {
                rangDuDonjon[id] = gardees.count
                gardees.append(entree)
                continue
            }
            if gardees[rang].estBoss, !entree.estBoss { gardees[rang].situer(comme: entree) }
        }
        return gardees
    }
}

private extension EntreePalette {
    mutating func situer(comme donjon: EntreePalette) {
        detail = detail ?? donjon.detail
        carte = carte ?? donjon.carte
        distance = distance ?? donjon.distance
        itineraire = itineraire ?? donjon.itineraire
        interieur = interieur || donjon.interieur
    }
}
