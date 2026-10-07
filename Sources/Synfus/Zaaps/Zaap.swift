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
    /// Le nom de la sous-zone, par code de langue (`fr`, `en`, `es`) ; un zaap
    /// ajouté à la main n'a que le nom saisi.
    let noms: [String: String]
    /// Le nom de la zone (« Bonta » pour Cœur immaculé) ; vide pour un ajout.
    let zone: [String: String]

    init(_ x: Int, _ y: Int, monde: Int = Zaap.mondeDesDouze, noms: [String: String], zone: [String: String] = [:]) {
        self.x = x
        self.y = y
        self.monde = monde
        self.noms = noms
        self.zone = zone
    }

    private enum CodingKeys: String, CodingKey { case x, y, monde, noms, zone }

    /// Un zaap ajouté à la main avant que la zone n'existe n'en a pas.
    init(from decoder: any Decoder) throws {
        let conteneur = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try conteneur.decode(Int.self, forKey: .x), try conteneur.decode(Int.self, forKey: .y),
                  monde: try conteneur.decode(Int.self, forKey: .monde),
                  noms: try conteneur.decode([String: String].self, forKey: .noms),
                  zone: try conteneur.decodeIfPresent([String: String].self, forKey: .zone) ?? [:])
    }

    /// Ce qui identifie un zaap d'une liste à l'autre — intégrée, DofusDB, à
    /// la main — pour y retrouver son activation.
    var cle: String { "\(monde):\(x),\(y)" }

    func nom(en langue: Langue) -> String { Lieu.traduit(noms, langue) ?? "\(x),\(y)" }
    func zone(en langue: Langue) -> String? { Lieu.traduit(zone, langue) }
}
