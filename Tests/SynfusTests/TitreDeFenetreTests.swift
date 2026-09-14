import Testing
@testable import Synfus

/// Le titre de fenêtre est la seule source d'information sur un perso : tous les
/// clients partagent le même bundle, donc la même icône. Ces tests fixent le
/// contrat d'analyse de ce titre, y compris ses cas dégradés.
@MainActor
struct TitreDeFenetreTests {

    // MARK: - Distinguer un perso d'un client à l'écran de connexion

    @Test("Un perso connecté est reconnu")
    func persoConnecte() {
        #expect(WindowTitle.isCharacterWindow(title: "Syn-App - Feca - 3.6.7.7 - Release"))
    }

    /// Le cas qui compte le plus : un client resté au login prendrait un
    /// emplacement et décalerait les raccourcis de tous les vrais persos.
    @Test("Un client sans perso en jeu est écarté", arguments: [
        "Dofus", "dofus", "  Dofus  ", "DOFUS", "",
    ])
    func clientSansPerso(titre: String) {
        #expect(!WindowTitle.isCharacterWindow(title: titre))
    }

    @Test("Un titre sans séparateur n'est pas un perso")
    func titreSansSeparateur() {
        #expect(!WindowTitle.isCharacterWindow(title: "Chargement en cours"))
    }

    // MARK: - Nom du perso

    @Test("Le nom est le segment qui précède le séparateur", arguments: [
        ("Syn-App - Feca - 3.6.7.7 - Release", "Syn-App"),
        ("Aeryn – Iop – 2.70 – Release", "Aeryn"),
        ("Nova — Crâ — Release", "Nova"),
        ("Kaeli | Sram | Release", "Kaeli"),
        ("Milo • Xélor • Release", "Milo"),
    ])
    func nomExtrait(titre: String, attendu: String) {
        #expect(WindowTitle.characterName(fromTitle: titre) == attendu)
    }

    /// Un nom composé garde ses tirets : le séparateur est « - » entouré
    /// d'espaces, pas le tiret nu.
    @Test("Un tiret dans le nom n'est pas un séparateur")
    func nomAvecTiret() {
        #expect(WindowTitle.characterName(fromTitle: "Jean-Michel - Iop - Release") == "Jean-Michel")
    }

    @Test("Un titre vide donne un libellé de repli")
    func nomDeRepli() {
        #expect(WindowTitle.characterName(fromTitle: "   ") == "Sans titre")
    }

    /// Si le premier segment est « Dofus », ce n'est pas un nom de perso : on
    /// continue à chercher plutôt que de renvoyer une évidence inutile.
    @Test("Un premier segment « Dofus » est ignoré")
    func premierSegmentDofus() {
        let nom = WindowTitle.characterName(fromTitle: "Dofus - Feca - Release")
        #expect(nom != "Dofus")
    }

    @Test("Un titre sans séparateur est renvoyé tel quel")
    func titreEntier() {
        #expect(WindowTitle.characterName(fromTitle: "Bidule") == "Bidule")
    }

    // MARK: - Ce qui mérite d'être mémorisé

    /// Un client resté au login s'intitule « Dofus 3.3.4.9 - Release » : son nom
    /// dérivé n'est qu'un numéro de version, et s'inscrirait à demeure dans la
    /// liste des persos — à changer à chaque mise à jour du jeu.
    @Test("Une version du client ne s'enregistre pas comme perso", arguments: [
        "Dofus 3.3.4.9",
        "Dofus - 3.3.4.9 - Release",
        "Dofus 2.70",
        "dofus",
        "3.6.7.7",
        "",
        "   ",
    ])
    func versionNonMemorisee(nom: String) {
        #expect(!WindowTitle.isPersistableName(nom))
    }

    /// Le suffixe est ajouté par `refresh()` selon l'ordre de découverte : il ne
    /// désigne aucun perso en propre.
    @Test("Un homonyme suffixé ne s'enregistre pas", arguments: [
        "Syn-App (2)", "Nova (3)", "Dofus 3.3.4.9 (2)",
    ])
    func homonymeNonMemorise(nom: String) {
        #expect(!WindowTitle.isPersistableName(nom))
    }

    @Test("Un vrai nom de perso est mémorisé", arguments: [
        "Syn-App", "Jean-Michel", "Nova", "Kaeli", "Milo",
    ])
    func nomMemorise(nom: String) {
        #expect(WindowTitle.isPersistableName(nom))
    }

    /// Une parenthèse non numérique n'est pas un suffixe de doublon — et rien
    /// n'interdit à un nom de contenir un chiffre.
    @Test("Une parenthèse quelconque ne fait pas un doublon")
    func parentheseNonNumerique() {
        #expect(WindowTitle.isPersistableName("Machin (bis)"))
        #expect(WindowTitle.isPersistableName("Nova2"))
    }

    // MARK: - Classe du perso

    @Test("La classe est le deuxième segment")
    func classeExtraite() {
        #expect(WindowTitle.characterClass(fromTitle: "Syn-App - Feca - 3.6.7.7 - Release") == "Feca")
    }

    @Test("Un accent est conservé tel quel dans la classe")
    func classeAccentuee() {
        #expect(WindowTitle.characterClass(fromTitle: "Nova - Crâ - 2.70 - Release") == "Crâ")
    }

    /// Certains titres placent la version en deuxième position : la prendre pour
    /// une classe donnerait une pastille colorée absurde.
    @Test("Un numéro de version n'est pas pris pour une classe")
    func versionEnDeuxiemePosition() {
        #expect(WindowTitle.characterClass(fromTitle: "Syn-App - 3.6.7.7 - Release") == nil)
    }

    @Test("Un titre à un seul segment n'a pas de classe")
    func pasDeClasse() {
        #expect(WindowTitle.characterClass(fromTitle: "Syn-App") == nil)
    }

    /// La classe n'est cherchée que sur « - » ; les autres séparateurs suffisent
    /// à identifier un perso mais pas à en déduire la classe.
    @Test("Un séparateur exotique ne donne pas de classe")
    func separateurExotique() {
        #expect(WindowTitle.characterClass(fromTitle: "Kaeli | Sram | Release") == nil)
    }
}
