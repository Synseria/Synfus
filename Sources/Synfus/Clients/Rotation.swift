/// Le pas de la rotation — perso suivant, précédent, enchaînement au clic —,
/// pur : on lui donne le rang courant et, pour chaque rang, si l'on peut s'y
/// poser ; il rend le rang d'arrivée.
///
/// Sauter l'injoignable est ce qui rend la rotation fiable après un ⌘Q. Un
/// client qui se ferme — ou qui gèle en se fermant — reste affiché par la
/// mémoire le temps de mourir : la rotation l'incluait, et un appui sur deux
/// activait un processus sans fenêtre, ce qui ne montrait rien. L'accès direct
/// (⌘1…⌘0, clic sur la pastille) n'y passe pas : viser un perso précis reste
/// un choix.
enum Rotation {
    /// Rang atteint à `pas` crans de `courant`, en ne comptant que les rangs
    /// joignables. Sans rang courant — l'app devant n'est pas de l'effectif —,
    /// le premier joignable. `nil` si aucun ne l'est.
    static func suivant(depuis courant: Int?, pas: Int, joignables: [Bool]) -> Int? {
        let nombre = joignables.count
        guard nombre > 0 else { return nil }
        guard let courant, courant >= 0, courant < nombre else {
            return joignables.firstIndex(of: true)
        }
        guard pas != 0 else { return joignables[courant] ? courant : nil }

        let sens = pas > 0 ? 1 : -1
        var restants = abs(pas)
        var rang = courant
        for _ in 0..<(nombre * abs(pas)) {
            rang = ((rang + sens) % nombre + nombre) % nombre
            guard joignables[rang] else { continue }
            restants -= 1
            if restants == 0 { return rang }
        }
        return nil
    }
}
