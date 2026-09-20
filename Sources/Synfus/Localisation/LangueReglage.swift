import AppKit

/// Le choix de langue de l'onglet Général — pour qui joue en français sur un
/// macOS en anglais, ou l'inverse.
///
/// Il passe par la clé `AppleLanguages` du domaine de préférences de l'app :
/// celle-là même que Réglages Système › Langue et région écrit quand on
/// choisit une langue par application. Les deux chemins se lisent donc l'un
/// l'autre, et `Locale.preferredLanguages` — ce que `L10n` consulte au
/// lancement — la reflète. `nil` : suivre le système. Le changement demande
/// de relancer, la table étant chargée une fois pour toutes.
@MainActor
enum LangueReglage {
    private static let cle = "AppleLanguages"

    /// La langue imposée à l'app, `nil` si elle suit le système.
    static var choisie: Langue? {
        get {
            guard let domaine = Bundle.main.bundleIdentifier,
                  let langues = UserDefaults.standard.persistentDomain(forName: domaine)?[cle] as? [String],
                  let premiere = langues.first
            else { return nil }
            return Langue(rawValue: premiere)
        }
        set {
            if let newValue {
                UserDefaults.standard.set([newValue.rawValue], forKey: cle)
            } else {
                UserDefaults.standard.removeObject(forKey: cle)
            }
        }
    }

    /// La langue que le prochain lancement emploiera : celle choisie, sinon
    /// celle du système.
    static var auProchainLancement: Langue {
        if let choisie { return choisie }
        let globales = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[cle] as? [String]
        return Langue.choisir(parmi: globales ?? Locale.preferredLanguages)
    }

    /// Relance Synfus : `open` sur le bundle une seconde après la sortie, le
    /// temps que le processus courant ait disparu — sinon `open` ne ferait que
    /// le remettre devant. Hors bundle (`swift run`), on se contente de quitter.
    static func relancer() {
        let chemin = Bundle.main.bundlePath
        if chemin.hasSuffix(".app") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "sleep 1; open \"$0\"", chemin]
            try? process.run()
        }
        NSApp.terminate(nil)
    }
}
