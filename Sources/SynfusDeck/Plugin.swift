import AppKit
import CoreGraphics
import Foundation
import Network

/// Le plugin est un **terminal** : Synfus compose les pages, une par taille de
/// grille ; ici on rend chaque touche et, à l'appui, on frappe la touche du
/// jeu qu'elle porte ou on renvoie la commande qu'elle nomme. Aucune
/// disposition n'est décidée de ce côté. Tout sur le main actor — c'est un
/// petit programme, un seul fil suffit.
@MainActor
final class Plugin {
    static let shared = Plugin()

    /// Une touche visible sur l'appareil.
    struct Key {
        let context: String
        let device: String
        let column: Int
        let row: Int
    }

    struct Grid: Hashable { let columns: Int; let rows: Int }

    private var keys: [String: Key] = [:]
    /// Les pages reçues, par grille.
    private var pages: [Grid: DeckPage] = [:]
    private var connected = false
    private var elgato: ElgatoSocket?
    private var synfus: SynfusSocket?
    /// Appareils sur lesquels on a basculé vers le profil Synfus — pour en
    /// revenir quand Dofus n'est plus devant.
    private var switchedDevices: Set<String> = []
    /// Les appareils et leur grille ; 5 × 3 quand le logiciel ne la dit pas.
    private var devices: [String: Grid] = [:]
    /// Appuis en cours : la tâche qui attend l'échéance de l'appui long, et
    /// si elle a déjà joué.
    private var holds: [String: Task<Void, Never>] = [:]
    private var longFired: Set<String> = []

    private static let socketPath = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/streamdeck.sock").path

    func start(port: Int, pluginUUID: String, registerEvent: String, info: String?) async {
        if let info, let data = info.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["devices"] as? [[String: Any]] {
            for device in list {
                guard let id = device["id"] as? String else { continue }
                let size = device["size"] as? [String: Any]
                devices[id] = Grid(columns: size?["columns"] as? Int ?? 5, rows: size?["rows"] as? Int ?? 3)
            }
            Log.write("appareils : \(list)")
        }
        let elgato = ElgatoSocket(port: port) { [weak self] event in self?.handle(event) }
        self.elgato = elgato
        await elgato.connect(registerEvent: registerEvent, uuid: pluginUUID)

        let synfus = SynfusSocket(path: Self.socketPath) { [weak self] page in
            self?.apply(page)
        } onDisconnect: { [weak self] in
            self?.disconnected()
        }
        synfus.onConnect = { [weak self] in self?.announceDevices() }
        self.synfus = synfus
        synfus.connect()
    }

    // MARK: - Évènements Stream Deck

    private func handle(_ event: StreamDeckEvent) {
        switch event.event {
        case "deviceDidConnect":
            if let device = event.device {
                let size = event.deviceInfo?.size
                devices[device] = Grid(columns: size?.columns ?? 5, rows: size?.rows ?? 3)
                announceDevices()
            }
        case "deviceDidDisconnect":
            if let device = event.device { devices[device] = nil; switchedDevices.remove(device) }
        default: break
        }
        guard let context = event.context else { return }
        switch event.event {
        case "willAppear":
            let c = event.payload?.coordinates
            keys[context] = Key(context: context, device: event.device ?? "", column: c?.column ?? 0, row: c?.row ?? 0)
            render(context)
        case "willDisappear":
            keys[context] = nil
        case "keyDown":
            keyDown(context)
        case "keyUp":
            keyUp(context)
        default:
            break
        }
    }

    /// Synfus compose une page par grille : il faut qu'il les connaisse.
    private func announceDevices() {
        guard let synfus, synfus.isConnected else { return }
        for grid in Set(devices.values) {
            synfus.send(DeckCommand(type: "appareil", colonnes: grid.columns, lignes: grid.rows))
        }
    }

    private func grid(of key: Key) -> Grid { devices[key.device] ?? Grid(columns: 5, rows: 3) }

