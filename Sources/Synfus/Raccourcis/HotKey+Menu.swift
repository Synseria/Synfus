import AppKit
import Carbon.HIToolbox

/// La touche d'un raccourci global telle qu'un `NSMenuItem` la montre : au bout de sa ligne, alignée par macOS.
struct EquivalentMenu: Equatable {
    let touche: String
    let modificateurs: NSEvent.ModifierFlags
}

extension HotKey {
    /// `nil` pour une touche que le menu ne sait pas dessiner (pavé numérique) : la ligne reste sans touche
    /// plutôt que d'en afficher une fausse.
    var equivalentMenu: EquivalentMenu? {
        guard let touche = Self.toucheDeMenu(keyCode) else { return nil }
        var masque: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { masque.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { masque.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { masque.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { masque.insert(.command) }
        return EquivalentMenu(touche: touche, modificateurs: masque)
    }

    private static func toucheDeMenu(_ code: UInt32) -> String? {
        if isFunctionKey(code), let rang = Int(keyName(code).dropFirst()) { return caractere(NSF1FunctionKey + rang - 1) }
        if pave.contains(code) { return nil }
        if let nommee = nommees[code] { return nommee }
        if let chiffre = digitRow.firstIndex(of: code) { return String((chiffre + 1) % 10) }
        let nom = keyName(code)
        // Les touches sans nom (« #51 ») n'ont pas de caractère de menu.
        guard nom.count == 1 else { return nil }
        return nom.lowercased()
    }

    private static func caractere(_ valeur: Int) -> String {
        UnicodeScalar(UInt32(valeur)).map { String(Character($0)) } ?? ""
    }

    /// Tout le pavé numérique, opérateurs compris : le menu les confondrait avec la rangée principale.
    private static let pave = Set<UInt32>([65, 67, 69, 71, 75, 76, 78, 81] + Array(82...92))

    private static let nommees: [UInt32: String] = [
        49: " ", 48: "\t", 36: "\r", 51: "\u{8}", 53: "\u{1b}",
        123: caractere(NSLeftArrowFunctionKey), 124: caractere(NSRightArrowFunctionKey),
        125: caractere(NSDownArrowFunctionKey), 126: caractere(NSUpArrowFunctionKey),
        115: caractere(NSHomeFunctionKey), 119: caractere(NSEndFunctionKey),
        117: caractere(NSDeleteFunctionKey), 116: caractere(NSPageUpFunctionKey), 121: caractere(NSPageDownFunctionKey),
    ]
}

extension NSMenuItem {
    /// Le raccourci au bout de la ligne ; sans raccourci, la ligne n'en montre pas. Le geste reste porté par le
    /// raccourci global (Carbon) : la ligne ne fait que le dire, pour qu'on l'apprenne en l'utilisant.
    func afficher(_ raccourci: HotKey?) {
        let equivalent = raccourci?.equivalentMenu
        keyEquivalent = equivalent?.touche ?? ""
        keyEquivalentModifierMask = equivalent?.modificateurs ?? []
    }
}
