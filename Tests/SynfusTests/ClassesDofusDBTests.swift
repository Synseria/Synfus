import Foundation
import Testing
@testable import Synfus

/// Les classes de DofusDB : décodage de `breeds`, fusion avec la table
/// intégrée, fichier gardé, choix de l'emblème.
struct ClassesDofusDBTests {
    /// La forme de `GET /breeds` (champs en trop compris, que le décodage ignore).
    private static let page = Data("""
    {"total": 2, "limit": 50, "skip": 0, "data": [
      {"_id": "x", "id": 13, "shortName": {"id": "1", "de": "Schurke", "en": "Rogue", "es": "Tymador", "fr": "Roublard"},
       "img": "https://api.dofusdb.fr/img/breeds/symbol_13.png"},
      {"id": 16, "shortName": {"en": "Eliotrope", "es": "Selotrop", "fr": "Eliotrope"}}
    ]}
    """.utf8)

    private func classe(_ id: Int, fr: String?, en: String? = nil, es: String? = nil, img: String? = nil)
        -> ClassesDofusDB.ClasseAPI {
        ClassesDofusDB.ClasseAPI(id: id, shortName: DofusDB.Noms(fr: fr, en: en, es: es), img: img)
    }

    @Test("La page de DofusDB se décode, emblème absent compris")
    func decodage() throws {
        let page = try JSONDecoder().decode(DofusDB.Page<ClassesDofusDB.ClasseAPI>.self, from: Self.page)
        #expect(page.data.map(\.id) == [13, 16])
        #expect(page.data[0].shortName.parLangue == ["fr": "Roublard", "en": "Rogue", "es": "Tymador"])
        #expect(page.data[1].img == nil)
    }

    @Test("Sans liste téléchargée, le catalogue est la table intégrée")
    func horsLigne() {
        let catalogue = ClassesDofusDB.catalogue([])
        #expect(catalogue.breeds == DofusClass.integrees)
        #expect(catalogue.key(for: "Rogue") == "roublard")
        #expect(catalogue.breed(forKey: "iop")?.embleme == DofusDB.emblemeClasse(8))
    }

    /// DofusDB nomme l'Eliotrope espagnol « Selotrop », la table « Eliotropo » :
    /// le nom affiché suit DofusDB, l'ancien reste reconnu dans un titre.
    @Test("Une classe connue prend les noms de DofusDB et garde sa clé, sa couleur, ses anciens noms")
    func classeConnue() throws {
        let page = try JSONDecoder().decode(DofusDB.Page<ClassesDofusDB.ClasseAPI>.self, from: Self.page)
        let catalogue = ClassesDofusDB.catalogue(page.data)
        let integree = try #require(DofusClass.integrees.first { $0.key == "eliotrope" })
        let eliotrope = try #require(catalogue.breed(forKey: "eliotrope"))
        #expect(eliotrope.nom(langue: "es") == "Selotrop")
        #expect(eliotrope.color == integree.color)
        #expect(catalogue.key(for: "Selotrop") == "eliotrope")
        #expect(catalogue.key(for: "Eliotropo") == "eliotrope")
        #expect(catalogue.breeds.count == DofusClass.integrees.count)
    }

    @Test("L'emblème vient de DofusDB, ou de l'identifiant quand elle n'en donne pas")
    func embleme() throws {
        let image = "https://api.dofusdb.fr/img/breeds/autre_13.png"
        let catalogue = ClassesDofusDB.catalogue([classe(13, fr: "Roublard", img: image), classe(16, fr: "Eliotrope")])
        #expect(catalogue.breed(forKey: "roublard")?.embleme == URL(string: image))
        #expect(catalogue.breed(forKey: "eliotrope")?.embleme == DofusDB.emblemeClasse(16))
    }

    @Test("Un nom manquant chez DofusDB garde celui de la table")
    func nomManquant() {
        let catalogue = ClassesDofusDB.catalogue([classe(13, fr: "Roublard", en: nil, es: nil)])
        #expect(catalogue.breed(forKey: "roublard")?.nom(langue: "en") == "Rogue")
    }

    @Test("Une classe que la table n'a pas s'ajoute à la suite, reconnue dans toutes les langues")
    func nouvelleClasse() throws {
        let catalogue = ClassesDofusDB.catalogue([
            classe(22, fr: "Zéphyrin", en: "Zephyr", es: "Céfiro"),
            classe(21, fr: "Arpenteur", en: "Strider", es: "Andante"),
            classe(23, fr: nil, en: "Nameless"),
            classe(24, fr: "Iop"),
        ])
        #expect(catalogue.breeds.count == DofusClass.integrees.count + 2)
        #expect(catalogue.breeds.suffix(2).map(\.key) == ["arpenteur", "zephyrin"])
        let nouvelle = try #require(catalogue.breed(forKey: "zephyrin"))
        #expect(nouvelle.label == "Zéphyrin")
        #expect(nouvelle.embleme == DofusDB.emblemeClasse(22))
        #expect(nouvelle.color == DofusClass.couleurDerivee("zephyrin"))
        #expect(catalogue.key(for: "Céfiro") == "zephyrin")
        #expect(catalogue.breed(forKey: "iop")?.idDofusDB == 8)
    }

    @Test("La liste gardée se relit ; une autre forme ou un autre format se retélécharge")
    func fichierGarde() throws {
        let gardees = ClassesDofusDB.Gardees(format: ClassesDofusDB.Gardees.formatActuel,
                                             date: Date(timeIntervalSince1970: 1_000_000),
                                             classes: [classe(13, fr: "Roublard", en: "Rogue", es: "Tymador")])
        let relues = try #require(ClassesDofusDB.relire(try JSONEncoder().encode(gardees)))
        #expect(relues.date == gardees.date)
        #expect(relues.classes.map(\.shortName.parLangue) == [["fr": "Roublard", "en": "Rogue", "es": "Tymador"]])

        let ancien = ClassesDofusDB.Gardees(format: ClassesDofusDB.Gardees.formatActuel - 1, date: Date(), classes: [])
        #expect(ClassesDofusDB.relire(try JSONEncoder().encode(ancien)) == nil)
        #expect(ClassesDofusDB.relire(Data("[]".utf8)) == nil)
    }

    @Test("L'icône de l'utilisateur prime sur l'emblème de DofusDB")
    func provenance() {
        let embleme = DofusDB.emblemeClasse(8)
        #expect(DofusClass.provenance(tienne: true, embleme: embleme) == .tienne)
        #expect(DofusClass.provenance(tienne: true, embleme: nil) == .tienne)
        #expect(DofusClass.provenance(tienne: false, embleme: embleme) == .dofusDB(embleme))
        #expect(DofusClass.provenance(tienne: false, embleme: nil) == nil)
    }
}
