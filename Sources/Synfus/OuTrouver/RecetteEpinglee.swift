/// Une recette épinglée à côté du jeu, pour les courses à l'hôtel de vente : ce qu'on fabrique, le
/// métier et son niveau, les ingrédients dans la langue de l'app avec leur quantité. Pur.
struct RecetteEpinglee: Equatable, Sendable {
    struct Ingredient: Equatable, Sendable {
        let nom: String
        let quantite: Int
    }

    /// Ce que la recette fabrique, quand l'appelant le sait (la clef d'un donjon, l'offrande du jour).
    let objet: String?
    let metier: String
    let niveau: Int
    let ingredients: [Ingredient]

    /// Un nom qui manque dans la langue (DofusDB n'a pas tout traduit) se lit dans une autre, sinon « ? ».
    init(_ recette: SourcesObjet.Recette, objet: String?, langue: Langue) {
        self.objet = objet
        metier = Lieu.traduit(recette.metier, langue) ?? "?"
        niveau = recette.niveau
        ingredients = recette.ingredients.map { Ingredient(nom: Lieu.traduit($0.noms, langue) ?? "?", quantite: $0.quantite) }
    }
}
