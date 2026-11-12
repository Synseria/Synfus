// Quelles coordonnées d'objectif le panneau des quêtes affiche : celles qui diffèrent de la précédente.

enum CoordonneesObjectifs {
    /// Les objectifs d'une étape, dans l'ordre, dont la coordonnée s'affiche : la première, et toute
    /// coordonnée qui n'est pas celle de l'objectif juste avant (même case d'un autre monde comprise).
    /// Ce qui est normal — plusieurs objectifs au même endroit — ne s'écrit qu'une fois ; le clic sur
    /// une ligne copie son trajet dans tous les cas.
    static func affichees(_ objectifs: [FicheQuete.Objectif]) -> Set<Int> {
        var affichees: Set<Int> = []
        var precedent: (position: PNJ.Position, sousZone: Int?)?
        for objectif in objectifs {
            guard let position = objectif.position else {
                precedent = nil
                continue
            }
            if precedent?.position != position || precedent?.sousZone != objectif.sousZone { affichees.insert(objectif.id) }
            precedent = (position, objectif.sousZone)
        }
        return affichees
    }
}
