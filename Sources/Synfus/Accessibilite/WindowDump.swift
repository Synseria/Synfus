import AppKit
import ApplicationServices

/// Mode diagnostic en ligne de commande : `Synfus --dump-windows`.
///
/// Pendant du `--dump-dock`, et pour la même raison — l'autorisation
/// Accessibilité étant liée à l'identité de code signée, seul le binaire du
/// bundle peut lire quoi que ce soit. Il montre, pour chaque client Dofus, ce
/// que l'Accessibilité rend **et** le verdict de chacun des filtres de
/// `refresh()` : c'est le seul moyen de savoir lequel écarte une fenêtre.
@MainActor
enum WindowDump {

    /// Le relevé est aussi écrit sur disque : lancé depuis un terminal, le
    /// binaire hérite du contexte d'autorisation de ce terminal et non du sien,
    /// et se voit refuser l'Accessibilité. Passer par LaunchServices
    /// (`open -n -a Synfus --args --dump-windows`) le règle, mais la sortie
    /// standard est alors perdue — d'où ce fichier.
    static let logURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Synfus/fenetres.log")

    private static var lines: [String] = []

    private static func say(_ line: String) {
        print(line)
        lines.append(line)
    }

    private static func flush() {
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? lines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
    }

    static func runCommandLine() -> Never {
        guard AXIsProcessTrusted() else {
            say("NON_AUTORISE — accordez l'accès Accessibilité à cette app.")
            flush()
            exit(2)
        }

        let apps = DofusProcesses.running()
        say("\(apps.count) processus Dofus")

        for app in apps {
            let pid = app.processIdentifier
            say("\n=== pid \(pid) — \(app.bundleIdentifier ?? "?") ===")
            say("  actif : \(app.isActive) | masqué : \(app.isHidden)")

            let axApp = AXHandle.application(pid)

            // Un client dans un espace plein écran inactif peut être ralenti par
            // le système : sans marge, la requête expirerait avant sa réponse.
            AXUIElementSetMessagingTimeout(axApp.element, 2)

            let windows: [AXHandle]
            switch AccessibilityReader.windows(of: axApp) {
            case .windows(let list): windows = list
            case .mute: say("  kAXWindows : MUET (borne expirée)"); continue
            case .failed(let status): say("  kAXWindows : ÉCHEC (code \(status.rawValue))"); continue
            }
            say("  kAXWindows : \(windows.count) fenêtre(s)")

            for (index, window) in windows.enumerated() {
                describe(window, index: index)
            }
        }

        say("\n--- fin du relevé ---")
        flush()
        exit(0)
    }

    private static func describe(_ window: AXHandle, index: Int) {
        let facts = AccessibilityReader.windowFacts(window)
        let title = facts.title
        let subrole = facts.subrole
        let role = AccessibilityReader.stringAttribute(window, kAXRoleAttribute)
        let minimized = AccessibilityReader.boolAttribute(window, kAXMinimizedAttribute) ?? false
        let fullScreen = AccessibilityReader.boolAttribute(window, "AXFullScreen")
        let dimension = facts.size

        // Les deux filtres de `refresh()`, dans l'ordre où ils s'appliquent —
        // le même seuil qu'eux, décomposé pour dire lequel a écarté la fenêtre.
        let subroleOK = AccessibilityReader.isGameWindow(subrole: subrole, size: nil)
        let sizeOK = AccessibilityReader.isGameWindow(subrole: nil, size: dimension)
        let characterOK = WindowTitle.isCharacterWindow(title: title ?? "")

        let verdict: String
        if !subroleOK {
            verdict = "ÉCARTÉE — sous-rôle"
        } else if !sizeOK {
            verdict = "écartée — trop petite"
        } else if !characterOK {
            verdict = "écartée — titre sans perso (client au login ?)"
        } else {
            verdict = "RETENUE"
        }

        let taille = dimension.map { "\(Int($0.width))x\(Int($0.height))" } ?? "?"
        say("  [\(index)] \(role ?? "∅")/\(subrole ?? "∅") \(taille) "
              + "réduite:\(minimized) plein écran:\(fullScreen.map(String.init) ?? "n/c")")
        say("       titre « \(title ?? "∅") »")
        say("       → \(verdict)")
    }
}
