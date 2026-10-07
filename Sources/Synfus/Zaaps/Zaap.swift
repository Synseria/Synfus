/// Un zaap, cible de `/zaap x,y`. Des coordonnées et des noms, aucun visuel
/// du jeu.
///
/// `monde` est la carte du monde de DofusDB (`worldMapId`) : 1, le Monde des
/// Douze ; Incarnam, la Canopée, Harebourg ou Crocuzko ont la leur, aux
/// coordonnées qui recoupent celles d'Amakna — d'où leur exclusion par défaut
/// (`CatalogueZaaps.actifParDefaut`).
struct Zaap: Codable, Hashable, Sendable {
    static let mondeDesDouze = 1

    let x: Int
    let y: Int
    let monde: Int
    /// Par code de langue (`fr`, `en`, `es`) ; un zaap ajouté à la main n'a
    /// que le nom saisi.
    let noms: [String: String]

    init(_ x: Int, _ y: Int, monde: Int = Zaap.mondeDesDouze, noms: [String: String]) {
        self.x = x
        self.y = y
        self.monde = monde
        self.noms = noms
    }

    /// Ce qui identifie un zaap d'une liste à l'autre — intégrée, DofusDB, à
    /// la main — pour y retrouver son activation.
    var cle: String { "\(monde):\(x),\(y)" }

    func nom(en langue: Langue) -> String {
        noms[langue.rawValue] ?? noms[Langue.fr.rawValue] ?? noms.values.min() ?? "\(x),\(y)"
    }

