import AppKit
import Testing
@testable import Synfus

/// Au clavier la sélection suit : où mène chaque flèche, sans jamais sortir du groupe.
struct GroupeSelectionTests {
    @Test("Une rangée n'écoute que gauche et droite, une colonne que haut et bas")
    func axes() {
        #expect(DispositionGroupe.horizontale.voisin(depuis: 1, parmi: 3, .droite) == 2)
        #expect(DispositionGroupe.horizontale.voisin(depuis: 1, parmi: 3, .gauche) == 0)
        #expect(DispositionGroupe.horizontale.voisin(depuis: 1, parmi: 3, .bas) == nil)
        #expect(DispositionGroupe.verticale.voisin(depuis: 1, parmi: 3, .bas) == 2)
        #expect(DispositionGroupe.verticale.voisin(depuis: 1, parmi: 3, .gauche) == nil)
    }

    @Test("Aux bords la sélection reste, sans rang elle prend le premier")
    func bords() {
        #expect(DispositionGroupe.horizontale.voisin(depuis: 2, parmi: 3, .droite) == 2)
        #expect(DispositionGroupe.verticale.voisin(depuis: 0, parmi: 3, .haut) == 0)
        #expect(DispositionGroupe.verticale.voisin(depuis: nil, parmi: 3, .bas) == 0)
        #expect(DispositionGroupe.horizontale.voisin(depuis: nil, parmi: 0, .droite) == nil)
    }

    @Test("Une grille se parcourt dans les quatre sens")
    func grille() {
        let grille = DispositionGroupe.grille(colonnes: 4)
        #expect(grille.voisin(depuis: 5, parmi: 8, .haut) == 1)
        #expect(grille.voisin(depuis: 5, parmi: 8, .bas) == 7)
        #expect(grille.voisin(depuis: 6, parmi: 8, .bas) == 7)
        #expect(grille.voisin(depuis: 5, parmi: 8, .gauche) == 4)
        #expect(grille.voisin(depuis: 5, parmi: 8, .droite) == 6)
    }
}

/// Une commande ou une variable de la palette a son symbole, et lui seul.
struct SymbolesPaletteTests {
    @Test("Chaque commande et chaque variable a un symbole qui existe et qui n'est qu'à elle")
    func symboles() {
        let symboles = CommandeJeu.allCases.map(\.symbole)
        #expect(Set(symboles).count == symboles.count)
        let variables = VariableJeu.allCases.map(\.symbole)
        #expect(Set(variables).count == variables.count)
        for nom in symboles + variables {
            #expect(NSImage(systemSymbolName: nom, accessibilityDescription: nil) != nil, "\(nom)")
        }
        #expect(!symboles.contains("slash.circle"))
    }

    @Test("La ligne d'une commande porte son symbole")
    func ligne() {
        let entrees = RecherchePalette.entrees("/", IndexPalette(ContextePalette()), filtre: .tout)
        #expect(!entrees.isEmpty && entrees.allSatisfy { $0.symbole != nil })
    }
}

@MainActor
struct ToucheDuPersoTests {
    @Test("La pastille montre le raccourci réel, à défaut le numéro")
    func touche() {
        let cmd1 = HotKey.defaultHotKey(slot: 0)
        #expect(BarView.toucheDuPerso(index: 0, raccourcis: [cmd1]) == cmd1?.displayString)
        #expect(BarView.toucheDuPerso(index: 1, raccourcis: [cmd1, nil]) == "2")
        #expect(BarView.toucheDuPerso(index: 3, raccourcis: []) == "4")
    }
}
