import CryptoKit
import Foundation
import Testing
@testable import Synfus

/// Les couleurs viennent du nuancier du design system : les fichiers engendrés ne sont jamais
/// retouchés à la main, le thème et la nuance se relisent, les réglages d'avant se convertissent.
@MainActor
struct CouleursTests {
    /// L'en-tête de `Jetons.swift` porte l'empreinte de ce qui suit ses deux premières lignes
    /// (SHA-256, 16 premiers caractères hexadécimaux) : une retouche à la main la rompt.
    @Test("Jetons.swift est tel que Synseria-Design l'a engendré")
    func empreinteDuFichierEngendre() throws {
        let url = SourcesDuDepot.fichiers().first { $0.lastPathComponent == "Jetons.swift" }
        let texte = try String(contentsOf: try #require(url), encoding: .utf8)
        let lignes = texte.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        try #require(lignes.count == 3)
        let annoncee = try #require(lignes[1].split(separator: " ").last).description
        let reelle = SHA256.hash(data: Data(lignes[2].utf8)).map { String(format: "%02x", $0) }.joined().prefix(16)
        #expect(annoncee == String(reelle), "Jetons.swift a été retouché : le régénérer par sh propager.sh")
    }

    /// La copie de SynseriaKit porte le même en-tête, dans ses trois premières lignes
    /// (`swift-tools-version` garde la première du manifeste) : l'empreinte couvre ce qui le suit.
    @Test("SynseriaKit/ est tel que Synseria-Design l'a copié")
    func empreinteDeLaCopieDuKit() throws {
        let kit = SourcesDuDepot.dossier.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SynseriaKit")
        let fichiers = (FileManager.default.enumerator(at: kit, includingPropertiesForKeys: [.isRegularFileKey],
                                                          options: .skipsHiddenFiles)?
            .compactMap { $0 as? URL } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        #expect(fichiers.contains { $0.lastPathComponent == "Package.swift" })
        for url in fichiers {
            let lignes = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            let k = try #require(lignes.prefix(3).firstIndex { $0.contains(" · contenu ") }, "\(url.lastPathComponent) sans en-tête")
            let annoncee = try #require(lignes[k].split(separator: " ").last).description
            let corps = lignes[(k + 1)...].joined(separator: "\n")
            let reelle = SHA256.hash(data: Data(corps.utf8)).map { String(format: "%02x", $0) }.joined().prefix(16)
            #expect(annoncee == String(reelle), "\(url.lastPathComponent) a été retouché : le recopier par sh propager.sh")
        }
    }

    @Test("La trousse est telle que Synseria-Design l'a engendrée")
    func empreinteDeLaTrousse() throws {
        let trousse = SourcesDuDepot.fichiers().filter { $0.deletingLastPathComponent().lastPathComponent == "Trousse" }
        #expect(!trousse.isEmpty)
        for url in trousse {
            let lignes = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
            try #require(lignes.count == 3)
            let annoncee = try #require(lignes[1].split(separator: " ").last).description
            let reelle = SHA256.hash(data: Data(lignes[2].utf8)).map { String(format: "%02x", $0) }.joined().prefix(16)
            #expect(annoncee == String(reelle), "\(url.lastPathComponent) a été retouché : le régénérer par sh propager.sh")
        }
    }

    @Test("Le thème s'écrit et se relit, Personnalisé compris ; une valeur illisible n'est pas un choix")
    func texteDuTheme() {
        for theme in Jetons.Coloris.allCases.map(Jetons.Theme.coloris) + [.personnalise(0x3FA9D8), .personnalise(0x00000A)] {
            #expect(Jetons.Theme(ecrit: theme.ecrit) == theme)
        }
        #expect(Jetons.Theme.personnalise(0x0E766C).ecrit == "personnalise:0E766C")
        #expect(Jetons.Theme(ecrit: "jade") == nil)
        #expect(Jetons.Theme(ecrit: "personnalise:FFFFFFF") == nil)
    }

    @Test("Le thème et la nuance se relisent ; Système s'écrit, et une nuance illisible laisse le défaut")
    func persistance() {
        let store = MemoireDeTest()
        let prefs = Preferences.forTesting(store: store)
        prefs.themeDeLApp = .personnalise(0x3FA9D8)
        prefs.nuanceDeLApp = .crepuscule
        let relu = Preferences.forTesting(store: store)
        #expect(relu.themeDeLApp == .personnalise(0x3FA9D8) && relu.nuanceDeLApp == .crepuscule)
        prefs.themeDeLApp = .coloris(.sauge)
        prefs.nuanceDeLApp = nil
        let encore = Preferences.forTesting(store: store)
        #expect(encore.themeDeLApp == .coloris(.sauge) && encore.nuanceDeLApp == nil)
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"themeDeLApp":"nimporte","nuanceDeLApp":"aube"}"#.utf8),
                          pour: Preferences.key)
        let illisible = Preferences.forTesting(store: store)
        #expect(illisible.characterOrder == ["A"])
        #expect(illisible.themeDeLApp == Jetons.themeParDefaut && illisible.nuanceDeLApp == Jetons.nuanceParDefaut)
    }

