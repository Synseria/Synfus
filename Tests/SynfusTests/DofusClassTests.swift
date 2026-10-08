import Testing
import SwiftUI
@testable import Synfus

struct DofusClassTests {
    private let catalogue = DofusClass.Catalogue.integre

    /// Les clés nomment les icônes déjà rangées par l'utilisateur
    /// (`iop.png`) : en changer une, c'est perdre son icône.
    @Test("Les 19 classes intégrées gardent leurs clés et leurs identifiants DofusDB")
    func clesStables() {
        #expect(DofusClass.integrees.map(\.key) == [
            "feca", "osamodas", "enutrof", "sram", "xelor", "ecaflip", "eniripsa", "iop", "cra", "sadida",
            "sacrieur", "pandawa", "roublard", "zobal", "steamer", "eliotrope", "huppermage", "ouginak", "forgelance",
        ])
        #expect(DofusClass.integrees.map(\.idDofusDB) == Array(1...18) + [20])
    }

    /// Le titre de fenêtre porte les accents, la clé de rangement n'en a pas :
    /// c'est ce pliage qui permet à « Crâ » de retrouver son icône `cra.png`.
    @Test("La clé est repliée sans accent ni majuscule", arguments: [
        ("Crâ", "cra"), ("Xélor", "xelor"), ("Féca", "feca"),
        ("IOP", "iop"), ("  Sram  ", "sram"),
    ])
    func clePliee(classe: String, attendue: String) {
        #expect(catalogue.key(for: classe) == attendue)
    }

    @Test("Une classe absente ou vide n'a pas de clé")
    func clefAbsente() {
        #expect(catalogue.key(for: nil) == nil)
        #expect(catalogue.key(for: "   ") == nil)
    }

    /// Chaque clé repliée doit tomber sur une entrée réelle : sans ça la classe
    /// serait traitée comme inconnue et recevrait une couleur de hachage.
    @Test("Chaque classe déclarée se retrouve depuis son libellé")
    func libellesRetrouves() {
        for breed in DofusClass.integrees {
            #expect(catalogue.key(for: breed.label) == breed.key,
                    "« \(breed.label) » ne se replie pas sur « \(breed.key) »")
            #expect(catalogue.color(for: breed.label) == breed.color)
        }
    }

    /// Le titre de la fenêtre est dans la langue du **jeu** : un client
    /// anglais annonce « Rogue », un espagnol « Tymador », et l'un comme
    /// l'autre est le Roublard — même clé, même icône, même couleur.
    @Test("Les noms anglais et espagnols retrouvent la clé française")
    func aliasEtrangers() {
        for breed in DofusClass.integrees {
            for nom in breed.alias {
                #expect(catalogue.key(for: nom) == breed.key, "« \(nom) »")
            }
        }
        #expect(catalogue.key(for: "Rogue") == "roublard")
        #expect(catalogue.key(for: "Masqueraider") == "zobal")
        #expect(catalogue.key(for: "Zurcarák") == "ecaflip")
        #expect(catalogue.key(for: "Yopuka") == "iop")
        #expect(catalogue.breed(forKey: "roublard")?.nom(langue: "es") == "Tymador")
        #expect(catalogue.breed(forKey: "roublard")?.nom(langue: "de") == "Roublard")
    }

    /// Une future classe ne doit pas s'afficher en gris : la teinte est dérivée
    /// du nom, donc stable d'un lancement à l'autre.
    @Test("Une classe inconnue reçoit une couleur stable")
    func classeInconnue() {
        let couleur = catalogue.color(for: "Nouvelleclasse")
        #expect(couleur == catalogue.color(for: "Nouvelleclasse"))
        #expect(couleur != catalogue.color(for: "Autreclasse"))
        #expect(couleur != Color.secondary)
    }

    @Test("Sans classe, la couleur reste neutre")
    func couleurNeutre() {
        #expect(catalogue.color(for: nil) == Color.secondary)
    }

    @Test("L'abréviation tient en deux lettres capitalisées")
    func abreviation() {
        #expect(catalogue.abbreviation(for: "Crâ") == "Cr")
        #expect(catalogue.abbreviation(for: "Iop") == "Io")
        #expect(catalogue.abbreviation(for: nil) == "?")
    }
}
