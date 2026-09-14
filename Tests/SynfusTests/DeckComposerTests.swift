import Testing
import Foundation
import Carbon.HIToolbox
@testable import Synfus

/// La composition des pages du Stream Deck : les dispositions générées, la
/// pagination, le menu, les actions courtes et longues — tout ce que le
/// plugin reçoit, sans appareil.
struct DeckComposerTests {

    private func profile() -> SpellProfile {
        var p = SpellProfile.empty(perso: "Aeryn", classe: "Feca")
        p.set(SpellSlot(sortId: 7, nom: "Bouclier"), bar: 0, position: 0)
        p.set(SpellSlot(sortId: 8, nom: "Glyphe"), bar: 1, position: 0)
        p.set(SpellSlot(sortId: 9, nom: "Douze"), bar: 0, position: 11)
        p.set(SpellSlot(sortId: 10, nom: "Trois"), bar: 2, position: 0)
        p.set(SpellSlot(sortId: 7, nom: "Six"), bar: 0, position: 5)
        return p
    }

    private func input(_ mode: DeckSettings = .parBarre, page: Int = 0, menu: Bool = false, pageMenu: Int = 0) -> DeckComposer.Input {
        var i = DeckComposer.Input()
        i.mode = mode
        i.page = page
        i.menuOuvert = menu
        i.pageMenu = pageMenu
        i.profile = profile()
        i.perso = DeckPerso(nom: "Aeryn", classe: "Feca", icone: "EMB")
        i.commandes = GameCommands.defaults
        i.dofusDevant = true
        return i
    }

    private func compose(_ i: DeckComposer.Input) -> DeckPage {
        DeckComposer.compose(i) { $0.sortId == 7 ? "PNG" : nil }
    }

    @Test("Barre par barre, 5 × 3 : la navigation en haut, dix cases de la barre active en dessous")
    func parBarre() {
        let page = compose(input())
        #expect(page.touches.count == 15)
        #expect(page.touches[0].court?.commande == .barreSuivante && page.touches[0].long?.commande == .barrePremiere)
        #expect(page.touches[0].titre == "Barre 1/3")
        #expect(page.touches[1].court?.commande == .persoSuivant && page.touches[1].long?.commande == .persoPrecedent)
        #expect(page.touches[1].titre == "Aeryn ▶" && page.touches[1].icone == "EMB")
        #expect(page.touches[2].court?.commande == .menu && page.touches[2].titre == "Menu")
        #expect(page.touches[3].court?.touche == DeckKey(HotKey(keyCode: HotKey.keyCode(typing: "W")!, modifiers: UInt32(controlKey))))
        #expect(page.touches[4].court == nil && page.touches[4].attenuee)   // fin de tour sans touche réglée
        #expect(page.touches[4].long == nil)   // jamais d'action longue sur la fin de tour : trop dangereux
        // Appui long sur la case 1 : la case 1 de la barre 2, en vignette ; case 2 d'en face vide → rien.
        #expect(page.touches[5].long?.touche == DeckKey(HotKey(keyCode: 18, modifiers: UInt32(controlKey))))
        #expect(page.touches[5].tresLong?.touche == DeckKey(HotKey(keyCode: 18, modifiers: UInt32(controlKey | shiftKey))))
        // La case 2 d'en face est inconnue de Synfus, pas du jeu : elle joue sa touche, sans vignette.
        #expect(page.touches[5].iconeLong == nil && page.touches[6].long?.touche != nil && page.touches[6].iconeLong == nil)
        #expect(page.touches[5].progressif && !page.touches[1].progressif && page.touches[6].progressif)
        #expect(page.touches[5].titre == "Bouclier" && page.touches[5].icone == "PNG")
        #expect(page.touches[5].court?.touche == DeckKey(HotKey(keyCode: 18, modifiers: 0)))
        #expect(page.touches[6].icone == nil && page.touches[6].titre == "2" && page.touches[6].court?.touche != nil)
        #expect(page.touches[14].court?.touche == DeckKey(HotKey(keyCode: 29, modifiers: 0)))
    }

    @Test("Barre suivante tourne la barre active : la page 1 montre la barre 2 avec ⌃")
    func barreActive() {
        let page = compose(input(page: 1))
        #expect(page.touches[0].titre == "Barre 2/3")
        #expect(page.touches[5].titre == "Glyphe")
        #expect(page.touches[5].court?.touche?.modifiers == UInt32(controlKey))
        #expect(DeckSettings.parBarre.pageCount(colonnes: 5, lignes: 3) == 3)
        var off = DeckSettings.parBarre
        off.sortLong = .aucun
        #expect(compose(input(off)).touches[5].long == nil)
        off.sortLong = .unNiveau
        #expect(compose(input(off)).touches[5].long != nil && compose(input(off)).touches[5].tresLong == nil)
        // Les barres retenues, dans l'ordre : barre 3 puis barre 1.
        let ordre = DeckSettings(kind: .parBarre, pages: [2, 0])
        #expect(ordre.pageCount(colonnes: 5, lignes: 3) == 2)
        #expect(compose(input(ordre)).touches[5].titre == "Trois")
        #expect(compose(input(ordre, page: 1)).touches[5].titre == "Bouclier")
    }

