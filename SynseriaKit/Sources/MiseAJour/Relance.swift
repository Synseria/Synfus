// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 25f4236349ad81d5 · contenu 02f3b5c5283ab0c0
// Poser une app à la place de celle qui tourne, et relancer l'app.

import AppKit

/// Relancer l'app : une mise à jour posée, ou une autorisation (« Enregistrement de l'écran ») qui ne
/// prend qu'au lancement suivant. Un shell détaché attend la fin de ce processus avant de rouvrir
/// l'app : ouverte avant, la nouvelle tournerait à côté de l'ancienne, dont les raccourcis globaux,
/// encore pris, ne s'enregistreraient pas.
@MainActor
public enum Relance {
    public static func relancer() {
        do {
            try attente(de: ProcessInfo.processInfo.processIdentifier, puisOuvrir: Bundle.main.bundleURL.path).run()
        } catch {
            NSSound.beep()
            return
        }
        NSApp.terminate(nil)
    }

    /// Après une pose : le shell d'attente part d'abord, puis `preparatif` (ce que la nouvelle version
    /// demande), qui s'exécute même si le shell n'a pas pu partir — l'app est déjà remplacée. Sans
    /// shell, rien ne quitte : l'erreur le dit, l'app tourne encore.
    static func relancer(apres preparatif: () async -> Void) async throws {
        let shell = Result { try attente(de: ProcessInfo.processInfo.processIdentifier, puisOuvrir: Bundle.main.bundleURL.path).run() }
        await preparatif()
        if case .failure(let erreur) = shell { throw EchecDeMiseAJour.autre(erreur.localizedDescription) }
        NSApp.terminate(nil)
    }

    /// Le shell qui attend la fin de `pid` puis lance `ouvreur chemin`. Les valeurs passent en
    /// arguments, jamais dans le script : un chemin à espaces ou à guillemets reste entier.
    public nonisolated static func attente(de pid: Int32, puisOuvrir chemin: String, ouvreur: String = "/usr/bin/open") -> Process {
        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/bin/sh")
        processus.arguments = ["-c", #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; exec "$3" "$2""#,
                               "relance", String(pid), chemin, ouvreur]
        return processus
    }
}

/// La pose d'une app prête à la place de l'installée.
public enum PoseDeMiseAJour {
    /// Remplace `installee` par `nouvelle`. L'échange est atomique (l'ancienne reste entière s'il
    /// échoue), et macOS garde ouverts les fichiers de l'app qui tourne encore. Seul un paquet `.app`
    /// se remplace : un binaire nu (`swift run`) a pour `bundleURL` son dossier de build.
    public static func remplacer(_ installee: URL, par nouvelle: URL) throws {
        try verifierEcriture(installee)
        do {
            _ = try FileManager.default.replaceItemAt(installee, withItemAt: nouvelle)
        } catch {
            throw EchecDeMiseAJour.ecriture(error.localizedDescription)
        }
    }

    /// Lève `ecriture` si `installee` ne se remplacerait pas : vérifié aussi avant de télécharger,
    /// pour ne pas préparer une version qu'on ne pourra pas poser.
    static func verifierEcriture(_ installee: URL) throws {
        let parent = installee.deletingLastPathComponent().path
        guard installee.pathExtension == "app", FileManager.default.isWritableFile(atPath: parent),
              FileManager.default.isWritableFile(atPath: installee.path)
        else {
            throw EchecDeMiseAJour.ecriture(CocoaError(.fileWriteNoPermission).localizedDescription)
        }
    }
}
