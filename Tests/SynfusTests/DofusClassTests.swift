import Testing
import SwiftUI
@testable import Synfus

struct DofusClassTests {

    @Test("Les 19 classes sont déclarées avec des clés uniques")
    func clesUniques() {
        #expect(DofusClass.breeds.count == 19)
        #expect(Set(DofusClass.breeds.map(\.key)).count == DofusClass.breeds.count)
    }

    /// Le titre de fenêtre porte les accents, la clé de rangement n'en a pas :
    /// c'est ce pliage qui permet à « Crâ » de retrouver son icône `cra.png`.
    @Test("La clé est repliée sans accent ni majuscule", arguments: [
        ("Crâ", "cra"), ("Xélor", "xelor"), ("Féca", "feca"),
        ("IOP", "iop"), ("  Sram  ", "sram"),
    ])
    func clePliee(classe: String, attendue: String) {
        #expect(DofusClass.key(for: classe) == attendue)
    }

    @Test("Une classe absente ou vide n'a pas de clé")
    func clefAbsente() {
        #expect(DofusClass.key(for: nil) == nil)
        #expect(DofusClass.key(for: "   ") == nil)
    }

    /// Chaque clé repliée doit tomber sur une entrée réelle : sans ça la classe
    /// serait traitée comme inconnue et recevrait une couleur de hachage.
    @Test("Chaque classe déclarée se retrouve depuis son libellé")
    func libellesRetrouves() {
        for breed in DofusClass.breeds {
            #expect(DofusClass.key(for: breed.label) == breed.key,
                    "« \(breed.label) » ne se replie pas sur « \(breed.key) »")
            #expect(DofusClass.color(for: breed.label) == breed.color)
        }
    }

    /// Le titre de la fenêtre est dans la langue du **jeu** : un client
    /// anglais annonce « Rogue », un espagnol « Tymador », et l'un comme
    /// l'autre est le Roublard — même clé, même icône, même couleur.
    @Test("Les noms anglais et espagnols retrouvent la clé française")
    func aliasEtrangers() {
        for breed in DofusClass.breeds {
            #expect(DofusClass.key(for: breed.en) == breed.key, "« \(breed.en) » (en)")
            #expect(DofusClass.key(for: breed.es) == breed.key, "« \(breed.es) » (es)")
        }
        #expect(DofusClass.key(for: "Rogue") == "roublard")
        #expect(DofusClass.key(for: "Masqueraider") == "zobal")
        #expect(DofusClass.key(for: "Zurcarák") == "ecaflip")
        #expect(DofusClass.key(for: "Yopuka") == "iop")
        #expect(DofusClass.breed(forKey: "roublard")?.nom(langue: "es") == "Tymador")
        #expect(DofusClass.breed(forKey: "roublard")?.nom(langue: "de") == "Roublard")
    }

    /// Une future classe ne doit pas s'afficher en gris : la teinte est dérivée
    /// du nom, donc stable d'un lancement à l'autre.
    @Test("Une classe inconnue reçoit une couleur stable")
    func classeInconnue() {
        let couleur = DofusClass.color(for: "Nouvelleclasse")
        #expect(couleur == DofusClass.color(for: "Nouvelleclasse"))
        #expect(couleur != DofusClass.color(for: "Autreclasse"))
        #expect(couleur != Color.secondary)
    }

    @Test("Sans classe, la couleur reste neutre")
    func couleurNeutre() {
        #expect(DofusClass.color(for: nil) == Color.secondary)
    }

    @Test("L'abréviation tient en deux lettres capitalisées")
    func abreviation() {
        #expect(DofusClass.abbreviation(for: "Crâ") == "Cr")
        #expect(DofusClass.abbreviation(for: "Iop") == "Io")
        #expect(DofusClass.abbreviation(for: nil) == "?")
    }
}
