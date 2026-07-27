import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    private override init() { super.init() }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.3.group",
            accessibilityDescription: "Synfus"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let manager = WindowManager.shared
        manager.refresh()

        if !manager.accessibilityGranted {
            add(to: menu, title: "Autoriser Synfus…", action: #selector(requestAccess))
            menu.addItem(.separator())
        } else if manager.clients.isEmpty {
            let empty = NSMenuItem(title: "Aucun perso connecté", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            menu.addItem(.separator())
        } else {
            let prefs = Preferences.shared
            for (index, client) in manager.clients.enumerated() {
                let item = add(to: menu, title: client.name, action: #selector(focusClient(_:)))
                item.tag = index
                item.image = ClassIconStore.shared.menuIcon(for: client.characterClass)
                if manager.isFrontmost(client) { item.state = .on }

                // Le raccourci est affiché à titre indicatif seulement : le vrai
                // enregistrement est global (Carbon), pas un key equivalent de menu
                // qui ne fonctionnerait que lorsque Synfus est au premier plan.
                if index < prefs.hotKeys.count, let hotKey = prefs.hotKeys[index] {
                    item.attributedTitle = attributed(name: client.name, shortcut: hotKey.displayString)
                }
            }
            menu.addItem(.separator())
        }

        let barTitle = Preferences.shared.barVisible ? "Masquer la barre" : "Afficher la barre"
        add(to: menu, title: barTitle, action: #selector(toggleBar))
        add(to: menu, title: "Recentrer la barre", action: #selector(recenterBar))
        add(to: menu, title: "Réglages…", action: #selector(openSettings))
        menu.addItem(.separator())
        add(to: menu, title: "Quitter Synfus", action: #selector(quit))
    }

    @discardableResult
    private func add(to menu: NSMenu, title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func attributed(name: String, shortcut: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: name,
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        )
        result.append(NSAttributedString(
            string: "   \(shortcut)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        return result
    }

    // MARK: - Actions

    @objc private func focusClient(_ sender: NSMenuItem) {
        WindowManager.shared.focus(slot: sender.tag)
    }

    @objc private func toggleBar() {
        FloatingBarController.shared.toggle()
    }

    @objc private func recenterBar() {
        FloatingBarController.shared.recenter()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    /// Exposé au menu applicatif (⌘,), qui vit en dehors de ce contrôleur.
    @objc func openSettingsFromMenu() {
        SettingsWindowController.shared.show()
    }

    @objc private func requestAccess() {
        WindowManager.shared.requestAccessibility()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
