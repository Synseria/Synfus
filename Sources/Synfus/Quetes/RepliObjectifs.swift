// Ce que la fiche d'une quête montre des objectifs d'une étape : les faits et ceux à venir repliés.

enum RepliObjectifs {
    /// Les objectifs de l'étape, dans leur ordre, répartis : `montres` s'affichent un à un, `faits`
    /// et `aVenir` sont comptés chacun par une ligne qui les déplie.
    struct Repli: Equatable {
        var faits: [Int] = []
        var aVenir: [Int] = []
        var montres: [Int] = []
    }

    /// `aVenir` : ceux que le suivi du jeu ne montre pas encore ouverts (`nonOuverts`) — sans
    /// lecture, aucun : on ne cache que ce que le jeu dit. Un objectif fait n'est jamais à venir.
    /// Déplié (`montrerFaits`, `montrerAVenir`), un groupe reste compté mais ses objectifs se montrent.
    static func replier(_ objectifs: [Int], faits: Set<Int>, aVenir: Set<Int>,
                        montrerFaits: Bool, montrerAVenir: Bool) -> Repli {
        var repli = Repli()
        for id in objectifs {
            if faits.contains(id) {
                repli.faits.append(id)
                if montrerFaits { repli.montres.append(id) }
            } else if aVenir.contains(id) {
                repli.aVenir.append(id)
                if montrerAVenir { repli.montres.append(id) }
            } else {
                repli.montres.append(id)
            }
        }
        return repli
    }
}
