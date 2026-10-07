/// Les zaaps du Monde des Douze, cibles de `/zaap x,y`. Relevés sur DofusDB
/// (`api.dofusdb.fr/hints?name.fr=Zaap`, `worldMapId` 1) : des coordonnées,
/// aucun visuel du jeu.
///
/// Seule la grille du Monde des Douze : Incarnam, la Canopée, le château de
/// Harebourg ou Crocuzko ont leurs propres cartes, où un `/travel` posé
/// derrière le zaap ne viserait pas la même case.
struct Zaap: Equatable, Sendable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    static let tous: [Zaap] = [
        Zaap(-78, -41),  // La Bourgade
        Zaap(-77, -73),  // Village enseveli
        Zaap(-67, 29),  // Nimotopia
        Zaap(-46, 18),  // Village côtier
        Zaap(-34, -8),  // Village des Dopeuls
        Zaap(-31, -56),  // Cœur immaculé
        Zaap(-27, -36),  // Champs de Cania
        Zaap(-26, 37),  // La Cuirasse
        Zaap(-25, 12),  // Route des Roulottes
        Zaap(-20, -20),  // Routes Rocailleuses
        Zaap(-17, -47),  // Plaines Rocheuses
        Zaap(-16, 1),  // Village des Éleveurs
        Zaap(-15, 25),  // Terres Désacrées
        Zaap(-13, -28),  // Massif de Cania
        Zaap(-12, 19),  // Cimetière primitif
        Zaap(-11, -36),  // Foire du Trool
        Zaap(-5, -23),  // Plaine des Porkass
        Zaap(-5, -8),  // Montagne des Craqueleurs
        Zaap(-3, -42),  // Lac de Cania
        Zaap(-2, 0),  // Village d'Amakna
        Zaap(-1, 13),  // Bord de la forêt maléfique
        Zaap(-1, 24),  // Plaine des Scarafeuilles
        Zaap(0, -56),  // Village des Kanigs
        Zaap(1, -32),  // Tainéla
        Zaap(3, -5),  // Château d'Amakna
        Zaap(5, -18),  // Cité d'Astrub
        Zaap(5, 7),  // Coin des Bouftous
        Zaap(7, -4),  // Port de Madrestam
        Zaap(10, 22),  // Rivage sufokien
        Zaap(13, 26),  // Sufokia
        Zaap(13, 35),  // Temple des alliances
        Zaap(15, -58),  // Dunes des ossements
        Zaap(15, -20),  // Arche de Vili
        Zaap(20, -29),  // Village de Pandala
        Zaap(25, -4),  // Île de la Cawotte
        Zaap(27, -14),  // Laboratoires abandonnés
        Zaap(35, 12),  // Plage de la Tortue
        Zaap(39, -82),  // Futaie enneigée
        Zaap(40, -44),  // Mont des Tombeaux
    ]
}
