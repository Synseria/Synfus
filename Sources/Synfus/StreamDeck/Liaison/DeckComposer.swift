import Foundation

/// Compose ce que le Stream Deck montre : la grille du mode choisi, remplie
/// avec le profil du perso devant, les touches du jeu, le menu s'il est
/// ouvert. **Pur** : tout ce qu'il faut est dans `Input`, les icônes viennent
/// de fermetures — c'est ce que les tests exercent, et ce que le miroir des
/// réglages dessine avec le même code que l'appareil.
enum DeckComposer {
    struct Input: Sendable {
        var colonnes = DeckLayout.defaultColumns
        var lignes = DeckLayout.defaultRows
        var mode: DeckSettings = .parBarre
        /// La page courante — barre active ou fenêtre selon le mode.
        var page = 0
        var menuOuvert = false
        var pageMenu = 0
        var perso: DeckPerso?
        var suivant: DeckPerso?
        var precedent: DeckPerso?
        var profile: SpellProfile?
        var keyMap: SpellKeyMap = .defaults
        var commandes: [GameCommand] = []
        var dofusDevant = false
        var enCombat: Bool?
        var appuiLongMs = 100
        var appuiTresLongMs = 200
        /// Les touches de sorts jouent chaque niveau à son seuil (voir `DeckTouche.progressif`).
        var progressif = true
        /// Le nom des sorts sous leur icône ; sinon il n'apparaît que pendant l'appui.
        var titresSorts = false
    }

    /// Ce qu'une source donne à voir et à faire.
    private struct Rendu {
        var icone: String?
        var symbole: String?
        var titre = ""
        var attenuee = false
        var action: DeckAction?
    }

