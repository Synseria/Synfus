import AppKit
import CoreGraphics
import Foundation
import Network

/// L'état du plugin : les touches présentes sur le Stream Deck, l'état reçu de
/// Synfus, et les deux liaisons. Tout sur le main actor — c'est un petit
/// programme, un seul fil suffit.
@MainActor
final class Plugin {
    static let shared = Plugin()

    /// Une touche visible sur l'appareil.
    struct Key {
        let context: String
        let action: String
        let device: String
        let column: Int
        let row: Int
    }

    private var keys: [String: Key] = [:]
    private var state: DeckState?
    private var elgato: ElgatoSocket?
    private var synfus: SynfusSocket?
    /// Appareils sur lesquels on a basculé vers le profil Synfus — pour en
    /// revenir quand Dofus n'est plus devant.
    private var switchedDevices: Set<String> = []
    private var devices: Set<String> = []
    /// « Menu » enfoncé : les touches de sorts montrent les commandes du jeu.
    private var menuOpen = false

    private static let socketPath = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/streamdeck.sock").path

    func start(port: Int, pluginUUID: String, registerEvent: String, info: String?) async {
        if let info, let data = info.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["devices"] as? [[String: Any]] {
            for device in list { if let id = device["id"] as? String { devices.insert(id) } }
            Log.write("appareils : \(list)")
        }
        let elgato = ElgatoSocket(port: port) { [weak self] event in self?.handle(event) }
        self.elgato = elgato
        await elgato.connect(registerEvent: registerEvent, uuid: pluginUUID)

        let synfus = SynfusSocket(path: Self.socketPath) { [weak self] state in
            self?.apply(state)
        } onDisconnect: { [weak self] in
            self?.apply(nil)
        }
        self.synfus = synfus
        synfus.connect()
    }

    // MARK: - Évènements Stream Deck

    private func handle(_ event: StreamDeckEvent) {
        switch event.event {
        case "deviceDidConnect":
            if let device = event.device { devices.insert(device) }
        case "deviceDidDisconnect":
            if let device = event.device { devices.remove(device); switchedDevices.remove(device) }
        default: break
        }
        guard let context = event.context, let action = event.action else { return }
        switch event.event {
        case "willAppear":
            let c = event.payload?.coordinates
            keys[context] = Key(context: context, action: action, device: event.device ?? "",
                                column: c?.column ?? 0, row: c?.row ?? 0)
            render()
        case "willDisappear":
            keys[context] = nil
        case "keyDown":
            press(context)
        default:
            break
        }
    }

