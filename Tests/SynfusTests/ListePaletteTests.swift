import Foundation
import Testing
@testable import Synfus

/// La liste classée de la palette : doublons réunis.
struct ListePaletteTests {
    private func lignesDuDonjon(_ entrees: [EntreePalette]) -> [EntreePalette] {
        entrees.filter { $0.effet == .donjon(ContexteNidas.donjon) }
    }

    @Test("Le boss et son donjon : une seule ligne, la mieux classée, à la case du donjon",
          arguments: TriPalette.allCases)
    func bossEtDonjon(tri: TriPalette) throws {
        let contexte = try ContexteNidas.contexte()
        for filtre in [FiltrePalette.tout, .donjons] {
            let lignes = lignesDuDonjon(RecherchePalette.entrees("nidas", contexte, filtre: filtre, tri: tri))
            #expect(lignes.count == 1)
        }
        let boss = try #require(lignesDuDonjon(RecherchePalette.entrees("nidas", contexte)).first)
        #expect(boss.estBoss && boss.titre == "Roi Nidas")
        #expect(boss.detail == Coordonnees.texte(-5, -5) && boss.carte == 112460048 && !boss.etiquetable)
        let donjon = try #require(lignesDuDonjon(RecherchePalette.entrees("palais", contexte)).first)
        #expect(!donjon.estBoss && donjon.titre == "Palais du roi Nidas" && donjon.etiquetable)
    }

    @Test("Un donjon à deux boss : une ligne, celle du boss cherché")
    func deuxBoss() {
        let boss = { (id: Int, nom: String) in
            EntreePalette(id: "boss:\(id)", genre: .monstre, titre: nom, effet: .donjon(1))
        }
        let donjon = EntreePalette(id: "lieu:1", genre: .lieu, titre: "Donjon", detail: "[1,1]", cle: "lieu:1", effet: .donjon(1))
        let autre = EntreePalette(id: "lieu:2", genre: .lieu, titre: "Autre", effet: .donjon(2))
        let lignes = ListePalette.fusionnerDonjons([boss(2, "Second"), autre, boss(1, "Premier"), donjon])
        #expect(lignes.map(\.id) == ["boss:2", "lieu:2"])
        #expect(lignes[0].detail == "[1,1]" && lignes[0].cle == nil)
    }

    @Test("En recherche, l'Accueil montre trois lignes par famille, puis une ligne vers le reste",
          arguments: TriPalette.allCases)
    func troisParFamille(tri: TriPalette) throws {
        let contexte = try ContexteNidas.contexte()
        let accueil = RecherchePalette.entrees("nidas", contexte, tri: tri)
        let objets = accueil.indices.filter { accueil[$0].genre == .objet }
        #expect(objets.count == ListePalette.parFamille)
        let suite = try #require(accueil.firstIndex { $0.effet == .famille(.objets, reste: 2) })
        let dernierObjet = try #require(objets.last)
        #expect(suite == dernierObjet + 1 && accueil[suite].titre == FiltrePalette.objets.suite(2))
        // Rien de perdu : le compte de l'Accueil est celui de la recherche dans chaque famille.
        #expect(ListePalette.nombre(accueil) == accueil.count - 1 + 2)
        #expect(RecherchePalette.entrees("nidas", contexte, filtre: .objets, tri: tri).count == 5)
    }

    @Test("Chaque entrée se range dans une capsule qui la garde ; persos, gestes et copies n'en ont pas")
    func familles() throws {
        let contexte = try ContexteNidas.contexte()
        for entree in RecherchePalette.entrees("roi", contexte) where entree.genre != .action {
            let famille = try #require(FiltrePalette.famille(de: entree))
            #expect(famille.garde(entree, enRecherche: true))
        }
        #expect(FiltrePalette.famille(de: EntreePalette(id: "a", genre: .recent, titre: "/w", effet: .copier("/w"))) == nil)
    }

    @Test("Ni une capsule, ni une commande, ni la grille au repos ne sont plafonnées")
    func horsAccueil() throws {
        let contexte = try ContexteNidas.contexte()
        #expect(!RecherchePalette.entrees("nidas", contexte, filtre: .objets).contains { $0.effet == .famille(.objets, reste: 2) })
        #expect(!RecherchePalette.entrees("/pnj", contexte).contains { if case .famille = $0.effet { true } else { false } })
        #expect(!RecherchePalette.entrees("", contexte).contains { if case .famille = $0.effet { true } else { false } })
    }

    @Test("↵ sur la ligne « de plus » passe sur la capsule, la recherche gardée")
    @MainActor
    func versLaCapsule() throws {
        let modele = PaletteModele(contexte: try ContexteNidas.contexte(), requete: "nidas")
        modele.selection = try #require(modele.entrees.firstIndex { $0.effet == .famille(.objets, reste: 2) })
        modele.valider()
        #expect(modele.filtre == .objets && modele.requete == "nidas" && modele.entrees.count == 5)
    }

    @Test("Une capsule s'efface exactement quand la recherche n'y trouverait rien ; l'Accueil jamais, rien sans texte",
          arguments: ["nidas", "nidsa", "roi", "zzzz", "/zaap", "/", "%", "%pos", "-5,-5", "  ", ""])
    func capsulesVides(requete: String) throws {
        let index = IndexPalette(try ContexteNidas.contexte())
        let attendues = requete.trimmingCharacters(in: .whitespaces).isEmpty ? [] : Set(FiltrePalette.allCases.filter {
            $0 != .tout && RecherchePalette.entrees(requete, index, filtre: $0).isEmpty
        })
        #expect(RecherchePalette.filtresVides(requete, index) == attendues)
    }

    @Test("« nidas » : Zaaps, Quêtes, Créatures et Almanax s'effacent ; Lieux garde le palais")
    func capsulesVidesNidas() throws {
        let vides = RecherchePalette.filtresVides("nidas", IndexPalette(try ContexteNidas.contexte()))
        #expect(vides == [.zaaps, .quetes, .creatures, .almanax])
    }
}
