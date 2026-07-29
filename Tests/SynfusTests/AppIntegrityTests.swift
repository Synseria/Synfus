import Testing
import Foundation
@testable import Synfus

/// La détection de quarantaine décide d'un avertissement que l'utilisateur ne
/// peut obtenir nulle part ailleurs : elle est vérifiée sur de vrais attributs
/// étendus, posés sur des fichiers temporaires.
struct AppIntegrityTests {

    private func withTemporaryFile(_ corps: (String) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("synfus-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        try corps(url.path)
    }

    @Test("Un fichier sans attribut n'est pas en quarantaine")
    func sansAttribut() throws {
        try withTemporaryFile { chemin in
            #expect(!AppIntegrity.isQuarantined(path: chemin))
        }
    }

    @Test("L'attribut de quarantaine est détecté")
    func avecAttribut() throws {
        try withTemporaryFile { chemin in
            let valeur = "0081;00000000;Safari;"
            let pose = valeur.withCString {
                setxattr(chemin, "com.apple.quarantine", $0, strlen($0), 0, XATTR_NOFOLLOW)
            }
            try #require(pose == 0, "impossible de poser l'attribut de test")
            #expect(AppIntegrity.isQuarantined(path: chemin))
        }
    }

    /// C'est exactement le geste que l'avertissement demande à l'utilisateur :
    /// la détection doit retomber à faux une fois l'attribut retiré.
    @Test("Retirer l'attribut lève la détection")
    func attributRetire() throws {
        try withTemporaryFile { chemin in
            let valeur = "0081;00000000;Safari;"
            _ = valeur.withCString {
                setxattr(chemin, "com.apple.quarantine", $0, strlen($0), 0, XATTR_NOFOLLOW)
            }
            #expect(AppIntegrity.isQuarantined(path: chemin))

            removexattr(chemin, "com.apple.quarantine", XATTR_NOFOLLOW)
            #expect(!AppIntegrity.isQuarantined(path: chemin))
        }
    }

    @Test("Un chemin inexistant n'est pas signalé en quarantaine")
    func cheminInexistant() {
        #expect(!AppIntegrity.isQuarantined(path: "/nexiste/pas/du/tout"))
    }

    /// La commande est copiée-collée dans un shell : un chemin à espaces sans
    /// guillemets serait lu comme deux arguments et la commande échouerait.
    @Test("La commande proposée cite le chemin de l'app")
    func commandeCopiable() {
        let commande = AppIntegrity.quarantineFix
        #expect(commande.hasPrefix("xattr -dr com.apple.quarantine "))
        let chemin = Bundle.main.bundlePath
        if chemin.contains(" ") {
            #expect(commande.contains("'\(chemin)'"))
        } else {
            #expect(commande.hasSuffix(chemin))
        }
    }

    @Test("La commande de réinitialisation vise le service Accessibilité")
    func commandeReinitialisation() {
        #expect(AppIntegrity.resetCommand.hasPrefix("tccutil reset Accessibility "))
    }
}
