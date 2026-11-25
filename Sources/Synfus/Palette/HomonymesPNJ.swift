/// Les PNJ que DofusDB dédouble (le même roi dehors et « intérieur ») : même nom, même sous-zone
/// habituelle, une seule ligne de la palette qui réunit leurs positions. Pur.
enum HomonymesPNJ {
    /// Un PNJ tel que la palette le montre : le plus petit identifiant du groupe le représente (favori,
    /// étiquette, habitudes), ses passages sont ceux de tous.
    struct Fusionne: Equatable, Sendable {
        let pnj: PNJ
        /// Tous les PNJ réunis, le représentant d'abord : un favori ou une étiquette posé sur l'un vaut pour la ligne.
        let ids: [Int]

        var cles: [String] { ids.map { PNJ.prefixeCle + "\($0)" } }
    }

    /// Un PNJ par ligne, dans l'ordre du premier de chaque groupe.
    static func fusionner(_ pnjs: [PNJ], langue: Langue) -> [Fusionne] {
        var groupes: [Cle: [PNJ]] = [:]
        var ordre: [Cle] = []
        for (rang, pnj) in pnjs.enumerated() {
            let cle = cle(pnj, langue: langue) ?? .seul(rang)
            if groupes[cle] == nil { ordre.append(cle) }
            groupes[cle, default: []].append(pnj)
        }
        return ordre.compactMap { groupes[$0].map(reunir) }
    }

    /// Le groupe du PNJ `id` parmi `pnjs`, réuni ; `nil` s'il n'y est pas.
    static func fusionne(de id: Int, parmi pnjs: [PNJ], langue: Langue) -> Fusionne? {
        guard let pnj = pnjs.first(where: { $0.id == id }) else { return nil }
        guard let cle = cle(pnj, langue: langue) else { return reunir([pnj]) }
        return reunir(pnjs.filter { self.cle($0, langue: langue) == cle })
    }

    private enum Cle: Hashable {
        case homonyme(nom: String, sousZone: Int)
        case seul(Int)
    }

    /// Sans sous-zone connue, rien ne dit que deux homonymes sont le même : chacun reste seul.
    private static func cle(_ pnj: PNJ, langue: Langue) -> Cle? {
        guard let sousZone = pnj.passages.first?.sousZone, let nom = Lieu.traduit(pnj.noms, langue) else { return nil }
        return .homonyme(nom: RecherchePalette.normaliser(nom), sousZone: sousZone)
    }

    /// Une case citée par plusieurs n'en fait qu'une, ses quêtes réunies ; la plus citée d'abord, comme
    /// `PNJ.passages`.
    private static func reunir(_ groupe: [PNJ]) -> Fusionne {
        let tries = groupe.sorted { $0.id < $1.id }
        guard tries.count > 1, let premier = tries.first else { return Fusionne(pnj: groupe[0], ids: [groupe[0].id]) }
        var passages: [PNJ.Passage] = []
        for passage in tries.flatMap(\.passages) {
            guard let rang = passages.firstIndex(where: { $0.position == passage.position }) else {
                passages.append(passage)
                continue
            }
            let deja = passages[rang]
            passages[rang] = PNJ.Passage(position: deja.position, carte: deja.carte ?? passage.carte,
                                         sousZone: deja.sousZone ?? passage.sousZone,
                                         quetes: Array(Set(deja.quetes + passage.quetes)).sorted())
        }
        let citees = passages.enumerated().sorted { a, b in
            a.element.quetes.count != b.element.quetes.count ? a.element.quetes.count > b.element.quetes.count : a.offset < b.offset
        }.map(\.element)
        return Fusionne(pnj: PNJ(id: premier.id, noms: premier.noms, passages: citees), ids: tries.map(\.id))
    }
}
