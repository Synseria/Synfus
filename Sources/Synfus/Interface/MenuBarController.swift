import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    private override init() { super.init() }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = icon()

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// À appeler après un changement de `Preferences.menuBarIcon`.
    func refreshIcon() {
        statusItem?.button?.image = icon()
    }

    /// Les deux images sont *template* : macOS les teint lui-même selon le thème
    /// et les inverse quand le menu est ouvert.
    private func icon() -> NSImage? {
        switch Preferences.shared.menuBarIcon {
        case .logo:
            return SynfusGlyph.menuBarImage()
        case .symbole:
            let image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "Synfus"
            )
            image?.isTemplate = true
            return image
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let manager = WindowManager.shared
        // Le menu se construit sur ce qui est déjà connu : un inventaire à cet
        // instant retardait l'ouverture du temps d'un tour d'Accessibilité, et
        // le timer de 2 s tient la liste assez fraîche. L'inventaire est
        // simplement demandé pour la suite — avec un délai, car sans lui
        // `refreshSoon` l'exécute sur-le-champ dès que le dernier date de plus
        // de 200 ms, c'est-à-dire presque toujours.
        manager.refreshSoon(after: 0.05)
        let prefs = Preferences.shared

        if let version = MiseAJour.shared.proposee {
            if case .installation = MiseAJour.shared.etat {
                let item = NSMenuItem(title: L("maj.menu.installation", version.numero), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                add(to: menu, title: L("maj.menu.installer", version.numero), action: #selector(installUpdate))
            }
            menu.addItem(.separator())
        }

        if !manager.accessibilityGranted {
            add(to: menu, title: L("menu.autoriser"), action: #selector(requestAccess))
            menu.addItem(.separator())
        } else if manager.clients.isEmpty {
            let empty = NSMenuItem(title: L("barre.aucunPerso"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            menu.addItem(.separator())
        } else {
            // L'effectif : les numéros sont ceux de la barre, et `focus(slot:)`
            // compte de la même façon.
            for (index, client) in manager.effectif.enumerated() {
                let item = add(to: menu, title: client.name, action: #selector(focusClient(_:)),
                               raccourci: index < prefs.hotKeys.count ? prefs.hotKeys[index] : nil)
                item.tag = index
                item.image = ClassesStore.shared.menuIcon(for: client.characterClass)
                if manager.isFrontmost(client) { item.state = .on }
            }
            if manager.effectif.isEmpty {
                let empty = NSMenuItem(title: L("menu.aucunPersoEquipe"), action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
            }
            if !prefs.equipes.isEmpty { menu.addItem(teamSubmenu()) }
            menu.addItem(.separator())
        }

        // Les panneaux de jeu dans l'ordre de la barre, puis les fenêtres et
        // la barre, puis Synfus lui-même.
        add(to: menu, title: L("menu.quetes"), action: #selector(openQuests), raccourci: prefs.quetesHotKey)
        add(to: menu, title: L("menu.boss"), action: #selector(openBoss), raccourci: prefs.bossHotKey)
        add(to: menu, title: L("menu.chasse"), action: #selector(openHunt), raccourci: prefs.chasseHotKey)
        add(to: menu, title: L("menu.palette"), action: #selector(openPalette), raccourci: prefs.paletteHotKey)
        menu.addItem(.separator())

        menu.addItem(arrangeSubmenu(enabled: manager.accessibilityGranted
                                             && !manager.clients.isEmpty))
        if !manager.clients.isEmpty {
            add(to: menu, title: L("menu.lancerSession"), action: #selector(launchSession), raccourci: prefs.sessionHotKey)
        }
        add(to: menu, title: prefs.barVisible ? L("menu.masquerBarre") : L("menu.afficherBarre"), action: #selector(toggleBar))
        add(to: menu, title: L("menu.recentrerBarre"), action: #selector(recenterBar))
        menu.addItem(.separator())

        add(to: menu, title: L("menu.reglages"), action: #selector(openSettings))
        // Reconstruit à chaque ouverture : l'item n'apparaît que s'il y a
        // quelqu'un à fermer, inutile de jouer avec `isEnabled`.
        if !manager.clients.isEmpty {
            add(to: menu, title: L("menu.fermerTous"), action: #selector(closeAllClients))
        }
        add(to: menu, title: L("menu.quitter"), action: #selector(quit))
    }

    /// Sous-menu « Ranger les fenêtres » : une entrée par disposition. Le
    /// raccourci, s'il existe, est montré sur la dernière disposition employée —
    /// c'est elle qu'il rejoue.
    private func arrangeSubmenu(enabled: Bool) -> NSMenuItem {
        let parent = NSMenuItem(title: L("menu.rangerFenetres"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let prefs = Preferences.shared
        for (index, disposition) in Disposition.allCases.enumerated() {
            let item = NSMenuItem(title: disposition.label,
                                  action: enabled ? #selector(arrange(_:)) : nil,
                                  keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = NSImage(systemSymbolName: disposition.symbolName,
                                 accessibilityDescription: disposition.label)
            if let hotKey = prefs.arrangeHotKey,
               disposition == prefs.lastArrangement {
                item.attributedTitle = attributed(name: disposition.label,
                                                  shortcut: hotKey.displayString)
            }
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        for (titre, action) in [(L("rangement.toutPleinEcran"), #selector(fullscreenAll)),
                                (L("rangement.toutSortirPleinEcran"), #selector(unfullscreenAll))] {
            let item = NSMenuItem(title: titre, action: enabled ? action : nil,
                                  keyEquivalent: "")
            item.target = self
            submenu.addItem(item)
        }
        parent.submenu = submenu
        parent.isEnabled = enabled
        return parent
    }

    /// Sous-menu « Équipe » : « Tous » puis chaque équipe avec ses membres.
    /// Le tag vaut l'index + 1, 0 pour « Tous ».
    private func teamSubmenu() -> NSMenuItem {
        let manager = WindowManager.shared
        let prefs = Preferences.shared
        let parent = NSMenuItem(title: L("equipes.equipe"), action: nil, keyEquivalent: "")
        if let hotKey = prefs.equipeSuivanteHotKey {
            parent.attributedTitle = attributed(name: L("equipes.equipe"), shortcut: hotKey.displayString)
        }
        let submenu = NSMenu()
        let tous = NSMenuItem(title: L("equipes.tous"), action: #selector(selectTeam(_:)), keyEquivalent: "")
        tous.target = self
        tous.tag = 0
        if manager.equipeActive == nil { tous.state = .on }
        submenu.addItem(tous)
        for (index, equipe) in prefs.equipes.enumerated() {
            let item = NSMenuItem(title: L("equipes.equipeMembres", index + 1, equipe.membres.joined(separator: ", ")),
                                  action: #selector(selectTeam(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index + 1
            if manager.equipeActive == index { item.state = .on }
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    /// Le raccourci, global (Carbon), est montré à titre indicatif : un key
    /// equivalent de menu ne marcherait que Synfus au premier plan.
    @discardableResult
    private func add(to menu: NSMenu, title: String, action: Selector, raccourci: HotKey? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let raccourci { item.attributedTitle = attributed(name: title, shortcut: raccourci.displayString) }
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
        UsageStore.shared.compter(.basculeMenu)
        WindowManager.shared.focus(slot: sender.tag)
    }

    @objc private func selectTeam(_ sender: NSMenuItem) {
        WindowManager.shared.activerEquipe(sender.tag == 0 ? nil : sender.tag - 1)
    }

    @objc private func arrange(_ sender: NSMenuItem) {
        Task { await WindowArranger.shared.appliquer(Disposition.allCases[sender.tag]) }
    }

    @objc private func closeAllClients() {
        ConfirmationFermeture.fermerTous()
    }

    @objc private func fullscreenAll() {
        Task { await WindowArranger.shared.toutEnPleinEcran() }
    }

    @objc private func unfullscreenAll() {
        Task { await WindowArranger.shared.toutSortirDuPleinEcran() }
    }

    @objc private func launchSession() {
        WindowManager.shared.lancerSession()
    }

    @objc private func toggleBar() {
        FloatingBarController.shared.toggle()
    }

    @objc private func recenterBar() {
        FloatingBarController.shared.recenter()
    }

    @objc private func openQuests() {
        QuetePanel.shared.ouvrir()
    }

    @objc private func openHunt() {
        ChassePanel.shared.ouvrir()
    }

    @objc private func openBoss() {
        BossPanel.shared.ouvrir()
    }

    @objc private func openPalette() {
        PalettePanel.shared.ouvrir()
    }

    @objc private func installUpdate() {
        MiseAJour.shared.proposer()
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
