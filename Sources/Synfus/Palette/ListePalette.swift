/// La liste de la palette une fois classée : ce qui ferait doublon s'y réunit, et l'Accueil n'y montre
/// que le meilleur de chaque famille. Pur.
enum ListePalette {
    /// Les lignes d'une famille que l'Accueil montre pendant une recherche.
    static let parFamille = 3

    /// Après la dernière ligne montrée de chaque famille, celle qui mène au reste (`.famille`) : une famille
    /// qui a un reste a toujours au moins une ligne montrée.
    static func avecLesSuites(_ entrees: [EntreePalette], restes: [FiltrePalette: Int]) -> [EntreePalette] {
        var derniere: [FiltrePalette: Int] = [:]
        for (rang, entree) in entrees.enumerated() {
            if let famille = FiltrePalette.famille(de: entree) { derniere[famille] = rang }
        }
        var suites: [Int: [EntreePalette]] = [:]
        for famille in FiltrePalette.allCases {
            guard let reste = restes[famille], reste > 0, let rang = derniere[famille] else { continue }
            suites[rang, default: []].append(EntreePalette(id: "suite:\(famille)", genre: .action, titre: famille.suite(reste),
                                                           effet: .famille(famille, reste: reste)))
        }
        return entrees.enumerated().flatMap { [$0.element] + (suites[$0.offset] ?? []) }
    }

    /// Combien de résultats la liste représente : une ligne « de plus » compte ceux qu'elle tait.
    static func nombre(_ entrees: [EntreePalette]) -> Int {
        entrees.reduce(0) { total, entree in
            if case .famille(_, let reste) = entree.effet { return total + reste }
            return total + 1
        }
    }

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
        ici = ici || donjon.ici
    }
}