    /// Les touches « sort », dans l'ordre de lecture (ligne puis colonne) :
    /// la première est la case 1, la suivante la case 2… Aucune configuration :
    /// la disposition physique dit tout.
    private var sortKeys: [Key] {
        keys.values.filter { $0.action == ActionID.sort }.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    private func press(_ context: String) {
        guard let key = keys[context] else { return }
        // Sans Synfus, n'importe quelle touche le lance : c'est ce qu'on veut
        // quand « Synfus absent » s'affiche.
        guard let state else { launchSynfus(); return }
        // Dofus derrière une autre app : une touche ne frappe rien, elle
        // ramène Dofus devant — la suivante fera ce qu'elle dit.
        if !state.dofusDevant, key.action != ActionID.persoSuivant, key.action != ActionID.persoPrecedent {
            send("activer")
            return
        }
        switch key.action {
        case ActionID.menu:
            menuOpen.toggle()
            render()
        case ActionID.sort:
            guard let index = sortKeys.firstIndex(where: { $0.context == context }) else { return }
            if menuOpen {
                guard index < state.commandes.count, let touche = state.commandes[index].touche
                else { elgato?.showAlert(context); return }
                Keystroke.press(touche)
                return
            }
            guard index < state.cases.count, let touche = state.cases[index].touche
            else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.suivi:
            guard let touche = state.commandes.first(where: { $0.id == "suivi" })?.touche
            else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.finDeTour:
            guard state.dofusDevant, let touche = state.finDeTour else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.corpsACorps:
            guard state.dofusDevant, let touche = state.corpsACorps else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.persoSuivant: send("persoSuivant")
        case ActionID.persoPrecedent: send("persoPrecedent")
        case ActionID.barreSuivante: send("barreSuivante")
        case ActionID.persoActif: send("barreSuivante")
        default: break
        }
    }

    private func send(_ type: String) {
        guard let synfus, synfus.isConnected else { launchSynfus(); return }
        synfus.send(DeckCommand(type: type, slot: nil))
    }

    private func launchSynfus() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Synfus.app"),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Affichage

    private func apply(_ new: DeckState?) {
        let wasFront = state?.dofusDevant == true
        state = new
        render()
        // Le profil Synfus suit Dofus : on y bascule quand il passe devant, on
        // rend la main quand il n'y est plus — le logiciel Stream Deck revient
        // alors au profil d'avant.
        let isFront = new?.dofusDevant == true
        if isFront, !wasFront {
            for device in devices where !switchedDevices.contains(device) {
                elgato?.switchToProfile(device: device, profile: BundledProfile.name)
                switchedDevices.insert(device)
            }
        } else if !isFront, wasFront {
            for device in switchedDevices { elgato?.switchToProfile(device: device, profile: nil) }
            switchedDevices.removeAll()
        }
    }

    /// Redessine toutes les touches d'après l'état courant. Sans Synfus, les
    /// touches le disent ; Dofus derrière une autre app, les icônes restent
    /// mais s'assombrissent — on voit toujours où on en est.
    private func render() {
        guard let elgato else { return }
        let sorts = sortKeys
        let dimmed = state?.dofusDevant != true
        for key in keys.values {
            switch key.action {
            case ActionID.sort where menuOpen && state != nil:
                let index = sorts.firstIndex { $0.context == key.context } ?? 0
                if let command = state.flatMap({ index < $0.commandes.count ? $0.commandes[index] : nil }) {
                    elgato.setImage(key.context, base64PNG: Images.symbol(command.symbole, dimmed: dimmed || command.touche == nil))
                    elgato.setTitle(key.context, command.nom)
                } else {
                    elgato.setImage(key.context, base64PNG: Images.blank(dimmed: true))
                    elgato.setTitle(key.context, "")
                }
            case ActionID.menu:
                elgato.setImage(key.context, base64PNG: Images.symbol(menuOpen ? "xmark" : "square.grid.2x2", dimmed: dimmed))
                elgato.setTitle(key.context, menuOpen ? "Sorts" : "Menu")
            case ActionID.suivi:
                let ready = state?.commandes.contains { $0.id == "suivi" && $0.touche != nil } == true
                elgato.setImage(key.context, base64PNG: Images.symbol("figure.walk", dimmed: dimmed || !ready))
                elgato.setTitle(key.context, "Suivi")
            case ActionID.sort:
                let index = sorts.firstIndex { $0.context == key.context } ?? 0
                let cell = state.flatMap { index < $0.cases.count ? $0.cases[index] : nil }
                if let cell, let icone = cell.icone {
                    elgato.setImage(key.context, base64PNG: dimmed ? Images.dimmed(icone) : icone)
                    elgato.setTitle(key.context, cell.nom ?? "")
                } else {
                    elgato.setImage(key.context, base64PNG: Images.blank(dimmed: dimmed))
                    elgato.setTitle(key.context, state == nil ? "Synfus\nabsent" : (cell?.nom ?? "\(index + 1)"))
                }
            case ActionID.persoSuivant, ActionID.persoPrecedent, ActionID.persoActif:
                let perso = key.action == ActionID.persoSuivant ? state?.persoSuivant
                    : key.action == ActionID.persoPrecedent ? state?.persoPrecedent : state?.persoActif
                if let perso {
                    let icon = perso.icone.map { dimmed ? Images.dimmed($0) : $0 }
                    elgato.setImage(key.context, base64PNG: icon ?? Images.blank(dimmed: dimmed))
                    let arrow = key.action == ActionID.persoSuivant ? "▶ " : key.action == ActionID.persoPrecedent ? "◀ " : ""
                    elgato.setTitle(key.context, arrow + perso.nom)
                } else {
                    elgato.setImage(key.context, base64PNG: Images.blank(dimmed: dimmed))
                    elgato.setTitle(key.context, state == nil ? "Synfus\nabsent" : (state?.perso == nil ? "Aucun\nperso" : "—"))
                }
            case ActionID.barreSuivante:
                elgato.setImage(key.context, base64PNG: Images.symbol("arrow.turn.down.right", dimmed: dimmed))
                elgato.setTitle(key.context, state.map { "Barre \($0.barre)/\($0.barres)" } ?? "Synfus\nabsent")
            case ActionID.finDeTour:
                // En combat, la touche s'allume ; hors combat (ou sans verdict), elle reste discrète.
                let armed = state?.finDeTour != nil && state?.enCombat != false
                elgato.setImage(key.context, base64PNG: Images.symbol("flag.checkered", dimmed: dimmed || !armed))
                elgato.setTitle(key.context, state?.finDeTour == nil ? "Fin de tour\n(à régler)" : "Fin de tour")
            case ActionID.corpsACorps:
                elgato.setImage(key.context, base64PNG: Images.symbol("figure.fencing", dimmed: dimmed || state?.corpsACorps == nil))
                elgato.setTitle(key.context, state?.corpsACorps == nil ? "CàC\n(à régler)" : "Corps à corps")
            default:
                break
            }
        }
    }
}

/// Un journal minimal dans ~/Library/Logs/Synfus/synfusdeck.log — le plugin
/// n'a pas de fenêtre, c'est le seul endroit où il peut dire ce qu'il voit.
enum Log {
    static let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appending(path: "Logs/Synfus/synfusdeck.log")

