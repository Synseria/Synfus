import Foundation
import MiseAJour
@testable import Synfus
import Testing

@Suite("Mise à jour : release GitHub, version, empreinte")
struct MiseAJourTests {
    private static let reponse = """
    [{"tag_name":"v0.11.0","html_url":"https://github.com/Synseria/Synfus/releases/tag/v0.11.0","prerelease":false,"body":"Notes",
     "assets":[
      {"name":"SHA256SUMS.txt","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/SHA256SUMS.txt"},
      {"name":"Synfus-0.11.0-macos26-arm64.dmg","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/Synfus-0.11.0-macos26-arm64.dmg"},
      {"name":"Synfus-0.11.0-macos26-x86_64.dmg","browser_download_url":"https://github.com/Synseria/Synfus/releases/download/v0.11.0/Synfus-0.11.0-macos26-x86_64.dmg"}]}]
    """

    private static func lire(_ texte: String = reponse, canal: CanalDeMiseAJour = .stable, architecture: String = "arm64") -> ReleasePubliee? {
        ReleasesDeSynfus.lire(Data(texte.utf8), canal: canal, architecture: architecture)
    }

    @Test("La ligne de version dit de quand date la réponse de GitHub, ou seulement l'état")
    func resume() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let hier = maintenant.addingTimeInterval(-86_400)
        func texte(_ etat: SuiviDeMiseAJour.Etat, _ date: Date?) -> String? {
            MiseAJour.resume(version: "1.4.2", etat: etat, verifiee: date, maintenant: maintenant, calendrier: calendrier)
        }
        #expect(texte(.aJour, maintenant) == "v1.4.2 · " + L("maj.etat.aJourVerifiee", L("maj.quand.aujourdhui")))
        #expect(texte(.aJour, hier) == "v1.4.2 · " + L("maj.etat.aJourVerifiee", L("maj.quand.hier")))
        #expect(texte(.aJour, nil) == "v1.4.2 · " + L("maj.aJour"))
        #expect(texte(.repos, maintenant) == "v1.4.2 · " + L("maj.etat.verifiee", L("maj.quand.aujourdhui")))
        #expect(texte(.repos, nil) == "v1.4.2")
        #expect(texte(.recherche, maintenant) == L("maj.verification"))
        #expect(MiseAJour.resume(version: nil, etat: .repos, verifiee: nil) == nil)
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
        #expect(ReleasesDeSynfus.page(de: "1.4.2").absoluteString == "https://github.com/Synseria/Synfus/releases/tag/v1.4.2")
    }

    @Test("La release se lit avec le DMG de l'architecture et les empreintes")
    func lecture() throws {
        let version = try #require(Self.lire(architecture: "x86_64"))
        #expect(version.numero.texte == "0.11.0")
        #expect(version.notes == "Notes")
        #expect(version.macOSMinimum == "26")
        #expect(version.page?.absoluteString.hasSuffix("/tag/v0.11.0") == true)
        let image = try #require(ReleasesDeSynfus.image(de: version, architecture: "x86_64"))
        #expect(image.nom == "Synfus-0.11.0-macos26-x86_64.dmg")
        #expect(image.adresse.lastPathComponent == "Synfus-0.11.0-macos26-x86_64.dmg")
        #expect(version.fichiers.contains { $0.nom == ReleasesDeSynfus.empreintes })
    }

    @Test("Une release sans le DMG de ce Mac, ou illisible, ne se propose pas")
    func incomplete() {
        #expect(Self.lire(architecture: "riscv") == nil)
        #expect(Self.lire(Self.reponse.replacingOccurrences(of: "SHA256SUMS.txt", with: "x")) == nil)
        #expect(Self.lire("{}") == nil)
        #expect(Self.lire("[]") == nil)
        #expect(Self.lire(Self.reponse.replacingOccurrences(of: "v0.11.0\",\"html", with: "nightly\",\"html")) == nil)
    }

    @Test("Une release au nom d'avant, sans macOS minimum, ne se lit pas : rien ne dirait si ce Mac l'ouvre")
    func nomSansMinimum() {
        let ancienne = Self.reponse.replacingOccurrences(of: "-macos26-", with: "-")
        #expect(Self.lire(ancienne) == nil)
        for illisible in ["-macos-", "-macosX-", "-macos0-", "-macos26.a-"] {
            #expect(Self.lire(Self.reponse.replacingOccurrences(of: "-macos26-", with: illisible)) == nil, "\(illisible)")
        }
        let fine = Self.reponse.replacingOccurrences(of: "-macos26-", with: "-macos26.2-")
        #expect(Self.lire(fine)?.macOSMinimum == "26.2")
    }

    /// Stable ne voit pas une préversion ; Bêta prend la plus haute, et une rc incomplète ne se propose pas.
    @Test("Le canal choisit la release dans la liste")
    func canal() throws {
        let rc = Self.reponse
            .replacingOccurrences(of: "0.11.0", with: "0.12.0-rc.1")
            .replacingOccurrences(of: "\"prerelease\":false", with: "\"prerelease\":true")
            .dropFirst().dropLast()
        let liste = "[" + rc + "," + Self.reponse.dropFirst()
        #expect(Self.lire(liste, canal: .stable)?.numero.texte == "0.11.0")
        let beta = try #require(Self.lire(liste, canal: .beta))
        #expect(beta.numero.texte == "0.12.0-rc.1")
        #expect(beta.preliminaire)
        #expect(Self.lire(liste.replacingOccurrences(of: "Synfus-0.12.0-rc.1-macos26-arm64", with: "x"), canal: .beta) == nil)
    }

    @Test("Une version pour un macOS plus récent se dit avec le macOS qu'elle exige")
    func incompatible() throws {
        let version = try #require(Self.lire())
        #expect(SuiviDeMiseAJour.Etat.incompatible(version).libelle == L("maj.incompatible", "0.11.0", "26"))
        #expect(SuiviDeMiseAJour.Etat.echec(.ecriture("refus"), version).libelle == L("maj.echec.ecriture"))
        #expect(SuiviDeMiseAJour.Etat.echec(.reseau, nil).libelle == L("maj.echec.reseau"))
    }
}
