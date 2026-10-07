import Foundation
import Testing
@testable import Synfus

/// La chasse au trésor : décodage de DofusDB, carte d'arrivée, indices
/// retrouvés dans une saisie ou une lecture de l'écran.
struct ChasseTests {

    /// Réduit d'une vraie réponse (`treasure-hunt?x=-25&y=-36&direction=0`) :
    /// les cartes ne sont pas dans l'ordre des distances, et portent des
    /// champs que Synfus ignore.
    private static let etapeEst = """
    {"total":4,"limit":50,"skip":0,"data":[
     {"_id":"a","id":139461129,"posX":-20,"posY":-36,"distance":5,"__v":0,"pois":[
       {"_id":"b","id":1021,"name":{"id":"936352","de":"Gestreifte Teekanne","en":"Striped Teapot","es":"Tetera con rayas","fr":"Théière à rayures","pt":"Chaleira Listrada"},"className":"PointOfInterestData"},
       {"_id":"c","id":993,"name":{"id":"936360","fr":"Poupée koalak"},"className":"PointOfInterestData"}]},
     {"_id":"d","id":139461641,"posX":-19,"posY":-36,"distance":6,"pois":[{"id":993,"name":{"fr":"Poupée koalak"}}]},
     {"_id":"e","id":139459081,"posX":-24,"posY":-36,"distance":1,"pois":[{"id":851,"name":{"fr":"Anneau d'or"}}]},
     {"_id":"f","id":139459593,"posX":-23,"posY":-36,"distance":2,"pois":[{"id":1021,"name":{"fr":"Théière à rayures"}}]}]}
    """

    /// Réduit d'une page de `point-of-interest`.
    private static let pageIndices = """
    {"total":179,"limit":50,"skip":0,"data":[
     {"_id":"1","id":875,"name":{"id":"930995","de":"Steinhügel","en":"Cairn","es":"Cairn","fr":"Cairn","pt":"Cairn"},"className":"PointOfInterestData","m_id":875},
     {"_id":"2","id":896,"name":{"id":"936391","en":"Unikron Skull","es":"Cráneo de urikornio","fr":"Crâne de likrone"}},
     {"_id":"3","id":897,"name":{"id":"936392","en":"Unikron Skull in Ice","es":"Cráneo de urikornio en el hielo","fr":"Crâne de likrone dans la glace"}},
     {"_id":"4","id":955,"name":{"en":"Bell","es":"Cascabel","fr":"Grelot"}},
     {"_id":"5","id":974,"name":{"en":"Egg in a Hole","es":"Huevo en un agujero","fr":"Œuf dans un trou"}},
     {"_id":"6","id":993,"name":{"en":"Koalak Doll","es":"Muñeca koalak","fr":"Poupée koalak"}},
     {"_id":"7","id":1021,"name":{"en":"Striped Teapot","es":"Tetera con rayas","fr":"Théière à rayures"}}]}
    """

    private func cartes() throws -> [EtapeChasse.Carte] {
        try JSONDecoder().decode(DofusDB.Page<EtapeChasse.Carte>.self, from: Data(Self.etapeEst.utf8)).data
    }

    private func indices() throws -> [Indice] {
        try JSONDecoder().decode(DofusDB.Page<ChasseDofusDB.IndiceAPI>.self, from: Data(Self.pageIndices.utf8))
            .data.map(\.indice)
    }

    private func ids(_ liste: [Indice]) -> [Int] { liste.map(\.id) }

    // MARK: - Décodage

    @Test("Une réponse d'étape se décode : position, distance, indices portés")
    func decodageEtape() throws {
        let cartes = try cartes()
        #expect(cartes.count == 4)
        #expect(cartes[0] == EtapeChasse.Carte(x: -20, y: -36, distance: 5, indices: [1021, 993]))
    }

    @Test("Un indice garde ses noms fr, en et es, rien d'autre")
    func decodageIndices() throws {
        let liste = try indices()
        #expect(liste.count == 7)
        #expect(liste[0].noms == ["fr": "Cairn", "en": "Cairn", "es": "Cairn"])
        #expect(liste[5].nom(en: .es) == "Muñeca koalak")
    }

    @Test("La liste gardée sur le disque se relit telle quelle")
    func releveRelu() throws {
        let releve = ChasseDofusDB.Releve(date: Date(timeIntervalSinceReferenceDate: 800_000_000), indices: try indices())
        let relu = try JSONDecoder().decode(ChasseDofusDB.Releve.self, from: JSONEncoder().encode(releve))
        #expect(relu == releve)
    }

