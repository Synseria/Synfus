/// Quand le menu propose de redonner la lecture de l'écran : elle n'est demandée que si quelque chose
/// la lit, sinon l'entrée parlerait d'une fonction éteinte.
enum AutorisationsMenu {
    static func lectureEcranManque(autorisee: Bool, lirePosition: Bool, lireCombat: Bool, apercus: Bool,
                                   panneauLisant: Bool) -> Bool {
        !autorisee && (lirePosition || lireCombat || apercus || panneauLisant)
    }
}
