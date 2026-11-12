// Quelles coordonnées d'objectif le panneau des quêtes affiche : celles qui diffèrent de la précédente.

enum CoordonneesObjectifs {
    /// Les objectifs d'une étape, dans l'ordre, dont la coordonnée s'affiche : la première, et toute
    /// coordonnée qui n'est pas la dernière **affichée** (même case d'un autre monde comprise), qu'un
    /// objectif validé, replié et sans coordonnée à l'écran se trouve entre les deux ou non.
    /// Ce qui est normal — plusieurs objectifs au même endroit — ne s'écrit qu'une fois ; le clic sur
    /// une ligne copie son trajet dans tous les cas.
    static func affichees(_ objectifs: [FicheQuete.Objectif], repliees: Set<Int> = []) -> Set<Int> {
        var affichees: Set<Int> = []
        var derniere: (position: PNJ.Position, sousZone: Int?)?
        for objectif in objectifs where !repliees.contains(objectif.id) {
            guard let position = objectif.position else {
                derniere = nil
                continue
            }
            if derniere?.position != position || derniere?.sousZone != objectif.sousZone {
                affichees.insert(objectif.id)
                derniere = (position, objectif.sousZone)
            }
        }
        return affichees
    }
}