    @Test("Une barre par rangée : L1 1-5 / L2 1-5, puis 6-10, puis 11-12, puis la barre 3 ; appui long = fenêtre suivante")
    func parRangee() {
        let rangee = DeckSettings(kind: .parRangee)
        #expect(rangee.pageCount(colonnes: 5, lignes: 3) == 6)
        let p0 = compose(input(rangee))
        #expect(p0.touches[5].long?.touche == DeckKey(HotKey(keyCode: 22, modifiers: 0)))   // case 6
        #expect(p0.touches[5].iconeLong == "PNG" && p0.touches[6].long?.touche != nil && p0.touches[6].iconeLong == nil)   // case 7 inconnue : la touche, sans vignette
        #expect(p0.touches[5].tresLong?.touche == DeckKey(HotKey(keyCode: 27, modifiers: 0)))   // case 11
        #expect(p0.touches[6].tresLong?.touche == DeckKey(HotKey(keyCode: 24, modifiers: 0)))   // case 2 → très long = case 12
        #expect(DeckLayout.pageLabelParRangee(0, colonnes: 5, lignes: 3) == "Barres 1-2 · cases 1-5")
        #expect(DeckLayout.pageLabelParRangee(5, colonnes: 5, lignes: 3) == "Barre 3 · cases 11-12")
        #expect(p0.touches[0].titre == "Page 1/6")
        #expect(p0.touches[5].titre == "Bouclier" && p0.touches[10].titre == "Glyphe")
        #expect(p0.touches[10].court?.touche?.modifiers == UInt32(controlKey))
        let p2 = compose(input(rangee, page: 2))
        #expect(p2.touches[6].titre == "Douze" && p2.touches[7].court == nil && p2.touches[7].titre == "")
        let p3 = compose(input(rangee, page: 3))
        #expect(p3.touches[5].titre == "Trois" && p3.touches[10].court == nil)
    }

    @Test("Les pages retenues, dans l'ordre choisi : deux pages, la seconde d'abord")
    func pagesChoisies() {
        let bridee = DeckSettings(kind: .parRangee, pages: [1, 0])
        #expect(bridee.pageCount(colonnes: 5, lignes: 3) == 2)
        let p0 = compose(input(bridee))
        #expect(p0.touches[0].titre == "Page 1/2" && p0.touches[5].titre == "Six")
        let p1 = compose(input(bridee, page: 1))
        #expect(p1.touches[5].titre == "Bouclier")
        // Une page hors grille est ignorée ; toutes ignorées = toutes.
        #expect(DeckSettings(kind: .parRangee, pages: [42]).pageCount(colonnes: 5, lignes: 3) == 6)
    }

    @Test("Menu ouvert : les commandes paginées sur les touches de sorts, havre-sac sur fin de tour, suivi non répété")
    func menu() {
        let page = compose(input(menu: true))
        #expect(page.touches[2].titre == "Sorts")
        #expect(page.touches[0].court?.commande == .pageMenuSuivante && page.touches[0].titre == "Menu 1/2")
        #expect(page.touches[4].titre == "Havre-sac" && page.touches[4].symbole == "house")
        #expect(page.touches[5].titre == "Inventaire" && page.touches[5].court?.touche != nil)
        #expect(!page.touches[5...14].contains { $0.titre == "Suivi du perso" || $0.titre == "Havre-sac" })
        let page2 = compose(input(menu: true, pageMenu: 1))
        #expect(page2.touches[5].titre == "Alliance")
        #expect(page2.touches[14].court == nil)   // au-delà des 19 commandes, vide
        #expect(page2.touches[0].titre == "Menu 2/2")
    }

    @Test("Disposition personnalisée : un second sort en appui long, une commande posée n'est plus dans le menu")
    func personnalisee() {
        var layout = DeckLayout.parBarre(colonnes: 5, lignes: 3)
        layout[1, 0] = DeckTile(.sort(barre: 0, position: 0), long: .sort(barre: 1, position: 0), tresLong: .commande("inventaire"))
        layout[1, 1] = DeckTile(.commande("inventaire"))
        let page = compose(input(DeckSettings(kind: .personnalisee, custom: layout)))
        #expect(page.touches[5].titre == "Bouclier")
        #expect(page.touches[5].long?.touche == DeckKey(HotKey(keyCode: 18, modifiers: UInt32(controlKey))))
        #expect(page.touches[5].tresLong?.nom == "Inventaire" && !page.touches[5].progressif)   // une commande dans les niveaux : pas progressif
        #expect(page.touches[6].titre == "Inventaire")
        let menu = compose(input(DeckSettings(kind: .personnalisee, custom: layout), menu: true))
        #expect(!menu.touches.contains { $0.titre == "Inventaire" && $0.index != 6 })
        // Ramenée sur une grille plus petite, chaque touche garde sa ligne et sa colonne.
        let small = layout.fitted(colonnes: 3, lignes: 2)
        #expect(small.touches.count == 6 && small[1, 0].court == .sort(barre: 0, position: 0) && small[0, 2].court == .menu)
    }

    @Test("Sans Dofus devant, tout est atténué ; sans perso, la touche perso le dit")
    func attenue() {
        var i = input()
        i.dofusDevant = false
        i.perso = nil
        i.profile = nil
        let page = compose(i)
        #expect(page.touches.allSatisfy(\.attenuee) && !page.dofusDevant)
        #expect(page.touches[1].titre == "Aucun\nperso" && page.touches[1].symbole == "person.slash")
    }

    @Test("La fin de tour s'allume en combat et s'éteint hors combat")
    func combat() {
        var i = input()
        i.keyMap.finDeTour = HotKey(keyCode: 49, modifiers: 0)
        i.enCombat = true
        #expect(compose(i).touches[4].attenuee == false)
        i.enCombat = false
        #expect(compose(i).touches[4].attenuee == true)
    }

    @Test("Une page se relit à l'identique après encodage — c'est le contrat du plugin")
    func allerRetour() throws {
        let page = compose(input())
        let back = try JSONDecoder().decode(DeckPage.self, from: JSONEncoder().encode(page))
        #expect(back == page && back.type == "page" && back.version == 2)
    }
}
