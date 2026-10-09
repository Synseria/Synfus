/// Le dernier résultat d'un calcul et la clé de ses entrées : redemandé sous
/// la même clé, il est rendu tel quel ; une autre clé le refait. Pour ce
/// qu'une vue redemande à chaque rendu — la clé dit tout ce dont il dépend,
/// c'est sa seule règle d'invalidation. Pur.
struct DernierCalcul<Cle: Equatable, Valeur> {
    private var dernier: (cle: Cle, valeur: Valeur)?

    mutating func valeur(pour cle: Cle, _ calculer: () -> Valeur) -> Valeur {
        if let dernier, dernier.cle == cle { return dernier.valeur }
        let valeur = calculer()
        dernier = (cle, valeur)
        return valeur
    }
}
