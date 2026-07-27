import AppKit
import Carbon.HIToolbox

/// Une combinaison de touches, stockée au format Carbon puisque c'est
/// `RegisterEventHotKey` qui la consommera.
struct HotKey: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let mods = HotKey.carbonModifiers(from: event.modifierFlags)
        // Un raccourci global sans modificateur intercepterait la touche partout,
        // y compris pendant que l'utilisateur écrit dans le chat du jeu.
        guard mods != 0 || HotKey.isFunctionKey(UInt32(event.keyCode)) else { return nil }
        self.keyCode = UInt32(event.keyCode)
        self.modifiers = mods
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }

    static func isFunctionKey(_ code: UInt32) -> Bool {
        functionKeyNames[code] != nil
    }

    /// Rendu type « ⌘1 », dans l'ordre canonique des modificateurs macOS.
    var displayString: String {
        var out = ""
        if modifiers & UInt32(controlKey) != 0 { out += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { out += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { out += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { out += "⌘" }
        out += HotKey.keyName(keyCode)
        return out
    }

    /// Libellé d'une touche par sa position physique. On reste sur les positions
    /// ANSI plutôt que sur le caractère produit : sur un clavier AZERTY la rangée
    /// du haut tape & é " ' ( alors que tout le monde l'appelle « 1 2 3 4 5 ».
    static func keyName(_ code: UInt32) -> String {
        if let name = functionKeyNames[code] { return name }
        if let name = namedKeys[code] { return name }
        if let name = positionalKeys[code] { return name }
        return "#\(code)"
    }

    private static let positionalKeys: [UInt32: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
        // Pavé numérique : très pratique en multi-compte sur un clavier complet.
        83: "num1", 84: "num2", 85: "num3", 86: "num4", 87: "num5",
        88: "num6", 89: "num7", 91: "num8", 92: "num9", 82: "num0",
    ]

    private static let namedKeys: [UInt32: String] = [
        48: "⇥", 49: "espace", 36: "↩", 51: "⌫", 53: "⎋",
        // Touche en haut à gauche, sous Échap : « @ » sur un clavier Mac
        // français, « ` » sur un QWERTY. On affiche le libellé français.
        50: "@", 10: "<",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "⇱", 119: "⇲", 116: "⇞", 121: "⇟",
    ]

    private static let functionKeyNames: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20",
    ]

    /// Keycodes des touches 1 à 9 puis 0, dans l'ordre visuel de la rangée.
    static let digitRow: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]

    static func defaultHotKey(slot: Int) -> HotKey? {
        guard slot < digitRow.count else { return nil }
        return HotKey(keyCode: digitRow[slot], modifiers: UInt32(cmdKey))
    }
}
