import Foundation
@testable import Synfus
import Testing

@Suite("Mise à jour : release GitHub, version, empreinte")
struct MiseAJourTests {
    private static let reponse = """
    {"tag_name":"v0.11.0","html_url":"https://github.com/Synseria/Synfus/releases/tag/v0.11.0","draft":false,
     "assets":[
      {"name":"SHA256SUMS.txt","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/SHA256SUMS.txt"},
      {"name":"Synfus-0.11.0-arm64.dmg","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/Synfus-0.11.0-arm64.dmg"},
      {"name":"Synfus-0.11.0-x86_64.dmg","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/Synfus-0.11.0-x86_64.dmg"}]}
    """

    @Test("La ligne de version dit de quand date la réponse de GitHub, ou seulement l'état")
    func resume() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let hier = maintenant.addingTimeInterval(-86_400)
        func texte(_ etat: MiseAJour.Etat, _ date: Date?) -> String? {
            MiseAJour.resume(version: "1.4.2", etat: etat, verifiee: date, maintenant: maintenant, calendrier: calendrier)
        }
        #expect(texte(.aJour, maintenant) == "v1.4.2 · " + L("maj.etat.aJourVerifiee", L("maj.quand.aujourdhui")))
        #expect(texte(.aJour, hier) == "v1.4.2 · " + L("maj.etat.aJourVerifiee", L("maj.quand.hier")))
        #expect(texte(.aJour, nil) == "v1.4.2 · " + L("maj.aJour"))
        #expect(texte(.inconnu, maintenant) == "v1.4.2 · " + L("maj.etat.verifiee", L("maj.quand.aujourdhui")))
        #expect(texte(.inconnu, nil) == "v1.4.2")
        #expect(texte(.verification, maintenant) == L("maj.verification"))
        #expect(MiseAJour.resume(version: nil, etat: .inconnu, verifiee: nil) == nil)
        #expect(MiseAJour.quand(maintenant.addingTimeInterval(-5 * 86_400), maintenant, calendrier)
                == L("maj.quand.le", maintenant.addingTimeInterval(-5 * 86_400).formatted(.dateTime.day().month(.abbreviated))))
    }

    @Test("Une version n'est annoncée par notification qu'une fois")
    func annonceUnique() {
        #expect(NotificationMiseAJour.aAnnoncer("1.5.0", derniere: nil))
        #expect(NotificationMiseAJour.aAnnoncer("1.5.0", derniere: "1.4.0"))
        #expect(!NotificationMiseAJour.aAnnoncer("1.5.0", derniere: "1.5.0"))
    }

    @Test("La page des nouveautés de la version installée se déduit de son numéro")
    func pageDeLaVersionInstallee() {
        #expect(VersionPubliee.page(de: "1.4.2").absoluteString == "https://github.com/Synseria/Synfus/releases/tag/v1.4.2")
    }

    @Test("La release se lit avec le DMG de l'architecture et les empreintes")
    func lecture() throws {
        let version = try #require(VersionPubliee.lire(Data(Self.reponse.utf8), architecture: "x86_64"))
        #expect(version.numero == "0.11.0")
        #expect(version.nomImage == "Synfus-0.11.0-x86_64.dmg")
        #expect(version.image.lastPathComponent == "Synfus-0.11.0-x86_64.dmg")
        #expect(version.empreintes.lastPathComponent == "SHA256SUMS.txt")
        #expect(version.page.absoluteString.hasSuffix("/tag/v0.11.0"))
    }

    @Test("Une release sans le DMG de ce Mac, ou illisible, ne se propose pas")
    func incomplete() {
        #expect(VersionPubliee.lire(Data(Self.reponse.utf8), architecture: "riscv") == nil)
        #expect(VersionPubliee.lire(Data(Self.reponse.replacingOccurrences(of: "SHA256SUMS.txt", with: "x").utf8),
                                    architecture: "arm64") == nil)
        #expect(VersionPubliee.lire(Data("{}".utf8), architecture: "arm64") == nil)
        #expect(VersionPubliee.lire(Data(Self.reponse.replacingOccurrences(of: "v0.11.0\",\"html", with: "nightly\",\"html").utf8),
                                    architecture: "arm64") == nil)
    }

    @Test("Les versions se comparent nombre par nombre")
    func comparaison() throws {
        let version = try #require(VersionPubliee.lire(Data(Self.reponse.utf8), architecture: "arm64"))
        #expect(version.plusRecente(que: "0.9.0"))
        #expect(version.plusRecente(que: "0.10.1"))
        #expect(!version.plusRecente(que: "0.11.0"))
        #expect(!version.plusRecente(que: "0.12.0"))
        #expect(!version.plusRecente(que: "1.0"))
        #expect(!version.plusRecente(que: nil))
        #expect(!version.plusRecente(que: "dev"))
        #expect(NumeroVersion("v1.2.3-beta") == NumeroVersion("1.2.3"))
        #expect(NumeroVersion("1.2") == NumeroVersion("1.2.0"))
    }

    @Test("L'empreinte se lit dans SHA256SUMS.txt, au nom exact")
    func empreinte() {
        let a = String(repeating: "A", count: 64)
        let b = String(repeating: "b", count: 64)
        let sommes = "\(a)  Synfus-0.11.0-arm64.dmg\n\(b)  Synfus-0.11.0-x86_64.dmg\n"
        #expect(VersionPubliee.empreinte(de: "Synfus-0.11.0-arm64.dmg", dans: sommes) == a.lowercased())
        #expect(VersionPubliee.empreinte(de: "Synfus-0.11.0-x86_64.dmg", dans: sommes) == b)
        #expect(VersionPubliee.empreinte(de: "Synfus-0.11.0.dmg", dans: sommes) == nil)
        #expect(VersionPubliee.empreinte(de: "x.dmg", dans: "123  x.dmg") == nil)
    }
}

@Suite("Mise à jour : après une mise à jour, version simulée")
struct ApresMiseAJourTests {
    @Test("Une autre version que la fois d'avant, ou une sauvegarde qui ne la connaît pas : mise à jour")
    func apresMiseAJour() {
        #expect(MiseAJour.apresMiseAJour(derniere: "0.11.0", courante: "0.12.0", premierLancement: false))
        #expect(MiseAJour.apresMiseAJour(derniere: nil, courante: "0.12.0", premierLancement: false))
        #expect(!MiseAJour.apresMiseAJour(derniere: "0.12.0", courante: "0.12.0", premierLancement: false))
        #expect(!MiseAJour.apresMiseAJour(derniere: nil, courante: "0.12.0", premierLancement: true))
        #expect(!MiseAJour.apresMiseAJour(derniere: "0.11.0", courante: nil, premierLancement: false))
    }

    @Test("--simuler-version remplace la version comparée")
    func simulation() {
        #expect(MiseAJour.versionSimulee(["Synfus", "--simuler-version", "0.0.1"]) == "0.0.1")
        #expect(MiseAJour.versionSimulee(["Synfus", "--simuler-version"]) == nil)
        #expect(MiseAJour.versionSimulee(["Synfus"]) == nil)
    }
}
