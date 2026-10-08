import Testing
import Foundation
@testable import Synfus

/// Les tables de libellés, `Resources/Localisation/<code>.json`, et la règle
/// qui choisit la langue. Le dossier est celui du dépôt : ces tests ne
/// dépendent ni d'un bundle ni de la langue de la machine.
struct LocalisationTests {

    private var dossier: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Localisation")
    }

    private func table(_ langue: Langue) throws -> [String: String] {
        try #require(Localisation.table(langue, dans: dossier), "\(langue.rawValue).json illisible")
    }

    /// Une clé qui manque à une langue s'afficherait en français ; une clé en
    /// trop est une traduction que rien n'affiche. Ni l'une ni l'autre.
    @Test("Chaque langue traduit exactement les clés du français")
    func memesCles() throws {
        let fr = Set(try table(.fr).keys)
        for langue in Langue.allCases where langue != .fr {
            let cles = Set(try table(langue).keys)
            #expect(cles.subtracting(fr).isEmpty, "\(langue.rawValue) : clés en trop \(cles.subtracting(fr).sorted())")
            #expect(fr.subtracting(cles).isEmpty, "\(langue.rawValue) : clés manquantes \(fr.subtracting(cles).sorted())")
        }
    }

    /// `String(format:)` lit ses arguments dans l'ordre : une traduction qui
    /// perd un `%@` ou change un `%lld` en `%@` plante à l'affichage.
    @Test("Les arguments de format sont les mêmes dans chaque langue")
    func memesArguments() throws {
        let fr = try table(.fr)
        for langue in Langue.allCases where langue != .fr {
            let traduction = try table(langue)
            for (cle, texte) in fr {
                #expect(Self.specificateurs(texte) == Self.specificateurs(traduction[cle] ?? ""),
                        "\(langue.rawValue) › \(cle)")
            }
        }
    }

    /// Le code ne porte que des clés ; chacune doit exister en français, et
    /// chaque clé française doit servir quelque part — sinon c'est un libellé
    /// mort, ou une faute de frappe qui s'afficherait telle quelle. Une clé
    /// accordée (`L("…", nombre:`) demande aussi sa forme `.un`, que seul
    /// cet usage fait vivre.
    @Test("Les clés du code et celles de fr.json se correspondent")
    func clesDuCode() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Synfus")
        var utilisees = Set<String>()
        let regex = try NSRegularExpression(pattern: #"\bL\("([^"]+)"(, nombre:)?"#)
        let fichiers = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        for cas in fichiers {
            guard let url = cas as? URL, url.pathExtension == "swift",
                  let contenu = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for match in regex.matches(in: contenu, range: NSRange(contenu.startIndex..., in: contenu)) {
                guard let plage = Range(match.range(at: 1), in: contenu) else { continue }
                utilisees.insert(String(contenu[plage]))
                if match.range(at: 2).location != NSNotFound { utilisees.insert(contenu[plage] + ".un") }
            }
        }
        let fr = Set(try table(.fr).keys)
        #expect(!utilisees.isEmpty)
        #expect(utilisees.subtracting(fr).isEmpty, "clés sans texte : \(utilisees.subtracting(fr).sorted())")
        #expect(fr.subtracting(utilisees).isEmpty, "textes sans usage : \(fr.subtracting(utilisees).sorted())")
    }

    @Test("Une clé absente d'une traduction revient au français, puis à la clé")
    func repli() {
        let table = Localisation(langue: .en, textes: ["a": "A"], repli: ["a": "Á", "b": "Bé"])
        #expect(table.texte("a") == "A")
        #expect(table.texte("b") == "Bé")
        #expect(table.texte("c") == "c")
    }

    /// Le français dit « 0 étape », l'anglais et l'espagnol « 0 steps ».
    @Test("Une clé accordée prend sa forme .un au singulier de chaque langue")
    func pluriel() {
        let textes = ["n": "%lld étapes", "n.un": "%lld étape"]
        let fr = Localisation(langue: .fr, textes: textes, repli: textes)
        let en = Localisation(langue: .en, textes: ["n": "%lld steps", "n.un": "%lld step"], repli: textes)
        #expect([0, 1, 2].map { fr.texte("n", nombre: $0) } == ["%lld étape", "%lld étape", "%lld étapes"])
        #expect([0, 1, 2].map { en.texte("n", nombre: $0) } == ["%lld steps", "%lld step", "%lld steps"])
        #expect(Langue.es.singulier(1) && !Langue.es.singulier(0))
    }

    @Test("Les trois tables se chargent et diffèrent")
    func chargement() {
        let en = Localisation.charger(.en, dans: dossier)
        let es = Localisation.charger(.es, dans: dossier)
        #expect(en.texte("menu.quitter") == "Quit Synfus")
        #expect(es.texte("menu.quitter") == "Salir de Synfus")
        #expect(en.repli["menu.quitter"] == "Quitter Synfus")
    }

    /// La liste des langues préférées de macOS porte des identifiants
    /// régionaux ; la première dont la langue est connue l'emporte, et un
    /// système sans aucune des trois parle français — la langue source.
    @Test("La langue suit la première préférence reconnue", arguments: [
        (["fr-FR", "en-US"], Langue.fr),
        (["en-GB", "fr-FR"], Langue.en),
        (["es-419"], Langue.es),
        (["de-DE", "es_ES"], Langue.es),
        (["de-DE", "pt-BR"], Langue.fr),
        ([], Langue.fr),
    ])
    func choix(preferees: [String], attendue: Langue) {
        #expect(Langue.choisir(parmi: preferees) == attendue)
    }

    private static func specificateurs(_ texte: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%[0-9$+.]*(?:lld|@|d|f)"#)
        return regex.matches(in: texte, range: NSRange(texte.startIndex..., in: texte))
            .compactMap { Range($0.range, in: texte).map { String(texte[$0]) } }
            .sorted()
    }
}