    @Test("Le défaut est Graphite, l'app suivant macOS")
    func defauts() {
        let prefs = Preferences.forTesting(store: MemoireDeTest())
        #expect(prefs.themeDeLApp == .coloris(.graphite))
        #expect(prefs.nuanceDeLApp == nil)
    }

    @Test("Sans nuance, macOS décide ; une nuance impose son apparence")
    func apparenceImposee() {
        #expect(ThemeCourant.apparence(nil) == nil)
        #expect(ThemeCourant.apparence(.jour)?.name == .aqua)
        #expect(ThemeCourant.apparence(.crepuscule)?.name == .aqua)
        #expect(ThemeCourant.apparence(.penombre)?.name == .darkAqua)
        #expect(ThemeCourant.apparence(.nuit)?.name == .darkAqua)
    }

    @Test("Une sauvegarde d'avant le nuancier : jade resté au défaut → Graphite, un préréglage → son coloris")
    func conversionDesPrereglages() {
        #expect(ConversionDuTheme.relire(couleur: nil, fonds: nil, apparence: nil) == .init())
        #expect(ConversionDuTheme.relire(couleur: "jade", fonds: nil, apparence: nil).theme == .coloris(.graphite))
        #expect(ConversionDuTheme.relire(couleur: "jade", fonds: "neutre", apparence: nil).theme == .coloris(.lagon))
        #expect(ConversionDuTheme.relire(couleur: "azur", fonds: nil, apparence: nil).theme == .coloris(.bleuet))
        #expect(ConversionDuTheme.relire(couleur: "framboise", fonds: "nuit", apparence: nil).theme == .coloris(.cerise))
        #expect(ConversionDuTheme.relire(couleur: "corail", fonds: nil, apparence: nil).theme == .coloris(.terracotta))
        #expect(ConversionDuTheme.relire(couleur: "ardoise", fonds: nil, apparence: nil).theme == .coloris(.graphite))
        #expect(ConversionDuTheme.relire(couleur: "violet", fonds: nil, apparence: nil).theme == Jetons.themeParDefaut)
    }

    @Test("Clair et Sombre imposés deviennent Jour et Pénombre ; Auto suit macOS")
    func conversionDeLApparence() {
        #expect(ConversionDuTheme.relire(couleur: nil, fonds: nil, apparence: "clair").nuance == .jour)
        #expect(ConversionDuTheme.relire(couleur: "jade", fonds: nil, apparence: "sombre").nuance == .penombre)
        #expect(ConversionDuTheme.relire(couleur: nil, fonds: nil, apparence: "auto").nuance == nil)
    }

