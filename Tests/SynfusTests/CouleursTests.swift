import CryptoKit
import Foundation
import Testing
@testable import Synfus
import SynseriaDesign

/// Les couleurs viennent du nuancier du design system (paquet SynseriaKit) : ce que Synfus en garde
/// n'est jamais retouché à la main, le thème se relit, les réglages d'avant se convertissent une fois.
@MainActor
struct CouleursTests {
    /// L'en-tête de `JetonsPropres.swift` porte l'empreinte de ce qui suit ses deux premières lignes
    /// (SHA-256, 16 premiers caractères hexadécimaux) : une retouche à la main la rompt.
    @Test("JetonsPropres.swift est tel que Synseria-Design l'a engendré")
    func empreinteDuFichierEngendre() throws {
        let url = SourcesDuDepot.fichiers().first { $0.lastPathComponent == "JetonsPropres.swift" }
        let texte = try String(contentsOf: try #require(url), encoding: .utf8)
        let lignes = texte.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        try #require(lignes.count == 3)
        let annoncee = try #require(lignes[1].split(separator: " ").last).description
        let reelle = SHA256.hash(data: Data(lignes[2].utf8)).map { String(format: "%02x", $0) }.joined().prefix(16)
        #expect(annoncee == String(reelle), "JetonsPropres.swift a été retouché : le régénérer par sh propager.sh")
    }

    @Test("Le thème se relit d'un bloc ; un thème illisible laisse le défaut sans perdre le reste")
    func persistance() {
        let store = StockageEnMemoire()
        let prefs = Preferences.forTesting(store: store)
        var theme = Jetons.Theme(teinte: 37, fond: .teinte(204), suivreLeSysteme: false, clarte: 640)
        prefs.themeDeLApp = theme
        #expect(Preferences.forTesting(store: store).themeDeLApp == theme)
        theme.suivreLeSysteme = true
        theme.poserClarte(120, systemeSombre: false)
        prefs.themeDeLApp = theme
        #expect(Preferences.forTesting(store: store).themeDeLApp == theme)
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"theme":"nimporte","themeDeLApp":"cerise"}"#.utf8),
                          pour: Preferences.key)
        let illisible = Preferences.forTesting(store: store)
        #expect(illisible.characterOrder == ["A"])
        #expect(illisible.themeDeLApp == Jetons.themeParDefaut)
    }

    @Test("Le défaut est celui de la fiche, l'app suivant macOS")
    func defauts() {
        let prefs = Preferences.forTesting(store: StockageEnMemoire())
        #expect(prefs.themeDeLApp == Jetons.themeParDefaut)
        #expect(prefs.themeDeLApp.suivreLeSysteme)
    }

    @Test("Avec le système, macOS décide ; une clarté fixée impose son apparence")
    func apparenceImposee() {
        #expect(ThemeCourant.apparence(Jetons.Theme()) == nil)
        for cran in Jetons.CranDeClarte.allCases {
            let theme = Jetons.Theme(suivreLeSysteme: false, clarte: cran.position)
            #expect(ThemeCourant.apparence(theme)?.name == ([.penombre, .nuit].contains(cran) ? .darkAqua : .aqua), "\(cran)")
        }
    }

    /// Les noms qu'écrivait le thème d'avant le continu (coloris, fonds nommés, nuances) : chacun a sa
    /// place dans la table de migration du SDS, sinon il retomberait en silence sur le défaut.
    @Test("Chaque coloris, fond et nuance d'avant a son équivalent")
    func tablesDeMigration() {
        let coloris = ["cerise", "terracotta", "abricot", "ambre", "miel", "sauge", "lagon", "bleuet", "lilas", "prune", "graphite"]
        let fonds = ["ardoise", "lagune", "sable", "brique", "graphite"]
        let nuances = ["jour", "crepuscule", "penombre", "nuit"]
        typealias M = Jetons.Parametres.Migration
        for nom in coloris { #expect(M.themes[nom] != nil, "\(nom)") }
        for nom in fonds { #expect(M.fonds[nom] != nil, "\(nom)") }
        for nom in nuances { #expect(M.nuances[nom] != nil, "\(nom)") }
        for nom in ConversionDuTheme.colorisDuPrereglage.values { #expect(M.themes[nom] != nil, "\(nom)") }
    }

    @Test("Le thème d'avant le continu : coloris ou Personnalisé, fond, nuance, Système")
    func conversionDuNuancier() {
        typealias A = ConversionDuTheme.Ancien
        let sauge = ConversionDuTheme.relire(A(theme: "sauge", nuance: "nuit", fond: "brique"))
        #expect(sauge.teinte == 154 && sauge.fond == .teinte(34))
        #expect(!sauge.suivreLeSysteme && sauge.clarte == Jetons.CranDeClarte.nuit.position)
        let systeme = ConversionDuTheme.relire(A(theme: "lagon", nuance: "systeme"))
        #expect(systeme.teinte == 185 && systeme.fond == .accorde && systeme.suivreLeSysteme)
        // Absente, la nuance était celle du système.
        #expect(ConversionDuTheme.relire(A(theme: "lagon")).suivreLeSysteme)
        let personnalise = ConversionDuTheme.relire(A(theme: "personnalise:3FA9D8", nuance: "systeme", fond: "#3F7A80"))
        #expect(personnalise == Jetons.Nuancier.migrer(coloris: nil, personnalise: 0x3FA9D8, nuance: nil, fond: "#3F7A80"))
        #expect(personnalise.teinte != Jetons.themeParDefaut.teinte)
        // Illisible : la couleur d'alors, pas celle d'aujourd'hui.
        #expect(ConversionDuTheme.relire(A(theme: "nimporte")).teinte == 185)
    }

    @Test("Une sauvegarde d'avant le nuancier : chaque préréglage → son coloris, jade → Lagon ; Clair et Sombre → Jour et Pénombre")
    func conversionDesPrereglages() {
        typealias A = ConversionDuTheme.Ancien
        let teinte = { (couleur: String) in ConversionDuTheme.relire(A(couleurDeLApp: couleur)).teinte }
        #expect(teinte("jade") == 185 && teinte("azur") == 254 && teinte("framboise") == 17)
        #expect(teinte("corail") == 36 && teinte("ardoise") == 256 && teinte("violet") == 185)
        #expect(ConversionDuTheme.relire(A(apparence: "clair")).clarte == Jetons.CranDeClarte.jour.position)
        let sombre = ConversionDuTheme.relire(A(couleurDeLApp: "jade", apparence: "sombre"))
        #expect(!sombre.suivreLeSysteme && sombre.clarte == Jetons.CranDeClarte.penombre.position)
        #expect(ConversionDuTheme.relire(A(apparence: "auto")).suivreLeSysteme)
    }

    /// `teinte:N` était déjà un angle OKLCH, l'unité de la teinte d'aujourd'hui.
    @Test("« teinte:N » garde son angle")
    func conversionDUneTeinte() {
        #expect(ConversionDuTheme.relire(.init(couleurDeLApp: "teinte:240")).teinte == 240)
        #expect(ConversionDuTheme.relire(.init(couleurDeLApp: "teinte:-30", apparence: "sombre")).teinte == 330)
    }

    @Test("Une sauvegarde d'avant se convertit à la lecture sans perdre le reste, puis s'écrit au nouveau format")
    func conversionALaLecture() throws {
        let store = StockageEnMemoire()
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"themeDeLApp":"terracotta","nuanceDeLApp":"penombre","fondDeLApp":"lagune"}"#.utf8),
                          pour: Preferences.key)
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["A"])
        #expect(prefs.themeDeLApp.teinte == 36 && prefs.themeDeLApp.fond == .teinte(204) && !prefs.themeDeLApp.suivreLeSysteme)
        prefs.themeDeLApp.teinte = 40
        let ecrit = try #require(store.donnees(pour: Preferences.key))
        let json = try #require(try JSONSerialization.jsonObject(with: ecrit) as? [String: Any])
        #expect(json["theme"] != nil && json["themeDeLApp"] == nil && json["nuanceDeLApp"] == nil && json["fondDeLApp"] == nil)
        #expect(Preferences.forTesting(store: store).themeDeLApp.teinte == 40)
    }

    @Test("Le thème courant lit le réglage courant ; ce qui se pose sur une carte s'écrit en Nuit")
    func facade() {
        let prefs = Preferences.shared
        let avant = prefs.themeDeLApp
        defer { prefs.themeDeLApp = avant }
        prefs.themeDeLApp = Jetons.Theme(teinte: 120)
        #expect(ThemeCourant.theme == Jetons.Theme(teinte: 120))
        #expect(ThemeCourant.couleurs(ThemeCourant.theme, systemeSombre: true)
            == Jetons.Nuancier.couleurs(Jetons.Theme(teinte: 120), systemeSombre: true))
        let nuit = ThemeCourant.theme(en: .nuit)
        #expect(nuit.teinte == 120 && nuit.sombreImpose == true)
    }

    @Test("Le continu garde ses textes lisibles, sur un échantillon de teintes et de clartés")
    func contrastes() {
        for teinte in stride(from: 0, to: 360, by: 30) {
            for cran in Jetons.CranDeClarte.allCases {
                let c = Jetons.Nuancier.couleurs(Jetons.Theme(teinte: teinte, suivreLeSysteme: false, clarte: cran.position), systemeSombre: false)
                #expect(contraste(c.texteSurAccent, c.accent) >= 4.5, "\(teinte) \(cran) : texte sur plein")
                #expect(contraste(c.accentTexte, c.fondFenetre) >= 4.5, "\(teinte) \(cran) : couleur écrite")
                #expect(contraste(c.texteSurDanger, c.danger) >= 4.5, "\(teinte) \(cran) : texte sur destructif")
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
