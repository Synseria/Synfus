import CryptoKit
import Foundation
import Testing
@testable import Synfus

/// Les couleurs viennent des jetons du design system : le fichier engendré n'est jamais
/// retouché à la main, la couleur de l'app se relit, et « Autre… » refuse le safran.
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

    @Test("« Autre… » refuse une teinte proche du safran")
    func autreRefuseLeSafran() {
        for proche in [84, 56, 70, 113] { #expect(!Jetons.teinteAcceptee(proche), "\(proche)") }
        for loin in [0, 38, 54, 114, 150, 350] { #expect(Jetons.teinteAcceptee(loin), "\(loin)") }
        #expect(Jetons.Couleur(ecrit: "teinte:90") == nil)
        #expect(Jetons.Couleur(ecrit: "teinte:200") == .teinte(200))
    }

    @Test("« Autre… » refuse aussi la teinte que l'app réserve à ses suggestions")
    func autreRefuseLaSuggestion() {
        for proche in [293, 270, 316] { #expect(!Jetons.teinteAcceptee(proche), "\(proche)") }
        #expect(Jetons.Couleur(ecrit: "teinte:293") == nil)
    }

    @Test("La teinte d'une couleur : celle du préréglage, ou la sienne ramenée au cercle")
    func teinteDeLaCouleur() {
        for prereglage in Jetons.Prereglage.allCases {
            #expect(Jetons.Couleur.prereglage(prereglage).degres == prereglage.teinte)
        }
        #expect(Jetons.Couleur.teinte(210).degres == 210)
        #expect(Jetons.Couleur.teinte(-10).degres == 350)
    }

    @Test("La couleur et les fonds se relisent")
    func persistance() {
        let store = MemoireDeTest()
        let prefs = Preferences.forTesting(store: store)
        prefs.couleurDeLApp = .teinte(210)
        prefs.fondsDeLApp = .teinte(30)
        let relu = Preferences.forTesting(store: store)
        #expect(relu.couleurDeLApp == .teinte(210) && relu.fondsDeLApp == .teinte(30))
        prefs.couleurDeLApp = .prereglage(.corail)
        prefs.fondsDeLApp = .neutre
        let encore = Preferences.forTesting(store: store)
        #expect(encore.couleurDeLApp == .prereglage(.corail) && encore.fondsDeLApp == .neutre)
    }

    @Test("Le défaut est le jade, et les fonds sont en Auto : primaire en clair, nuit en sombre")
    func defauts() {
        let prefs = Preferences.forTesting(store: MemoireDeTest())
        #expect(prefs.couleurDeLApp == .prereglage(.jade))
        #expect(prefs.fondsDeLApp == nil)
        #expect(Jetons.fondsParDefaut(.clair) == .primaire && Jetons.fondsParDefaut(.sombre) == .nuit)
        #expect(Jetons.theme(.prereglage(.jade), fonds: nil, .sombre) == Jetons.theme(.prereglage(.jade), fonds: .nuit, .sombre))
        #expect(Jetons.theme(.prereglage(.jade), fonds: nil, .clair) == Jetons.theme(.prereglage(.jade), fonds: .primaire, .clair))
    }

    @Test("Revenir à Auto efface le choix des fonds de la sauvegarde")
    func retourALAuto() {
        let store = MemoireDeTest()
        let prefs = Preferences.forTesting(store: store)
        prefs.fondsDeLApp = .neutre
        prefs.fondsDeLApp = nil
        #expect(Preferences.forTesting(store: store).fondsDeLApp == nil)
    }

    @Test("Une ancienne sauvegarde en violet retombe sur le défaut sans perdre le reste")
    func violetRetire() {
        let store = MemoireDeTest()
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"couleurDeLApp":"violet","fondsDeLApp":"nuit"}"#.utf8),
                          pour: Preferences.key)
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["A"])
        #expect(prefs.couleurDeLApp == Jetons.couleurParDefaut && prefs.fondsDeLApp == .nuit)
    }

    @Test("Une valeur illisible laisse les défauts sans rendre la sauvegarde illisible")
    func valeurIllisible() {
        let store = MemoireDeTest()
        store.enregistrer(Data(#"{"characterOrder":["A"],"hotKeys":[],"barVisible":true,"showNumbers":true,"couleurDeLApp":"nimporte","fondsDeLApp":"teinte:x"}"#.utf8),
                          pour: Preferences.key)
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["A"])
        #expect(prefs.couleurDeLApp == Jetons.couleurParDefaut && prefs.fondsDeLApp == nil)
    }

    @Test("Le thème courant lit les jetons du réglage courant")
    func facade() {
        let prefs = Preferences.shared
        let avant = (prefs.couleurDeLApp, prefs.fondsDeLApp)
        defer { (prefs.couleurDeLApp, prefs.fondsDeLApp) = avant }
        prefs.couleurDeLApp = .prereglage(.azur)
        prefs.fondsDeLApp = .nuit
        for apparence in Jetons.apparences {
            #expect(ThemeCourant.theme(apparence) == Jetons.theme(.prereglage(.azur), fonds: .nuit, apparence))
        }
        prefs.couleurDeLApp = .prereglage(.corail)
        #expect(ThemeCourant.theme(.clair).primaire == Jetons.theme(.prereglage(.corail), fonds: .nuit, .clair).primaire)
    }

    @Test("Chaque préréglage garde ses textes lisibles, en clair et en sombre")
    func contrastes() {
        for prereglage in Jetons.Prereglage.allCases {
            for apparence in Jetons.apparences {
                let theme = Jetons.theme(.prereglage(prereglage), apparence)
                #expect(contraste(theme.encreSurPrimaire, theme.primaire) >= 4.5, "\(prereglage) \(apparence) : texte sur plein")
                #expect(contraste(theme.primaireEncre, theme.fenetre) >= 4.5, "\(prereglage) \(apparence) : couleur écrite")
                #expect(contraste(theme.encreSurDanger, theme.dangerPlein) >= 4.5, "\(prereglage) \(apparence) : texte sur destructif")
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
