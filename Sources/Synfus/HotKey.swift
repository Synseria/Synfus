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

    /// Libellé d'une touche.
    ///
    /// La rangée de chiffres reste nommée par sa **position ANSI** : sur AZERTY
    /// elle tape `& é " ' (`, mais tout le monde l'appelle « 1 2 3 4 5 », et ce
    /// sont les numéros d'emplacement de Synfus.
    ///
    /// Tout le reste est demandé à la **disposition active**, et surtout pas
    /// codé en dur. Une table figée a déjà menti : elle donnait « @ » au keycode
    /// 50, ce qui n'est vrai que sur un clavier ANSI. Sur un ISO — tous les
    /// claviers Apple européens —, la touche sous Échap est le keycode 10, et 50
    /// est la touche `<>` près de la touche Majuscule gauche. Les réglages
    /// affichaient donc « ⌘@ » pour une combinaison que cette touche-là ne
    /// déclenchait pas.
    static func keyName(_ code: UInt32) -> String {
        if let name = functionKeyNames[code] { return name }
        if let name = namedKeys[code] { return name }
        if let name = positionalKeys[code] { return name }
        if let typed = layoutCharacter(code) { return typed }
        return "#\(code)"
    }

    /// Ce que la touche tape réellement dans la disposition active, en majuscule.
    /// `nil` si la touche ne tape rien, ou si la disposition n'est pas une
    /// disposition de clavier — une méthode de saisie idéographique n'expose
    /// aucune table.
    static func layoutCharacter(_ code: UInt32) -> String? {
        layoutCharacters[code]
    }

    /// La table complète, résolue **une seule fois**.
    ///
    /// Une fois, et pas à chaque affichage : `TISCopyCurrentKeyboardLayoutInputSource`
    /// ne supporte pas d'être appelée depuis plusieurs fils à la fois — la suite
    /// de tests, qui s'exécute en parallèle, la faisait abandonner sur SIGABRT.
    /// Un `static let` paresseux sérialise l'initialisation par construction,
    /// sans verrou ni isolation à plaider.
    ///
    /// La contrepartie est assumée : changer de disposition en cours de session
    /// ne rafraîchit pas les libellés avant le prochain lancement. Les raccourcis
    /// eux-mêmes, qui sont des positions physiques, ne bougent pas pour autant.
    private static let layoutCharacters: [UInt32: String] = readLayout()

    private static func readLayout() -> [UInt32: String] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }

        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let kind = UInt32(LMGetKbdType())

        return data.withUnsafeBytes { bytes -> [UInt32: String] in
            guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress
            else { return [:] }

            var table: [UInt32: String] = [:]
            for code in UInt32(0)...127 {
                var deadState: UInt32 = 0
                var length = 0
                var buffer = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDown), 0, kind,
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadState, buffer.count, &length, &buffer
                )
                guard status == noErr, length > 0 else { continue }
                let typed = String(utf16CodeUnits: buffer, count: length)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !typed.isEmpty { table[code] = typed.uppercased() }
            }
            return table
        }
    }

    /// Les seules touches nommées par leur position, et pour cause : ce sont des
    /// numéros. Les lettres en sont volontairement absentes — les y mettre
    /// affichait « A » pour la touche marquée Q d'un clavier AZERTY, ce qui est
    /// simplement faux. Elles passent par la disposition active.
    private static let positionalKeys: [UInt32: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        // Pavé numérique : très pratique en multi-compte sur un clavier complet.
        83: "num1", 84: "num2", 85: "num3", 86: "num4", 87: "num5",
        88: "num6", 89: "num7", 91: "num8", 92: "num9", 82: "num0",
    ]

    /// Touches qui ne tapent rien : la disposition n'a rien à en dire.
    private static let namedKeys: [UInt32: String] = [
        48: "⇥", 49: "espace", 36: "↩", 51: "⌫", 53: "⎋",
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
    /// Elle est réservée à l'accès direct : ⌘1…⌘0 numérotent les emplacements,
    /// ⌘0 étant celui du dixième. Aucun autre défaut ne doit y piocher.
    static let digitRow: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]

    static func defaultHotKey(slot: Int) -> HotKey? {
        guard slot < digitRow.count else { return nil }
        return HotKey(keyCode: digitRow[slot], modifiers: UInt32(cmdKey))
    }

    // MARK: - Jeu de raccourcis par défaut

    /// Touche sous Échap — « @ » sur un clavier Mac français, « ` » sur un
    /// QWERTY américain. Toutes les commandes de navigation tiennent dessus,
    /// différenciées par les modificateurs : un seul repère à mémoriser,
    /// atteignable de la main gauche sans lâcher la souris, et hors de la rangée
    /// de chiffres que se réserve l'accès direct.
    ///
    /// Son keycode dépend du **type physique** du clavier, et non de la
    /// disposition. Un ANSI place là `kVK_ANSI_Grave` (50) ; un ISO — donc tous
    /// les claviers Apple européens, clavier interne français compris — y place
    /// `kVK_ISO_Section` (10) et relègue le 50 à côté de la touche Majuscule
    /// gauche, là où AZERTY tape `<` et `>`.
    ///
    /// Le supposer à 50 partout est précisément ce qui rendait ces raccourcis
    /// muets sur un clavier français : ils étaient bien enregistrés, simplement
    /// sur une autre touche que celle annoncée.
    static var escapeRowKey: UInt32 {
        KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardISO ? isoSectionKey : ansiGraveKey
    }

    static let ansiGraveKey: UInt32 = 50
    static let isoSectionKey: UInt32 = 10

    /// ⌘@ — passer au perso suivant. C'est le geste central : plutôt que de viser
    /// un numéro, on avance dans la barre.
    static var defaultCycleNext: HotKey {
        HotKey(keyCode: escapeRowKey, modifiers: UInt32(cmdKey))
    }
    /// ⇧⌘@ — revenir au précédent.
    static var defaultCyclePrevious: HotKey {
        HotKey(keyCode: escapeRowKey, modifiers: UInt32(cmdKey) | UInt32(shiftKey))
    }
    /// ⌥⌘@ — aperçu de tous les persos, tant que la combinaison est maintenue.
    static var defaultPreview: HotKey {
        HotKey(keyCode: escapeRowKey, modifiers: UInt32(cmdKey) | UInt32(optionKey))
    }
    /// ⌃⌘@ — bascule du passage automatique.
    static var defaultToggleAutoFocus: HotKey {
        HotKey(keyCode: escapeRowKey, modifiers: UInt32(cmdKey) | UInt32(controlKey))
    }
    /// ⌘< — active ou coupe le mode « enchaîner ».
    ///
    /// Un seul modificateur : c'est une bascule, pas un accord. Sur un clavier
    /// ISO la touche voisine de Majuscule gauche est le keycode 50 — « < » sur
    /// AZERTY —, et elle est libre puisque la navigation occupe le keycode 10.
    ///
    /// Sur un ANSI cette touche n'existe pas, et le 50 y est justement celui de
    /// la navigation : le défaut s'y replie sur ⌥⌘⇥, faute d'équivalent. Deux
    /// branches ici, mais une seule combinaison simple sous chaque clavier.
    static var defaultAdvanceArm: HotKey {
        escapeRowKey == isoSectionKey
            ? HotKey(keyCode: ansiGraveKey, modifiers: UInt32(cmdKey))
            : HotKey(keyCode: 48, modifiers: UInt32(cmdKey) | UInt32(optionKey))
    }
}
