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
