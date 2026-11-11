import Foundation

/// Un donjon tel que DofusDB le décrit (`dungeons`) : ce que la palette en
/// cherche et ce que sa fiche montre d'emblée. Le détail — monstres, clef,
/// succès nommés — se demande à l'ouverture de la fiche (`DetailDonjon`). Pur.
struct Donjon: Equatable, Sendable {
    struct Clef: Equatable, Sendable {
        let objet: Int
        let quantite: Int
    }

    let id: Int
    let noms: [String: String]
    /// Le niveau conseillé (`optimalPlayerLevel`).
    let niveau: Int?
    /// La carte d'entrée, que le repère du donjon sur la carte partage souvent.
    let entree: Int?
    let clefs: [Clef]
    let boss: [Int]
    let monstres: [Int]
    let succes: [Int]

    struct API: Decodable, Sendable {
        struct Objet: Decodable, Sendable {
            let id: Int
            let quantity: Int?
        }

        let id: Int
        let name: DofusDB.Noms
        let optimalPlayerLevel: Int?
        let entranceMapId: Int?
        let requiredObjects: [Objet]?
        let bosses: [Int]?
        let monsters: [Int]?
        let achievements: [Int]?

        static let champs = ["id", "name", "optimalPlayerLevel", "entranceMapId", "requiredObjects", "bosses",
                             "monsters", "achievements"]
    }

    init(_ api: API) {
        id = api.id
        noms = api.name.parLangue
        niveau = api.optimalPlayerLevel
        entree = api.entranceMapId
        clefs = (api.requiredObjects ?? []).map { Clef(objet: $0.id, quantite: $0.quantity ?? 1) }
        boss = api.bosses ?? []
        monstres = api.monsters ?? []
        succes = api.achievements ?? []
    }

    /// Le nom français : le titre de sa page sur Dofus pour les noobs.
    var nomFrancais: String? { noms[Langue.fr.rawValue] }
}

/// Tous les donjons, et le nom de leurs boss : de quoi retrouver la fiche
/// d'un donjon par son repère sur la carte ou par le nom d'un boss. Pur.
struct Donjons: Sendable {
    /// Le nom de chaque boss de donjon, par identifiant DofusDB.
    let nomsBoss: [Int: [String: String]]
    private let parId: [Int: Donjon]
    private let parEntree: [Int: Donjon]
    private let parNom: [String: Donjon]
    private let parBoss: [Int: Donjon]
    /// Les noms de chaque donjon en toutes langues, du plus long au plus
    /// court : dans « Expédition de l'Audace - Donjon du Comte Harebourg »,
    /// l'expédition l'emporte sur le donjon qu'elle reprend.
    private let nomsLus: [(forme: Ressemblance.Forme, donjon: Donjon)]

    /// Les écorchures de l'OCR tolérées dans le nom d'un donjon lu.
    static let fautesTolerees = 2
    static let nomMinimal = 2 * fautesTolerees

    init(_ liste: [Donjon], nomsBoss: [Int: [String: String]]) {
        func premiers<Cle: Hashable>(_ paires: [(Cle, Donjon)]) -> [Cle: Donjon] {
            Dictionary(paires, uniquingKeysWith: { premier, _ in premier })
        }
        self.nomsBoss = nomsBoss
        parId = premiers(liste.map { ($0.id, $0) })
        parEntree = premiers(liste.compactMap { donjon in donjon.entree.map { ($0, donjon) } })
        parNom = premiers(liste.compactMap { donjon in donjon.nomFrancais.map { (RecherchePalette.normaliser($0), donjon) } })
        // Le premier donjon d'un boss : une expédition reprend le boss du donjon d'origine.
        parBoss = premiers(liste.flatMap { donjon in donjon.boss.map { ($0, donjon) } })
        nomsLus = liste.flatMap { donjon in Set(donjon.noms.values).map { (Ressemblance.normaliser($0), donjon) } }
            // Un nom plus court que les écorchures tolérées se lirait partout.
            .filter { $0.0.count > Self.nomMinimal }
            .sorted { $0.0.count > $1.0.count }
            .map { (Ressemblance.Forme($0.0), $0.1) }
    }

    /// Le donjon nommé dans la zone lue au-dessus de la position (« Frigost
    /// (Donjon du Comte Harebourg) ») : sa sous-zone porte son nom ; `nil`
    /// ailleurs.
    func donjon(zone: String?) -> Donjon? {
        guard let zone else { return nil }
        let lue = Ressemblance.Forme(Ressemblance.normaliser(zone))
        return nomsLus.first { Ressemblance.distanceDansTexte($0.forme, lue, auPlus: Self.fautesTolerees) != nil }?.donjon
    }

    func donjon(id: Int) -> Donjon? { parId[id] }

    /// Le donjon d'un repère de la carte : par sa carte, sinon par son nom.
    func donjon(de lieu: Lieu) -> Donjon? {
        parEntree[lieu.idCarte] ?? lieu.noms[Langue.fr.rawValue].flatMap { parNom[RecherchePalette.normaliser($0)] }
    }

    func donjon(boss: Int) -> Donjon? { parBoss[boss] }
}

/// Ce que la fiche d'un donjon montre une fois ouverte : ses monstres à leur
/// plus haut grade (les boss d'abord), sa clef et ses succès nommés. Pur.
struct DetailDonjon: Equatable, Sendable {
    struct Monstre: Equatable, Sendable {
        let id: Int
        let noms: [String: String]
        let boss: Bool
        let fiche: FicheCombat
    }

    struct Clef: Equatable, Sendable {
        let objet: Int
        let noms: [String: String]
        let quantite: Int
    }

    struct Succes: Equatable, Sendable {
        let noms: [String: String]
        let description: [String: String]
    }

    let monstres: [Monstre]
    let clefs: [Clef]
    let succes: [Succes]

    /// Les boss d'abord, puis les autres du plus fort au plus faible.
    static func assembler(_ donjon: Donjon, monstres: [FicheCombat.MonstreAPI], objets: [Int: [String: String]],
                          succes: [Succes]) -> DetailDonjon {
        let boss = Set(donjon.boss)
        let situes = monstres.compactMap { api -> Monstre? in
            guard let id = api.id, let fiche = FicheCombat(api) else { return nil }
            return Monstre(id: id, noms: api.name?.parLangue ?? [:], boss: boss.contains(id), fiche: fiche)
        }
        .sorted { a, b in a.boss != b.boss ? a.boss : a.fiche.niveau > b.fiche.niveau }
        let clefs = donjon.clefs.map { Clef(objet: $0.objet, noms: objets[$0.objet] ?? [:], quantite: $0.quantite) }
        return DetailDonjon(monstres: situes, clefs: clefs, succes: succes)
    }
}