    /// La liste intégrée, relevée sur DofusDB (`ZaapsDofusDB`) : celle qui sert
    /// tant qu'aucune mise à jour n'a été téléchargée.
    static let integres: [Zaap] = [
        Zaap(-78, -41, noms: ["fr": "La Bourgade", "en": "Frigost Village", "es": "Burgo"]),
        Zaap(-77, -73, noms: ["fr": "Village enseveli", "en": "Snowbound Village", "es": "Pueblo Sepultado"]),
        Zaap(-67, 29, noms: ["fr": "Nimotopia", "en": "Nimaltopia", "es": "Animatopía"]),
        Zaap(-46, 18, noms: ["fr": "Village côtier", "en": "Coastal Village", "es": "Pueblo costero"]),
        Zaap(-34, -8, noms: ["fr": "Village des Dopeuls", "en": "Dopple Village", "es": "Pueblo de los dopeuls"]),
        Zaap(-31, -56, noms: ["fr": "Cœur immaculé", "en": "Immaculate Heart", "es": "Corazón Inmaculado"]),
        Zaap(-27, -36, noms: ["fr": "Champs de Cania", "en": "Cania Fields", "es": "Campos de Cania"]),
        Zaap(-26, 37, noms: ["fr": "La Cuirasse", "en": "The Breastplate", "es": "Coraza"]),
        Zaap(-25, 12, noms: ["fr": "Route des Roulottes", "en": "Caravan Alley", "es": "Camino de las caravanas"]),
        Zaap(-20, -20, noms: ["fr": "Routes Rocailleuses", "en": "Rocky Roads", "es": "Caminos rocosos"]),
        Zaap(-17, -47, noms: ["fr": "Plaines Rocheuses", "en": "Rocky Plains", "es": "Llanuras Rocosas"]),
        Zaap(-16, 1, noms: ["fr": "Village des Éleveurs", "en": "Breeder Village", "es": "Pueblo de los ganaderos"]),
        Zaap(-15, 25, noms: ["fr": "Terres Désacrées", "en": "Desecrated Highlands", "es": "Tierras Desacralizadas"]),
        Zaap(-13, -28, noms: ["fr": "Massif de Cania", "en": "Cania Massif", "es": "Sierra de Cania"]),
        Zaap(-12, 19, noms: ["fr": "Cimetière primitif", "en": "Primitive Cemetery", "es": "Cementerio primitivo"]),
        Zaap(-11, -36, noms: ["fr": "Foire du Trool", "en": "Trool Fair", "es": "Feria del Trool"]),
        Zaap(-5, -23, noms: ["fr": "Plaine des Porkass", "en": "Lousy Pig Plain", "es": "Llanura de los puerkazos"]),
        Zaap(-5, -8, noms: ["fr": "Montagne des Craqueleurs", "en": "Crackler Mountain", "es": "La montaña de los crujidores"]),
        Zaap(-3, -42, noms: ["fr": "Lac de Cania", "en": "Cania Lake", "es": "Lago de Cania"]),
        Zaap(-2, 0, noms: ["fr": "Village d'Amakna", "en": "Amakna Village", "es": "Pueblo de Amakna"]),
        Zaap(-1, 13, noms: ["fr": "Bord de la forêt maléfique", "en": "Edge of the Evil Forest", "es": "Linde del Bosque Maléfico"]),
        Zaap(-1, 24, noms: ["fr": "Plaine des Scarafeuilles", "en": "Scaraleaf Plain", "es": "Llanura de los escarahojas"]),
        Zaap(0, -56, noms: ["fr": "Village des Kanigs", "en": "Kanig Village", "es": "Pueblo de los kanigs"]),
        Zaap(1, -32, noms: ["fr": "Tainéla", "en": "Tainela", "es": "Tainela"]),
        Zaap(3, -5, noms: ["fr": "Château d'Amakna", "en": "Amakna Castle", "es": "Castillo de Amakna"]),
        Zaap(5, -18, noms: ["fr": "Cité d'Astrub", "en": "Astrub City", "es": "Ciudad de Astrub"]),
        Zaap(5, 7, noms: ["fr": "Coin des Bouftous", "en": "Gobball Corner", "es": "Rincón de los Jalatós"]),
        Zaap(7, -4, noms: ["fr": "Port de Madrestam", "en": "Madrestam Harbour", "es": "Puerto de Madrestam"]),
        Zaap(10, 22, noms: ["fr": "Rivage sufokien", "en": "Sufokian Shoreline", "es": "Ribera del golfo sufokeño"]),
        Zaap(13, 26, noms: ["fr": "Sufokia", "en": "Sufokia", "es": "Sufokia"]),
        Zaap(13, 35, noms: ["fr": "Temple des alliances", "en": "Alliance Temple", "es": "Templo de las alianzas"]),
        Zaap(15, -58, noms: ["fr": "Dunes des ossements", "en": "Dunes of Bones", "es": "Dunas de los Huesos"]),
        Zaap(15, -20, noms: ["fr": "Arche de Vili", "en": "Arch of Vili", "es": "Arco de Vili"]),
        Zaap(20, -29, noms: ["fr": "Village de Pandala", "en": "Pandala Village", "es": "Pueblo de Pandala"]),
        Zaap(25, -4, noms: ["fr": "Île de la Cawotte", "en": "Cawwot Island", "es": "Isla Zanahowia"]),
        Zaap(27, -14, noms: ["fr": "Laboratoires abandonnés", "en": "Abandoned Labowatowies", "es": "Laboratorios abandonados"]),
        Zaap(35, 12, noms: ["fr": "Plage de la Tortue", "en": "Turtle Beach", "es": "Playa Tortuga"]),
        Zaap(39, -82, noms: ["fr": "Futaie enneigée", "en": "Snowbound Timberland", "es": "Arboleda nevada"]),
        Zaap(40, -44, noms: ["fr": "Mont des Tombeaux", "en": "Mount Tombs", "es": "Monte de las Tumbas"]),
        Zaap(-1, -3, monde: 2, noms: ["fr": "Route des âmes", "en": "Way of Souls", "es": "Camino de las Almas"]),
        Zaap(2, -5, monde: 2, noms: ["fr": "Pâturages", "en": "Pastures", "es": "Prado"]),
        Zaap(3, 0, monde: 2, noms: ["fr": "Cimetière", "en": "Cemetery", "es": "Cementerio"]),
        Zaap(-54, 16, monde: 10, noms: ["fr": "Village de la Canopée", "en": "Canopy Village", "es": "Pueblo de la canopea"]),
        Zaap(-67, -77, monde: 12, noms: ["fr": "Entrée du château de Harebourg", "en": "Entrance to Harebourg's Castle", "es": "Entrada del castillo de Kontatrás"]),
        Zaap(-83, -15, monde: 22, noms: ["fr": "Crocuzko", "en": "Crocuzko", "es": "Cocuzko"]),
    ]
}
