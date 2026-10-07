import Foundation
import Testing
@testable import Synfus

/// La recherche de la palette, sur la carte intégrée.
struct RecherchePaletteTests {

    private func contexte(position: PositionCarte? = PositionCarte(x: -2, y: 0, zone: "Amakna"),
                          etiquettes: [String: String] = [:], favoris: Set<String> = []) -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = position
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.lieux = Carte.integree.lieux
        contexte.etiquettes = etiquettes
        contexte.favoris = favoris
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        return contexte
    }

    private func premiere(_ requete: String, _ contexte: ContextePalette) -> EntreePalette? {
        RecherchePalette.entrees(requete, contexte).first
    }

    @Test("Sans rien taper : les zaaps, favoris d'abord puis du plus proche")
    func grille() {
        let amakna = "1:-2,0", bonta = "1:-31,-56"
        let entrees = RecherchePalette.entrees("", contexte(favoris: [bonta]))
        #expect(entrees.allSatisfy { $0.genre == .zaap })
        #expect(entrees.first?.cle == bonta)
        #expect(entrees.dropFirst().first?.cle == amakna)
    }

    @Test("/zaap bonta trouve Cœur immaculé par sa zone")
    func zaapParZone() {
        let entree = premiere("/zaap bonta", contexte())
        #expect(entree?.titre == "Cœur immaculé")
        #expect(entree?.effet == .copier("/zaap -31,-56"))
    }

    @Test("Une étiquette passe devant les noms")
    func etiquette() {
        let entree = premiere("/zaap fri 1", contexte(etiquettes: ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2"]))
        #expect(entree?.cle == "1:-78,-41")
    }

    @Test("/travel banque bonta : la banque de Bonta, par le zaap")
    func travelLieu() throws {
        let entree = try #require(premiere("/travel banque bonta", contexte()))
        #expect(entree.titre == "Banque")
        #expect(entree.sousTitre?.contains("Bonta") == true)
        let texte = try #require(RecherchePalette.texte(de: entree.effet, contexte()))
        #expect(texte.hasPrefix("/zaap -31,-56; /travel "))
    }

    @Test("Les surnoms des joueurs : fm, hdv conso")
    func surnoms() {
        #expect(premiere("/travel fm", contexte())?.titre == "Atelier des forgemages")
        #expect(premiere("/travel hdv conso", contexte())?.titre == "Hôtel de vente des consommables")
    }

    @Test("Le lieu le plus proche passe devant à score égal")
    func plusProche() throws {
        let depuisBonta = contexte(position: PositionCarte(x: -31, y: -55, zone: "Bonta"))
        let entree = try #require(premiere("/travel banque", depuisBonta))
        #expect(entree.sousTitre?.contains("Bonta") == true)
    }

    @Test("/travel x,y : le trajet, zaap compris")
    func travelCoordonnees() {
        #expect(premiere("/travel 6,8", contexte(position: PositionCarte(x: -30, y: -40, zone: nil)))?.effet
                == .copier("/zaap 5,7; /travel 6,8"))
    }

    @Test("/ liste les commandes ; une commande à argument se complète")
    func commandes() {
        let entrees = RecherchePalette.entrees("/", contexte())
        #expect(entrees.count == CommandeJeu.allCases.count)
        #expect(premiere("/wh", contexte())?.titre == "/whois")
        #expect(premiere("/w", contexte())?.effet == .completer("/w "))
        #expect(premiere("/away", contexte())?.effet == .copier("/away"))
    }

    @Test("% liste les variables, filtrées")
    func variables() {
        #expect(RecherchePalette.entrees("%", contexte()).count == VariableJeu.allCases.count)
        #expect(RecherchePalette.entrees("%vie", contexte()).map(\.titre) == ["%vie%", "%viemax%", "%viep%"])
    }

    @Test("/invite : toute l'équipe d'abord, puis chacun")
    func invitations() {
        let entrees = RecherchePalette.entrees("/invite", contexte())
        #expect(entrees.map(\.effet) == [.copier("/invite Brok; /invite Cid"), .copier("/invite Brok"), .copier("/invite Cid")])
    }

    @Test("Sans préfixe : un geste")
    func tout() {
        #expect(premiere("ranger", contexte())?.effet == .action(.rangerFenetres))
    }

    @Test("Les accents et la casse ne comptent pas")
    func normalisation() {
        #expect(premiere("/zaap COEUR", contexte())?.titre == "Cœur immaculé")
        #expect(premiere("/zaap eleveurs", contexte())?.titre == "Village des Éleveurs")
    }

    @Test("Les copies récentes : en tête, sans doublon, huit au plus")
    func recents() {
        var recents: [String] = []
        for texte in ["/zaap 1,1", "/zaap 2,2", "/zaap 1,1"] { recents = RecherchePalette.noterRecent(texte, dans: recents) }
        #expect(recents == ["/zaap 1,1", "/zaap 2,2"])
        for index in 0..<20 { recents = RecherchePalette.noterRecent("\(index)", dans: recents) }
        #expect(recents.count == RecherchePalette.nombreDeRecents)
        var avecRecents = contexte()
        avecRecents.recents = ["/travel 12,34"]
        #expect(premiere("12,34", avecRecents)?.effet == .copier("/travel 12,34"))
    }

    // MARK: - Filtres et tris

    @Test("Sans préfixe, les zaaps passent devant les lieux")
    func zaapsDevant() {
        let entrees = RecherchePalette.entrees("amakna", contexte())
        let premierLieu = entrees.firstIndex { $0.genre == .lieu }
        let dernierZaap = entrees.lastIndex { $0.genre == .zaap }
        #expect(premierLieu != nil && dernierZaap != nil && dernierZaap! < premierLieu!)
    }

    @Test("Le filtre ne garde qu'une famille ; vide, il liste la famille entière")
    func filtres() {
        #expect(RecherchePalette.entrees("amakna", contexte(), filtre: .lieux).allSatisfy { $0.genre == .lieu })
        #expect(RecherchePalette.entrees("", contexte(), filtre: .quetes).isEmpty)
        #expect(FiltrePalette.tout.suivant(-1) == FiltrePalette.allCases.last)
    }

    @Test("Les trois tris : proximité, alphabétique, type")
    func tris() {
        let proches = RecherchePalette.entrees("/travel banque", contexte(), tri: .proximite).compactMap(\.distance)
        #expect(proches == proches.sorted())
        let titres = RecherchePalette.entrees("", contexte(), filtre: .lieux, tri: .alphabetique).map(\.titre)
        #expect(titres == titres.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        let categories = RecherchePalette.entrees("", contexte(), filtre: .lieux, tri: .type).compactMap(\.categorie)
        #expect(categories == categories.sorted())
    }
}
