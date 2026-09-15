import Foundation

/// Une équipe : des noms de persos. C'est une **appartenance**, pas un ordre —
/// l'effectif suit `characterOrder` comme tout le reste, une équipe n'est qu'un
/// sous-ensemble. Struct plutôt que tableau nu pour qu'un champ (nom, couleur)
/// puisse s'ajouter un jour sans migration.
struct Equipe: Codable, Equatable, Sendable {
    var membres: [String]
}

/// Règles pures des équipes : ce que la barre affiche quand une équipe est
/// active, comment un perso change d'équipe, comment on tourne entre elles.
/// Aucune lecture, aucun état — c'est ce qui les rend testables.
enum Equipes {
    /// Dofus plafonne à huit comptes ; quatre équipes couvrent 4 × 2 comme 2 × 4.
    static let maximum = 4

    /// `clients` restreint aux membres de l'équipe, dans l'ordre reçu. `nil`
    /// vaut « Tous ». Les clients au login et les homonymes suffixés n'ont
    /// jamais d'équipe : ils n'apparaissent que sous « Tous ».
    static func filtre(_ clients: [DofusClient], equipe: Equipe?) -> [DofusClient] {
        guard let equipe else { return clients }
        let membres = Set(equipe.membres)
        return clients.filter { membres.contains($0.name) }
    }

    /// Affecte `nom` à l'équipe `index` : le retire des autres, crée l'équipe
    /// si `index == equipes.count` (tant qu'on est sous `maximum`), et fait
    /// disparaître les équipes vidées. `nil` = retirer de toute équipe.
    ///
    /// Un nom non persistable (`WindowTitle.isPersistableName`) ou un index
    /// hors de portée laisse tout inchangé : l'appelant compare avant d'écrire.
    static func affecter(_ nom: String, a index: Int?, dans equipes: [Equipe]) -> [Equipe] {
        guard WindowTitle.isPersistableName(nom) else { return equipes }
        if let index {
            guard index >= 0, index <= equipes.count, index < maximum else { return equipes }
        }

        var resultat = equipes
        for i in resultat.indices { resultat[i].membres.removeAll { $0 == nom } }
        if let index {
            if index == resultat.count { resultat.append(Equipe(membres: [])) }
            resultat[index].membres.append(nom)
        }
        return resultat.filter { !$0.membres.isEmpty }
    }

    /// Ne garde que les membres présents dans `noms` ; une équipe vidée
    /// disparaît. C'est ce qui tient les équipes dans `characterOrder` quand
    /// un perso est oublié ou purgé.
    static func restreintes(_ equipes: [Equipe], aux noms: Set<String>) -> [Equipe] {
        equipes
            .map { Equipe(membres: $0.membres.filter { noms.contains($0) }) }
            .filter { !$0.membres.isEmpty }
    }

    static func indexEquipe(de nom: String, dans equipes: [Equipe]) -> Int? {
        equipes.firstIndex { $0.membres.contains(nom) }
    }

    /// Tous → 1 → … → n → Tous. Sans équipe, on reste sur Tous.
    static func suivante(apres active: Int?, nombre: Int) -> Int? {
        guard nombre > 0 else { return nil }
        guard let active else { return 0 }
        let prochaine = active + 1
        return prochaine < nombre ? prochaine : nil
    }

    /// L'index encore valable après un changement de composition : une équipe
    /// disparue ramène à « Tous » ; un index encore dans la plage pointe sur
    /// l'équipe qui a remonté — c'est accepté.
    static func activeValide(_ active: Int?, nombre: Int) -> Int? {
        guard let active, active >= 0, active < nombre else { return nil }
        return active
    }
}
