// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu dce09d0174d40237
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
        let parent = installee.deletingLastPathComponent().path
        guard installee.pathExtension == "app", FileManager.default.isWritableFile(atPath: parent),
              FileManager.default.isWritableFile(atPath: installee.path)
        else {
            throw EchecDeMiseAJour.ecriture(CocoaError(.fileWriteNoPermission).localizedDescription)
        }
        do {
            _ = try FileManager.default.replaceItemAt(installee, withItemAt: nouvelle)
        } catch {
            throw EchecDeMiseAJour.ecriture(error.localizedDescription)
        }
    }
}