    // MARK: - Destination

    @Test("La destination est la plus proche des cartes qui portent l'indice")
    func destination() throws {
        let cartes = try cartes()
        // 1021 est à 5 et à 2 cartes : l'API ne trie pas.
        #expect(EtapeChasse.destination(indice: 1021, cartes: cartes)?.distance == 2)
        #expect(EtapeChasse.resultat(indice: 993, cartes: cartes) == .trouve(x: -20, y: -36, distance: 5))
        #expect(EtapeChasse.resultat(indice: 4242, cartes: cartes) == .introuvable)
        #expect(EtapeChasse.resultat(indice: 993, cartes: []) == .introuvable)
    }

    // MARK: - Direction

    @Test("Codes de l'API et flèches du clavier")
    func direction() {
        #expect(Direction.allCases.map(\.rawValue) == [0, 2, 4, 6])
        #expect(Direction(toucheFleche: 124) == .est)
        #expect(Direction(toucheFleche: 125) == .sud)
        #expect(Direction(toucheFleche: 123) == .ouest)
        #expect(Direction(toucheFleche: 126) == .nord)
        #expect(Direction(toucheFleche: 36) == nil)
        #expect(Direction.nord.libelle == L("chasse.direction.nord"))
    }

    // MARK: - Recherche

    @Test("La saisie ignore accents, casse et ligatures ; le début du nom passe avant")
    func rechercheAccents() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.rechercher("crane de lik", parmi: liste, langue: .fr)) == [896, 897])
        #expect(ids(IndicesChasse.rechercher("THEIERE", parmi: liste, langue: .fr)) == [1021])
        #expect(ids(IndicesChasse.rechercher("oeuf", parmi: liste, langue: .fr)) == [974])
        #expect(ids(IndicesChasse.rechercher("koalak", parmi: liste, langue: .fr)) == [993])
        #expect(ids(IndicesChasse.rechercher("teapot", parmi: liste, langue: .en)) == [1021])
        #expect(IndicesChasse.rechercher("  ", parmi: liste, langue: .fr).isEmpty)
    }

    @Test("Une faute de frappe trouve encore l'indice, pas un mot sans rapport")
    func rechercheFaute() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.rechercher("poupee koalack", parmi: liste, langue: .fr)) == [993])
        #expect(IndicesChasse.rechercher("zzzzzz", parmi: liste, langue: .fr).isEmpty)
    }

    // MARK: - OCR

    @Test("Les lignes de l'OCR donnent les indices, fautes et icônes comprises, dans leur ordre")
    func indicesLus() throws {
        let liste = try indices()
        let lignes = ["CHASSE AU TRÉSOR", "Départ [-25,-36]", "→ Poupee koaiak",
                      "Théiére á rayures ?", "Etape 3/6", "Crâne de likrone dans la glace"]
        #expect(ids(IndicesChasse.indicesReconnus(dans: lignes, parmi: liste)) == [993, 1021, 897])
    }

    @Test("Un indice relu plus bas ne compte qu'à sa dernière place")
    func indicesRelus() throws {
        let liste = try indices()
        let lignes = ["Grelot", "Cairn", "Grelot"]
        #expect(ids(IndicesChasse.indicesReconnus(dans: lignes, parmi: liste)) == [875, 955])
    }

    @Test("Le jeu en anglais se lit aussi, quelle que soit la langue de l'interface")
    func indicesAutreLangue() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.indicesReconnus(dans: ["Striped Teap0t"], parmi: liste)) == [1021])
    }

    // MARK: - Phorreur

    @Test("Le Phorreur se reconnaît, à une faute près, mais pas l'horreur")
    func phorreur() {
        #expect(EtapeChasse.estPhorreur("Phorreur sournois"))
        #expect(EtapeChasse.estPhorreur("phoreur baveux"))
        #expect(EtapeChasse.estPhorreur("PHORREUR"))
        #expect(!EtapeChasse.estPhorreur("Quelle horreur"))
        #expect(!EtapeChasse.estPhorreur("Poupée koalak"))
    }

    @Test("Les cibles lues mêlent indices et Phorreur, dans l'ordre des lignes")
    func ciblesLues() throws {
        let liste = try indices()
        let lues = EtapeChasse.ciblesLues(dans: ["Poupée koalak", "Phorreur fourbe", "rien"], parmi: liste)
        #expect(lues.count == 2)
        #expect(lues.last == .phorreur)
        if case .indice(let indice) = lues.first { #expect(indice.id == 993) } else { Issue.record("indice attendu") }
    }
}
