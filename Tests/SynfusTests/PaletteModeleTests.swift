import Testing
@testable import Synfus

/// Les gestes du modèle de la palette, hors de l'app (contexte imposé).
@MainActor
struct PaletteModeleTests {
    @Test("Le tri se choisit dans le menu ou passe au suivant (⌘T), en boucle")
    func tri() {
        let modele = PaletteModele(contexte: ContextePalette(), requete: "a")
        #expect(modele.tri == .auto)
        modele.choisirTri(.alphabetique)
        #expect(modele.tri == .alphabetique)
        modele.triSuivant()
        #expect(modele.tri == .type)
        modele.triSuivant()
        #expect(modele.tri == .auto)
    }

    @Test("Le pied montre le texte que ↵ copie, trajet compris ; rien pour ce qui ne copie pas")
    func texteDeLaSelection() {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -30, y: -40, zone: nil)
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(Carte.integree))
        let trajet = PaletteModele(contexte: contexte, requete: "6,8")
        #expect(trajet.texteDeLaSelection == "/zaap 5,7 ; /travel 6,8")
        let geste = PaletteModele(contexte: contexte, requete: "ranger les fenetres")
        #expect(geste.entrees.first?.effet == .action(.rangerFenetres))
        #expect(geste.texteDeLaSelection == nil)
        #expect(PaletteModele(contexte: contexte, requete: "zzzzzz").texteDeLaSelection == nil)
    }

    @Test("La carte choisie de l'almanax survit aux rechargements du contexte")
    func selectionDeLAlmanax() {
        let modele = PaletteModele(contexte: ContextePalette(), filtre: .almanax)
        modele.deplacer(ligne: 1)
        modele.deplacer(colonne: 1)
        #expect(modele.selection == 2)
        modele.rafraichir()
        #expect(modele.selection == 2)
    }

    @Test("La rangée suit l'état : trois vues et « Ici » au repos, cinq portées et « Ici » en recherche")
    func jeu() {
        #expect(FiltrePalette.jeu(enRecherche: false) == [.tout, .zaaps, .almanax, .ici])
        #expect(FiltrePalette.jeu(enRecherche: true) == [.tout, .lieux, .quetes, .creatures, .objets, .ici])
        let modele = PaletteModele(contexte: ContextePalette())
        #expect(modele.jeu == FiltrePalette.jeu(enRecherche: false))
        modele.requete = "a"
        #expect(modele.jeu == FiltrePalette.jeu(enRecherche: true))
        modele.requete = "  "
        #expect(modele.jeu == FiltrePalette.jeu(enRecherche: false))
    }

    @Test("La première capsule s'appelle « Accueil » au repos, « Tout » en recherche")
    func titreDeLaPremiere() {
        #expect(FiltrePalette.tout.titre(enRecherche: false) == L("palette.filtre.accueil"))
        #expect(FiltrePalette.tout.titre(enRecherche: true) == L("palette.filtre.tout"))
        #expect(FiltrePalette.zaaps.titre(enRecherche: false) == FiltrePalette.zaaps.titre(enRecherche: true))
    }

    @Test("La première lettre choisit « Tout » ; le champ vidé ramène à la vue quittée, même après une portée")
    func vueQuittee() {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.choisir(.zaaps)
        modele.requete = "b"
        #expect(modele.filtre == .tout)
        modele.choisir(.lieux)
        modele.requete = ""
        #expect(modele.filtre == .zaaps)
        modele.choisir(.almanax)
        modele.requete = "b"
        #expect(modele.filtre == .tout && !modele.surAlmanax)
        modele.requete = ""
        #expect(modele.filtre == .almanax && modele.surAlmanax)
    }

    @Test("« Ici » reste choisi quand on tape : c'est un filtre, pas une vue qu'on quitte")
    func iciResteChoisi() {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.choisir(.ici)
        modele.requete = "b"
        #expect(modele.filtre == .ici)
        modele.requete = ""
        #expect(modele.filtre == .ici)
    }

    @Test("Tab et ⇧Tab parcourent le jeu affiché, en boucle")
    func tabulation() {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.tabulation()
        #expect(modele.filtre == .zaaps)
        modele.tabulation()
        modele.tabulation()
        #expect(modele.filtre == .ici)
        modele.tabulation()
        #expect(modele.filtre == .tout)
        modele.tabulation(arriere: true)
        #expect(modele.filtre == .ici)
        modele.requete = "b"
        modele.choisir(.tout)
        modele.tabulation()
        #expect(modele.filtre == .lieux)
    }

    @Test("Échap : efface la recherche (la vue revient), puis rend l'Accueil")
    func echap() {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.choisir(.zaaps)
        modele.requete = "b"
        modele.echap()
        #expect(modele.requete.isEmpty && modele.filtre == .zaaps)
        modele.echap()
        #expect(modele.filtre == .tout)
    }

    @Test("Le tri ne se montre que là où il range : ni l'Accueil ni l'almanax, au repos")
    func triSeulementOuIlRange() {
        for (filtre, agit) in [(FiltrePalette.tout, false), (.almanax, false), (.zaaps, true), (.ici, true)] {
            #expect(filtre.triAgit(enRecherche: false) == agit)
            #expect(filtre.triAgit(enRecherche: true))
        }
        let modele = PaletteModele(contexte: ContextePalette())
        #expect(!modele.triAgit)
        modele.triSuivant()
        #expect(modele.tri == .auto)
        modele.requete = "a"
        #expect(modele.triAgit)
    }

    @Test("Sur « Zaaps », trois tris ; « Type », gardé d'avant, y passe pour « Auto »")
    func trisDesZaaps() {
        #expect(FiltrePalette.zaaps.tris(enRecherche: false) == [.auto, .proximite, .alphabetique])
        #expect(FiltrePalette.zaaps.tris(enRecherche: true) == TriPalette.allCases)
        let modele = PaletteModele(contexte: ContextePalette())
        modele.choisir(.zaaps)
        modele.choisirTri(.alphabetique)
        modele.triSuivant()
        #expect(modele.tri == .auto)
        modele.choisirTri(.type)
        #expect(modele.triAffiche == .auto)
        modele.requete = "a"
        #expect(modele.triAffiche == .type)
    }

    @Test("La palette s'ouvre sur l'Accueil, champ vide, première carte choisie ; deux exceptions disent où elles vont")
    func ouvertureSurLAccueil() {
        let modele = PaletteModele(contexte: ContextePalette(), requete: "amakna", filtre: .lieux)
        modele.selection = 3
        modele.ouvrir()
        #expect(modele.requete.isEmpty && modele.filtre == .tout && modele.selection == 0)
        modele.choisir(.zaaps)
        modele.ouvrir()
        #expect(modele.filtre == .tout)
        modele.ouvrir(vue: .almanax)
        #expect(modele.surAlmanax)
        modele.ouvrir(requete: "/combat")
        #expect(modele.requete == "/combat" && modele.filtre == .tout)
        modele.requete = ""
        #expect(modele.filtre == .tout)
    }
}
