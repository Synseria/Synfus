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
        contexte.zaaps = ZaapsSitues(CatalogueZaaps.actifs(base: CarteDuJeu.integree.zaaps, ajoutes: [], choix: [:]),
                                     reseau: ReseauSousZones(CarteDuJeu.integree))
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

    @Test("Une seule rangée, dans l'ordre des capsules, quel que soit le texte tapé")
    func rangee() {
        #expect(FiltrePalette.allCases == [.tout, .zaaps, .lieux, .donjons, .pnj, .quetes, .creatures, .objets, .almanax])
        #expect(FiltrePalette.tout.titre == L("palette.filtre.accueil"))
    }

    @Test("Taper puis effacer ne change ni la capsule choisie ni son nom", arguments: FiltrePalette.allCases)
    func capsuleStable(filtre: FiltrePalette) {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.choisir(filtre)
        let titre = filtre.titre
        for requete in ["b", "bonta", "  ", "", "/zaap", "%", ""] {
            modele.requete = requete
            #expect(modele.filtre == filtre)
            #expect(modele.filtre.titre == titre)
        }
    }

    @Test("Tab et ⇧Tab parcourent la rangée, en boucle, avec ou sans texte")
    func tabulation() {
        let modele = PaletteModele(contexte: ContextePalette())
        modele.tabulation()
        #expect(modele.filtre == .zaaps)
        modele.tabulation()
        #expect(modele.filtre == .lieux)
        modele.tabulation(arriere: true)
        modele.tabulation(arriere: true)
        #expect(modele.filtre == .tout)
        modele.tabulation(arriere: true)
        #expect(modele.filtre == .almanax)
        modele.tabulation()
        #expect(modele.filtre == .tout)
        modele.requete = "b"
        modele.tabulation()
        #expect(modele.filtre == .zaaps)
    }

    @Test("Échap : efface la recherche (la capsule reste), puis rend l'Accueil")
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
        for (filtre, agit) in [(FiltrePalette.tout, false), (.almanax, false), (.zaaps, true), (.donjons, true),
                               (.pnj, true), (.quetes, true)] {
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

    @Test("Au repos : Donjons et PNJ rangent par Auto, proximité et A → Z ; Quêtes, sans position, par Auto et A → Z")
    func trisDesVues() {
        for vue in [FiltrePalette.donjons, .pnj] {
            #expect(vue.tris(enRecherche: false) == [.auto, .proximite, .alphabetique])
            #expect(vue.tris(enRecherche: true) == TriPalette.allCases)
        }
        #expect(FiltrePalette.quetes.tris(enRecherche: false) == [.auto, .alphabetique])
        #expect(FiltrePalette.quetes.tris(enRecherche: true) == TriPalette.allCases)
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

    @Test("La palette s'ouvre sur l'Accueil, champ vide, première carte choisie ; une vue demandée fait exception")
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
        modele.ouvrir(vue: .donjons)
        #expect(modele.requete.isEmpty && modele.filtre == .donjons)
    }

    @Test("Le pied ne propose ⌘E et ⌘D que sur une ligne qui s'étiquette : pas sur un boss ni un objet")
    func gestesDuPied() throws {
        let modele = PaletteModele(contexte: try ContexteNidas.contexte(), requete: "nidas")
        let lignes = modele.entrees
        func etiquetable(_ entree: EntreePalette) -> Bool {
            modele.selection = lignes.firstIndex(of: entree) ?? -1
            return modele.selectionEtiquetable
        }
        let boss = try #require(lignes.first { $0.estBoss })
        let objet = try #require(lignes.first { $0.genre == .objet })
        let pnj = try #require(lignes.first { $0.genre == .pnj })
        #expect(!etiquetable(boss) && !etiquetable(objet))
        #expect(etiquetable(pnj))
        #expect(!PaletteModele(contexte: ContextePalette(), filtre: .almanax).selectionEtiquetable)
    }
}