    static func write(_ message: String) {
        let line = "\(Date().formatted(date: .abbreviated, time: .standard))  \(message)\n"
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

/// La frappe elle-même — le seul endroit du projet qui émet un évènement
/// clavier, et il est hors de Synfus. Les modificateurs sont **pressés** comme
/// des touches, pas seulement posés en drapeau sur l'évènement : le client
/// Unity lit l'état des touches, et ⌃1 en drapeau seul jouait le sort de la
/// touche 1 nue. Appui puis relâchement, dans l'ordre inverse ; rien n'est
/// retenu ni répété.
enum Keystroke {
    private static let modifierKeys: [(mask: UInt32, code: CGKeyCode, flag: CGEventFlags)] = [
        (1 << 12, 59, .maskControl),   // controlKey → kVK_Control
        (1 << 11, 58, .maskAlternate), // optionKey → kVK_Option
        (1 << 9, 56, .maskShift),      // shiftKey → kVK_Shift
        (1 << 8, 55, .maskCommand),    // cmdKey → kVK_Command
    ]

    static func press(_ key: DeckKey) {
        let held = modifierKeys.filter { key.modifiers & $0.mask != 0 }
        var flags: CGEventFlags = []
        for modifier in held {
            flags.insert(modifier.flag)
            post(modifier.code, down: true, flags: flags)
        }
        post(CGKeyCode(key.keyCode), down: true, flags: flags)
        usleep(12_000)
        post(CGKeyCode(key.keyCode), down: false, flags: flags)
        for modifier in held.reversed() {
            flags.remove(modifier.flag)
            post(modifier.code, down: false, flags: flags)
        }
    }

    private static func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        usleep(4_000)
    }
}

/// Les images des touches : la vignette assombrie quand Dofus n'est pas
/// devant, et une touche vide sobre — plutôt que le logo partout.
@MainActor
enum Images {
    private static var dimCache: [String: String] = [:]

    static func dimmed(_ base64PNG: String) -> String {
        if let cached = dimCache[base64PNG] { return cached }
        guard let data = Data(base64Encoded: base64PNG), let image = NSImage(data: data) else { return base64PNG }
        let size = NSSize(width: 144, height: 144)
        let out = NSImage(size: size, flipped: false) { rect in
            NSColor(white: 0.08, alpha: 1).setFill()
            rect.fill()
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.55)
            return true
        }
        let result = png(out) ?? base64PNG
        dimCache[base64PNG] = result
        return result
    }

    static func blank(dimmed: Bool) -> String {
        let size = NSSize(width: 144, height: 144)
        let out = NSImage(size: size, flipped: false) { rect in
            NSColor(white: dimmed ? 0.08 : 0.16, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 6, dy: 6), xRadius: 18, yRadius: 18).fill()
            return true
        }
        return png(out) ?? ""
    }

    private static var symbolCache: [String: String] = [:]

    /// Un symbole SF, blanc sur fond sombre — les touches de commande.
    static func symbol(_ name: String, dimmed: Bool) -> String {
        let key = "\(name)/\(dimmed)"
        if let cached = symbolCache[key] { return cached }
        let size = NSSize(width: 144, height: 144)
        // Le glyphe est teinté à part, sur fond transparent — `sourceAtop`
        // ne peint que là où il y a déjà du dessin —, puis posé sur le fond.
        let glyph: NSImage? = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 60, weight: .regular))
            .map { symbol in
                NSImage(size: symbol.size, flipped: false) { rect in
                    symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                    NSColor.white.setFill()
                    rect.fill(using: .sourceAtop)
                    return true
                }
            }
        let out = NSImage(size: size, flipped: false) { rect in
            NSColor(white: dimmed ? 0.08 : 0.16, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 6, dy: 6), xRadius: 18, yRadius: 18).fill()
            if let glyph {
                let target = NSRect(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2 + 10,
                                    width: glyph.size.width, height: glyph.size.height)
                glyph.draw(in: target, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.35 : 0.95)
            }
            return true
        }
        let result = png(out) ?? ""
        symbolCache[key] = result
        return result
    }

    private static func png(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { return nil }
        return data.base64EncodedString()
    }
}
