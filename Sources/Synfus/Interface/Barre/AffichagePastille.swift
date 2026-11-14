// Ce que montre une pastille de la barre : nom et classe, emblème, touche (pur).

/// Les éléments d'une pastille. Réduite, une pastille qui n'est pas devant garde l'emblème et la
/// touche ; sans ni l'un ni l'autre à montrer, elle garde son nom : une pastille vide ne dirait
/// rien du perso.
struct AffichagePastille: Equatable {
    let nom: Bool
    let classe: Bool
    let embleme: Bool
    let touche: Bool

    init(devant: Bool, reduireInactifs: Bool, embleme: Bool, touche: Bool, aUneClasse: Bool) {
        let reduite = reduireInactifs && !devant && (embleme || touche)
        self.nom = !reduite
        self.classe = !reduite && aUneClasse
        self.embleme = embleme
        self.touche = touche
    }
}
