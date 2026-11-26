import Foundation
import MiseAJour
@testable import Synfus
import SynseriaDesign
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

    @Test("L'état se traduit pour la ligne commune : une version trouvée est prête à installer")
    func pourLaLigne() throws {
        let version = try #require(Self.lire())
        #expect(SuiviDeMiseAJour.Etat.repos.pourLaLigne == .repos)
        #expect(SuiviDeMiseAJour.Etat.aJour.pourLaLigne == .aJour)
        #expect(SuiviDeMiseAJour.Etat.disponible(version).pourLaLigne == .prete(version: "0.11.0", notes: "Notes"))
        #expect(SuiviDeMiseAJour.Etat.telechargement(version).pourLaLigne == .telechargement(version: "0.11.0"))
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
        #expect(SuiviDeMiseAJour.Etat.incompatible(version).pourLaLigne == .echec(L("maj.incompatible", "0.11.0", "26")))
        #expect(SuiviDeMiseAJour.Etat.echec(.ecriture("refus"), version).pourLaLigne == .echec(L("maj.echec.ecriture")))
        #expect(SuiviDeMiseAJour.Etat.echec(.reseau, nil).pourLaLigne == .echec(L("maj.echec.reseau")))
    }

    /// Les deux dernières releases telles que l'API les donnait au passage au canal : la 0.14.0, au nom
    /// d'avant le macOS minimum, ne se propose pas sur Stable ; la rc de la 0.15 se propose sur Bêta.
    @Test("Les releases publiées se lisent sur chaque canal")
    func releasesPubliees() throws {
        let liste = #"[{"tag_name": "v0.15.0-rc.1", "html_url": "https://github.com/Synseria/Synfus/releases/tag/v0.15.0-rc.1", "prerelease": true, "draft": false, "body": "…", "assets": [{"name": "SHA256SUMS.txt", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.15.0-rc.1/SHA256SUMS.txt"}, {"name": "Synfus-0.15.0-rc.1-dSYM.zip", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.15.0-rc.1/Synfus-0.15.0-rc.1-dSYM.zip"}, {"name": "Synfus-0.15.0-rc.1-macos26-arm64.dmg", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.15.0-rc.1/Synfus-0.15.0-rc.1-macos26-arm64.dmg"}, {"name": "Synfus-0.15.0-rc.1-macos26-x86_64.dmg", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.15.0-rc.1/Synfus-0.15.0-rc.1-macos26-x86_64.dmg"}]}, {"tag_name": "v0.14.0", "html_url": "https://github.com/Synseria/Synfus/releases/tag/v0.14.0", "prerelease": false, "draft": false, "body": "…", "assets": [{"name": "SHA256SUMS.txt", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.14.0/SHA256SUMS.txt"}, {"name": "Synfus-0.14.0-arm64.dmg", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.14.0/Synfus-0.14.0-arm64.dmg"}, {"name": "Synfus-0.14.0-dSYM.zip", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.14.0/Synfus-0.14.0-dSYM.zip"}, {"name": "Synfus-0.14.0-x86_64.dmg", "browser_download_url": "https://github.com/Synseria/Synfus/releases/download/v0.14.0/Synfus-0.14.0-x86_64.dmg"}]}]"#
        #expect(Self.lire(liste, canal: .stable) == nil)
        let beta = try #require(Self.lire(liste, canal: .beta))
        #expect(beta.numero.texte == "0.15.0-rc.1" && beta.macOSMinimum == "26")
        #expect(ReleasesDeSynfus.image(de: beta, architecture: "arm64")?.nom == "Synfus-0.15.0-rc.1-macos26-arm64.dmg")
    }
}