    /// `teinte:N` était un angle OKLCH : relu en TSL, un bleu-vert de 240 tournerait à l'indigo.
    @Test("« teinte:N » devient Personnalisé à l'angle OKLCH N, pas à la teinte TSL N")
    func conversionDUneTeinte() throws {
        let relu = ConversionDuTheme.relire(couleur: "teinte:240", fonds: nil, apparence: nil)
        guard case .personnalise(let couleur) = relu.theme else { Issue.record("pas Personnalisé"); return }
        let lab = Jetons.Oklab.lab(Jetons.Octets(couleur), nil)
        let angle = (atan2(lab[2], lab[1]) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        #expect(abs(angle - 240) < 3, "\(angle)")
        #expect(abs(ConversionDuTheme.teinte(couleur) - 240) > 10)
    }

    @Test("Une sauvegarde d'avant se convertit à la lecture sans perdre le reste, puis s'écrit au nouveau format")
    func conversionALaLecture() {
        let store = MemoireDeTest()
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"couleurDeLApp":"corail","fondsDeLApp":"nuit","apparence":"sombre"}"#.utf8),
                          pour: Preferences.key)
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["A"])
        #expect(prefs.themeDeLApp == .coloris(.terracotta) && prefs.nuanceDeLApp == .penombre)
        prefs.nuanceDeLApp = .nuit
        let relu = Preferences.forTesting(store: store)
        #expect(relu.themeDeLApp == .coloris(.terracotta) && relu.nuanceDeLApp == .nuit)
    }

    @Test("La teinte de Personnalisé suit le curseur, au degré près")
    func teinteDePersonnalise() {
        for teinte in [0, 37, 180, 293, 359] {
            #expect(ConversionDuTheme.teinte(ConversionDuTheme.aLaTeinte(Jetons.personnaliseParDefaut, teinte)) == teinte)
        }
    }

    @Test("Le thème courant lit les couleurs du réglage courant")
    func facade() {
        let prefs = Preferences.shared
        let avant = (prefs.themeDeLApp, prefs.nuanceDeLApp)
        defer { (prefs.themeDeLApp, prefs.nuanceDeLApp) = avant }
        prefs.themeDeLApp = .coloris(.lagon)
        prefs.nuanceDeLApp = .crepuscule
        #expect(ThemeCourant.reglage == ThemeCourant.Reglage(theme: .coloris(.lagon), nuance: .crepuscule))
        #expect(ThemeCourant.couleurs(.coloris(.lagon), .crepuscule) == Jetons.Nuancier.couleurs(.coloris(.lagon), .crepuscule))
        prefs.nuanceDeLApp = nil
        #expect(ThemeCourant.reglage.nuance(sombre: true) == .penombre && ThemeCourant.reglage.nuance(sombre: false) == .jour)
    }

    @Test("Chaque coloris garde ses textes lisibles, dans chaque nuance")
    func contrastes() {
        for coloris in Jetons.Coloris.allCases {
            for nuance in Jetons.Nuance.allCases {
                let c = Jetons.Nuancier.couleurs(.coloris(coloris), nuance)
                #expect(contraste(c.texteSurAccent, c.accent) >= 4.5, "\(coloris) \(nuance) : texte sur plein")
                #expect(contraste(c.accentTexte, c.fondFenetre) >= 4.5, "\(coloris) \(nuance) : couleur écrite")
                #expect(contraste(c.texteSurDanger, c.danger) >= 4.5, "\(coloris) \(nuance) : texte sur destructif")
            }
        }
    }

    private func luminance(_ rvb: Jetons.RVB) -> Double {
        func canal(_ octet: UInt32) -> Double {
            let v = Double(octet) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal(rvb.hex >> 16 & 0xff) + 0.7152 * canal(rvb.hex >> 8 & 0xff) + 0.0722 * canal(rvb.hex & 0xff)
    }

    private func contraste(_ a: Jetons.RVB, _ b: Jetons.RVB) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

/// Stockage en mémoire : aucun test ne touche au disque ni aux réglages de la machine.
private final class MemoireDeTest: PreferencesStore {
    private var contenu: [String: Data] = [:]
    func donnees(pour cle: String) -> Data? { contenu[cle] }
    func enregistrer(_ donnees: Data, pour cle: String) { contenu[cle] = donnees }
}
