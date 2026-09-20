import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory : pas d'icône dans le Dock, Synfus vit dans la barre de menus.
        NSApp.setActivationPolicy(.accessory)

        buildApplicationMenu()

        WindowManager.shared.start()
        HotKeyManager.shared.rebind()
        MenuBarController.shared.install()
        AttentionWatcher.shared.start()
        ClickAdvanceWatcher.shared.apply()
        FloatingBarController.shared.apply()
        StreamDeckLink.shared.start()
        CombatWatcher.shared.start()

        if !AXIsProcessTrusted() {
            WindowManager.shared.requestAccessibility()
            SettingsWindowController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // La position de la barre s'écrit avec un temps de retard sur le
        // déplacement : quitter dans cet intervalle ne doit pas la perdre.
        FloatingBarController.shared.flushPendingOrigin()
        HotKeyManager.shared.unregisterAll()
        StreamDeckLink.shared.stop()
    }

    /// Menu applicatif minimal : sans lui, ⌘Q et ⌘W ne fonctionneraient pas
    /// lorsque la fenêtre de réglages est au premier plan.
    private func buildApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = appMenu.addItem(
            withTitle: L("menu.reglages"),
            action: #selector(MenuBarController.openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = MenuBarController.shared
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.masquerSynfus"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L("menu.quitter"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: L("menu.fenetre"))
        windowMenu.addItem(withTitle: L("menu.fermer"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

/// Point d'entrée. On passe par `@main` plutôt que par du code top-level dans
/// un `main.swift` : ce dernier n'est pas isolé au main actor, alors que tout
/// AppKit l'exige.
@main
enum SynfusMain {
    @MainActor
    static func main() {
        // Mode diagnostic : --dump-dock [filtre] [secondes]
        if let index = CommandLine.arguments.firstIndex(of: "--dump-dock") {
            let arguments = CommandLine.arguments
            let filter = index + 1 < arguments.count ? arguments[index + 1] : ""
            let seconds = index + 2 < arguments.count ? Double(arguments[index + 2]) ?? 0 : 0
            DockInspector.runCommandLine(filter: filter, seconds: seconds)
        }

        // Mode diagnostic : --dump-windows
        if CommandLine.arguments.contains("--dump-windows") {
            WindowDump.runCommandLine()
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