    /// La touche telle que Synfus l'a composée pour cette position.
    private func touche(_ key: Key) -> DeckTouche? {
        let grid = grid(of: key)
        guard let page = pages[grid] else { return nil }
        let index = key.row * grid.columns + key.column
        return page.touches.first { $0.index == index }
    }

    // MARK: - Appuis

    /// Appui court = au relâchement ; maintenu jusqu'à l'échéance = action
    /// longue, et le relâchement ne fait plus rien. Une touche sans action
    /// longue joue à l'enfoncement, sans attendre.
    private func keyDown(_ context: String) {
        guard let key = keys[context] else { return }
        flash(context)
        // Sans Synfus, n'importe quelle touche le lance : c'est ce qu'on veut
        // quand « Synfus absent » s'affiche.
        guard connected, let touche = touche(key) else { launchSynfus(); return }
        guard let long = touche.long else { perform(touche.court, context: context); return }
        longFired.remove(context)
        let delay = pages[grid(of: key)]?.appuiLongMs ?? 350
        holds[context] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.holds[context] = nil
            self.longFired.insert(context)
            self.perform(long, context: context)
        }
    }

    private func keyUp(_ context: String) {
        if let hold = holds.removeValue(forKey: context) {
            hold.cancel()
            guard let key = keys[context], let touche = touche(key) else { return }
            perform(touche.court, context: context)
        }
        longFired.remove(context)
    }

    private func perform(_ action: DeckAction?, context: String) {
        guard let action else { elgato?.showAlert(context); return }
        if let commande = action.commande {
            send(commande)
        } else if let touche = action.touche {
            // Dofus derrière une autre app : une touche ne frappe rien, elle
            // ramène Dofus devant — la suivante fera ce qu'elle dit.
            guard let key = keys[context], pages[grid(of: key)]?.dofusDevant == true else { send("activer"); return }
            Keystroke.press(touche)
        } else {
            elgato?.showAlert(context)
        }
    }

    private func send(_ type: String) {
        guard let synfus, synfus.isConnected else { launchSynfus(); return }
        synfus.send(DeckCommand(type: type))
    }

    private func launchSynfus() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Synfus.app"),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Affichage

    private func apply(_ page: DeckPage) {
        let grid = Grid(columns: page.colonnes, rows: page.lignes)
        let wasFront = pages[grid]?.dofusDevant == true
        connected = true
        pages[grid] = page
        render()
        // Le profil Synfus suit Dofus : on y bascule quand il passe devant, on
        // rend la main quand il n'y est plus — le logiciel Stream Deck revient
        // alors au profil d'avant.
        let isFront = page.dofusDevant
        if isFront, !wasFront {
            for (device, deviceGrid) in devices where deviceGrid == grid && !switchedDevices.contains(device) {
                elgato?.switchToProfile(device: device, profile: BundledProfile.name)
                switchedDevices.insert(device)
            }
        } else if !isFront, wasFront {
            for device in switchedDevices where devices[device] == grid { elgato?.switchToProfile(device: device, profile: nil) }
            switchedDevices = switchedDevices.filter { devices[$0] != grid }
        }
    }

    private func disconnected() {
        connected = false
        pages.removeAll()
        render()
        for device in switchedDevices { elgato?.switchToProfile(device: device, profile: nil) }
        switchedDevices.removeAll()
    }

    private func render() { for context in keys.keys { render(context) } }

    /// Une touche, d'après la page de sa grille. Sans Synfus, les touches le
    /// disent ; Dofus derrière une autre app, Synfus les a atténuées.
    private func render(_ context: String, highlight: Bool = false) {
        guard let elgato, let key = keys[context] else { return }
        guard connected else {
            elgato.setImage(context, base64PNG: Images.blank(dimmed: true))
            elgato.setTitle(context, "Synfus\nabsent")
            return
        }
        guard let touche = touche(key) else {
            elgato.setImage(context, base64PNG: Images.blank(dimmed: true))
            elgato.setTitle(context, "")
            return
        }
        if let icone = touche.icone {
            elgato.setImage(context, base64PNG: Images.framed(icone, corner: touche.iconeLong, dimmed: touche.attenuee, highlight: highlight))
        } else if let symbole = touche.symbole {
            elgato.setImage(context, base64PNG: Images.symbol(symbole, dimmed: touche.attenuee, highlight: highlight))
        } else {
            elgato.setImage(context, base64PNG: Images.blank(dimmed: touche.attenuee))
        }
        elgato.setTitle(context, Images.title(touche.titre))
    }

    /// Un éclair sur la touche pressée : l'appareil n'anime rien de lui-même.
    private func flash(_ context: String) {
        render(context, highlight: true)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            self?.render(context)
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
    private static var frameCache: [String: String] = [:]
    /// Marge autour de l'icône sur la touche : une image bord à bord bave
    /// dès qu'on n'est pas pile en face de l'écran ; en retrait, avec des
    /// coins arrondis, elle reste nette. La place du titre est laissée en bas.
    static let margin: CGFloat = 16

    /// L'icône posée sur la touche : en retrait sur fond sombre, assombrie
    /// quand Dofus n'est pas devant ; en `corner`, le sort de l'appui long,
    /// en vignette en bas à droite — on sait d'un coup d'œil ce qu'on tient.
    static func framed(_ base64PNG: String, corner: String? = nil, dimmed: Bool, highlight: Bool = false) -> String {
        let key = "\(dimmed)/\(highlight)/\(base64PNG.hashValue)/\(corner?.hashValue ?? 0)"
        if let cached = frameCache[key] { return cached }
        guard let data = Data(base64Encoded: base64PNG), let image = NSImage(data: data) else { return base64PNG }
        let small = corner.flatMap { Data(base64Encoded: $0) }.flatMap { NSImage(data: $0) }
        let size = NSSize(width: 144, height: 144)
        let out = NSImage(size: size, flipped: false) { rect in
            NSColor(white: highlight ? 0.45 : 0.08, alpha: 1).setFill()
            rect.fill()
            let target = rect.insetBy(dx: margin, dy: margin).offsetBy(dx: 0, dy: 6)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: target, xRadius: 12, yRadius: 12).addClip()
            image.draw(in: target, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.55 : 1)
            NSGraphicsContext.restoreGraphicsState()
            if let small {
                let side = target.width * 0.42
                let box = NSRect(x: target.maxX - side + 4, y: target.minY - 4, width: side, height: side)
                NSColor(white: 0.08, alpha: 1).setFill()
                NSBezierPath(roundedRect: box.insetBy(dx: -3, dy: -3), xRadius: 9, yRadius: 9).fill()
                NSBezierPath(roundedRect: box, xRadius: 7, yRadius: 7).addClip()
                small.draw(in: box, from: .zero, operation: .sourceOver, fraction: dimmed ? 0.55 : 1)
            }
            return true
        }
        let result = png(out) ?? base64PNG
        frameCache[key] = result
        return result
    }

    /// Un titre qui tient sur la touche : coupé en deux lignes à l'espace le
    /// plus proche du milieu quand il est long, jamais plus de deux lignes.
    static func title(_ text: String) -> String {
        guard text.count > 9, !text.contains("\n") else { return text }
        let spaces = text.indices.filter { text[$0] == " " }
        guard let cut = spaces.min(by: { abs(text.distance(from: text.startIndex, to: $0) - text.count / 2)
                                          < abs(text.distance(from: text.startIndex, to: $1) - text.count / 2) })
        else { return text }
        return String(text[..<cut]) + "\n" + String(text[text.index(after: cut)...])
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
    static func symbol(_ name: String, dimmed: Bool, highlight: Bool = false) -> String {
        let key = "\(name)/\(dimmed)/\(highlight)"
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
            NSColor(white: highlight ? 0.45 : dimmed ? 0.08 : 0.16, alpha: 1).setFill()
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
