import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // Accessory : pas d'icône dans le Dock, Synfus vit dans la barre de menus.
        NSApp.setActivationPolicy(.accessory)

        buildApplicationMenu()

        // Le modèle signale quand la barre et les panneaux du jeu doivent se
        // réévaluer ; il ne les connaît pas.
        WindowManager.shared.visibiliteARevoir = {
            FloatingBarController.shared.updateVisibility(force: $0)
            PanneauxJeu.revoir(force: $0)
        }
        WindowManager.shared.start()
        FreezeWatcher.shared.start()
        HotKeyManager.shared.rebind()
        MenuBarController.shared.install()
        AttentionWatcher.shared.start()
        ClickAdvanceWatcher.shared.apply()
        FloatingBarController.shared.apply()
        LecteurEcran.shared.start()
        CarteStore.shared.start()
        ClassesStore.shared.start()
        QuetesStore.shared.preparer()
        // Abonnée à la carte et aux quêtes, lues en tâche de fond : elle en
        // normalisera les textes dès leur arrivée.
        _ = PaletteModele.shared
        ZaapClipboard.shared.start()
        MiseAJour.shared.start()

        if !AXIsProcessTrusted() {
            WindowManager.shared.requestAccessibility()
            SettingsWindowController.shared.show()
        }
    }

    func applicationWillTerminate(_: Notification) {
        // La position de la barre s'écrit avec un temps de retard sur le
        // déplacement : quitter dans cet intervalle ne doit pas la perdre.
        FloatingBarController.shared.flushPendingOrigin()
        HotKeyManager.shared.unregisterAll()
    }

    /// Menu applicatif minimal : sans lui, ⌘Q et ⌘W ne fonctionneraient pas
    /// lorsque la fenêtre de réglages est au premier plan — ni ⌘C, ⌘V, ⌘A et
    /// ⌘Z dans les champs (palette, chasse, réglages) : un champ de texte ne
    /// les reçoit que par le menu Édition.
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

        let editionItem = NSMenuItem()
        let edition = NSMenu(title: L("menu.edition"))
        edition.addItem(withTitle: L("menu.annuler"), action: Selector(("undo:")), keyEquivalent: "z")
        edition.addItem(withTitle: L("menu.retablir"), action: Selector(("redo:")), keyEquivalent: "Z")
        edition.addItem(.separator())
        edition.addItem(withTitle: L("menu.couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edition.addItem(withTitle: L("menu.copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edition.addItem(withTitle: L("menu.coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edition.addItem(withTitle: L("menu.toutSelectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editionItem.submenu = edition
        mainMenu.addItem(editionItem)

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

        // Banc de la capture : --banc-captures <nom d'app ou pid> [tours]
        if let index = CommandLine.arguments.firstIndex(of: "--banc-captures"),
           index + 1 < CommandLine.arguments.count {
            let arguments = CommandLine.arguments
            let tours = index + 2 < arguments.count ? Int(arguments[index + 2]) ?? 30 : 30
            BancCaptures.runCommandLine(cible: arguments[index + 1], tours: tours)
        }

        // Relevé de la carte intégrée : --exporter-carte Resources/Carte.json
        if let index = CommandLine.arguments.firstIndex(of: "--exporter-carte"),
           index + 1 < CommandLine.arguments.count {
            CarteDofusDB.exporterLigneDeCommande(vers: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }

        let application = NSApplication.shared
        // `NSApplication.delegate` est une référence **faible** : un délégué
        // gardé dans une variable locale peut être libéré dès son dernier usage
        // une fois l'optimiseur passé, et l'app ne reçoit alors plus aucun
        // évènement de cycle de vie. Il vit donc aussi longtemps que le
        // processus.
        application.delegate = delegate
        application.run()
    }

    /// Le délégué, tenu pour la durée du processus (cf. `main`).
    @MainActor private static let delegate = AppDelegate()
}