    static func compose(_ input: Input, icone: (SpellSlot) -> String?) -> DeckPage {
        let layout = input.mode.layout(colonnes: input.colonnes, lignes: input.lignes, page: input.page)
        let pageCount = input.mode.pageCount(colonnes: input.colonnes, lignes: input.lignes)
        let barreActive = input.mode.barreActive(page: input.page, colonnes: input.colonnes, lignes: input.lignes)
        let dimmed = !input.dofusDevant

        // Les commandes que le menu pagine : celles qui n'ont pas déjà leur
        // touche dans la disposition, ni le havre-sac, posé sur « fin de tour ».
        let placed = Set(layout.touches.flatMap(\.sources)
            .compactMap { if case .commande(let id) = $0 { return id } else { return nil } })
        let paged = input.commandes.filter { !placed.contains($0.id) && $0.id != GameCommands.havresacID }
        let sortIndices = layout.touches.indices.filter { layout.touches[$0].court.estUnSort }
        let perMenuPage = max(1, sortIndices.count)
        let menuPages = max(1, (paged.count + perMenuPage - 1) / perMenuPage)
        let pageMenu = input.pageMenu % menuPages

        func command(_ id: String) -> GameCommand? { input.commandes.first { $0.id == id } }

        func frappe(_ key: HotKey?, nom: String) -> DeckAction? { key.map { .frappe($0, nom: nom) } }

        func sort(barre: Int, position: Int) -> Rendu {
            let slot = input.profile?.slot(bar: barre, position: position)
            let key = input.keyMap.key(bar: barre, position: position)
            let nom = slot?.nom ?? "\(position + 1)"
            return Rendu(icone: slot.flatMap(icone), titre: input.titresSorts || slot == nil ? nom : "", attenuee: dimmed,
                         action: frappe(key, nom: nom))
        }

        func perso(_ p: DeckPerso?, titre: (String) -> String, commande: DeckCommand.Kind) -> Rendu {
            Rendu(icone: p?.icone, symbole: p == nil ? "person.slash" : nil,
                  titre: p.map { titre($0.nom) } ?? "Aucun\nperso", attenuee: dimmed,
                  action: .commande(commande, nom: commande == .persoSuivant ? "Perso suivant" : "Perso précédent"))
        }

        func gameCommand(_ id: String) -> Rendu {
            guard let c = command(id) else { return Rendu(symbole: "questionmark", titre: id, attenuee: true) }
            return Rendu(symbole: c.symbole, titre: c.nom, attenuee: dimmed || c.touche == nil, action: frappe(c.touche, nom: c.nom))
        }

        func render(_ source: DeckSource) -> Rendu {
            switch source {
            case .sort(let barre, let position): return sort(barre: barre, position: position)
            case .sortActif(let position): return sort(barre: barreActive, position: position)
            case .sortBarreDecalee(let position, let decalage):
                return sort(barre: (barreActive + decalage) % SpellProfile.barCount, position: position)
            case .persoSuivant: return perso(input.perso, titre: { $0 + " ▶" }, commande: .persoSuivant)
            case .persoPrecedent: return perso(input.perso, titre: { "◀ " + $0 }, commande: .persoPrecedent)
            case .persoActif: return perso(input.perso, titre: { $0 }, commande: .persoSuivant)
            case .barreSuivante where input.menuOuvert:
                return Rendu(symbole: "arrow.right.to.line", titre: "Menu \(pageMenu + 1)/\(menuPages)",
                             attenuee: dimmed || menuPages == 1, action: .commande(.pageMenuSuivante, nom: "Page suivante du menu"))
            case .barreSuivante where pageCount == 1:
                // Une seule page : rien à tourner, la touche sert au corps à corps.
                return render(.corpsACorps)
            case .barreSuivante:
                let label = input.mode.kind == .parRangee ? "Page" : "Barre"
                return Rendu(symbole: "arrow.turn.down.right", titre: "\(label) \(input.page % pageCount + 1)/\(pageCount)",
                             attenuee: dimmed, action: .commande(.barreSuivante, nom: "\(label) suivante"))
            case .barrePrecedente:
                return Rendu(symbole: "arrow.turn.up.left", titre: "Précédente", attenuee: dimmed,
                             action: .commande(.barrePrecedente, nom: "Barre précédente"))
            case .barrePremiere:
                return Rendu(symbole: "arrow.left.to.line", titre: "Barre 1", attenuee: dimmed,
                             action: .commande(.barrePremiere, nom: "Première barre"))
            case .menu:
                return Rendu(symbole: "square.grid.2x2", titre: input.menuOuvert ? "Sorts" : "Menu", attenuee: dimmed,
                             action: .commande(.menu, nom: input.menuOuvert ? "Revenir aux sorts" : "Menu"))
            case .finDeTour where input.menuOuvert:
                return gameCommand(GameCommands.havresacID)
            case .finDeTour:
                let key = input.keyMap.finDeTour
                // En combat, la touche s'allume ; hors combat (ou sans verdict), elle reste discrète.
                return Rendu(symbole: "flag.checkered", titre: key == nil ? "Fin de tour\n(à régler)" : "Fin de tour",
                             attenuee: dimmed || key == nil || input.enCombat == false, action: frappe(key, nom: "Fin de tour"))
            case .corpsACorps:
                let key = input.keyMap.corpsACorps
                return Rendu(symbole: "figure.fencing", titre: key == nil ? "CàC\n(à régler)" : "Corps à corps",
                             attenuee: dimmed || key == nil, action: frappe(key, nom: "Corps à corps"))
            case .reconnaitre:
                return Rendu(symbole: "wand.and.stars", titre: "Relire les sorts", attenuee: dimmed,
                             action: .commande(.reconnaitre, nom: "Relire les sorts à l'écran"))
            case .commande(let id): return gameCommand(id)
            case .vide: return Rendu(attenuee: true)
            }
        }

        var touches: [DeckTouche] = []
        for (index, tile) in layout.touches.enumerated() {
            var rendu: Rendu
            var long: Rendu?
            var tresLong: Rendu?
            if input.menuOuvert, let rank = sortIndices.firstIndex(of: index) {
                // Le menu recouvre les sorts : une commande par touche, par pages.
                let absolute = pageMenu * perMenuPage + rank
                rendu = absolute < paged.count ? gameCommand(paged[absolute].id) : Rendu(attenuee: true)
            } else {
                rendu = render(tile.court)
                // Une case que Synfus ne connaît pas n'est pas une case vide
                // pour le jeu : le profil peut simplement ne pas être rempli.
                // Le niveau joue sa touche quand même — le deck est un clavier
                // —, il n'a juste pas de vignette.
                long = tile.long.map(render)
                tresLong = tile.tresLong.map(render)
            }
            touches.append(DeckTouche(index: index, role: tile.court.role, icone: rendu.icone,
                                      iconeLong: long?.icone, iconeTresLong: tresLong?.icone,
                                      symbole: rendu.symbole, titre: rendu.titre, attenuee: rendu.attenuee,
                                      court: rendu.action, long: long?.action, tresLong: tresLong?.action,
                                      progressif: input.progressif && !input.menuOuvert && tile.sources.allSatisfy(\.estUnSort)
                                          && (long != nil || tresLong != nil)))
        }
        return DeckPage(colonnes: input.colonnes, lignes: input.lignes, dofusDevant: input.dofusDevant,
                        perso: input.perso, touches: touches, appuiLongMs: input.appuiLongMs,
                        appuiTresLongMs: input.appuiTresLongMs)
    }
}
