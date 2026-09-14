import AppKit
import ApplicationServices

/// Inspection des éléments du Dock via l'API Accessibilité.
///
/// Sert deux usages : le mode diagnostic en ligne de commande
/// (`Synfus --dump-dock [filtre]`), et la détection d'appel d'attention en
/// conditions réelles. On passe par le binaire de l'app plutôt que par un
/// utilitaire séparé parce que l'autorisation Accessibilité est liée à
/// l'identité de code : seul ce bundle-ci est autorisé à lire le Dock.
enum DockInspector {

    /// Instantané d'un élément du Dock : tous ses attributs lisibles.
    struct Snapshot {
        let title: String
        let attributes: [String: String]
    }

    /// Géométrie d'une icône du Dock. C'est tout ce dont le détecteur de rebond
    /// a besoin : quand une app réclame l'attention, le Dock fait monter son
    /// icône et l'expose réellement — `AXPosition.y` diminue le temps du saut.
    struct Item: Equatable {
        let title: String
        let position: CGPoint
        let size: CGSize
        /// Rang d'affichage, de gauche à droite.
        let rank: Int

        /// Identité d'une icône. Les clients Dofus s'intitulent tous « Dofus »
        /// dans le Dock : seul leur rang les distingue. On tient délibérément le
        /// rang plutôt que l'abscisse, qui bouge dès que la magnification écarte
        /// les icônes sous le curseur — chaque survol créait alors une identité
        /// neuve, et autant de positions de repos parasites.
        var key: String { "dofus#\(rank)" }

        var frame: CGRect { CGRect(origin: position, size: size) }
    }

    /// Sous-rôle des icônes d'application. Les fenêtres réduites en portent un
    /// autre (`AXMinimizedWindowDockItem`) : les compter décalerait l'appariement
    /// rang ↔ pid, et un rebond ferait basculer vers le mauvais perso.
    private static let applicationDockItem = "AXApplicationDockItem"

    /// Ce qu'un tour d'inspection rapporte du Dock.
    struct Inventory: Equatable {
        /// Icônes des clients Dofus lancés, de gauche à droite.
        let items: [Item]
        /// Cadre du **bandeau** entier — la liste qui héberge les icônes, toutes
        /// applications confondues. C'est la référence par rapport à laquelle une
        /// icône monte ou non : le bandeau accompagne le Dock quand il se masque
        /// ou se dévoile, alors qu'une icône qui rebondit s'en détache seule.
        let strip: CGRect?

        /// Zone où le curseur est réputé « sur le Dock ».
        ///
        /// Elle part du bandeau et non des seules icônes Dofus, faute de quoi un
        /// Dock masqué dévoilé à l'autre bout du bandeau ferait remonter les
        /// icônes de Dofus sans que le curseur soit jamais réputé dessus. La
        /// marge verticale couvre à la fois le bandeau caché et la bande de
        /// déclenchement au bord de l'écran ; l'horizontale, la magnification.
        var mouseZone: CGRect? {
            guard let base = strip ?? DockInspector.boundingFrame(items) else { return nil }
            return base.insetBy(dx: -60, dy: -max(80, base.height))
        }
    }

    /// Ce qui, dans le Dock, ne change pas d'un tour à l'autre : les éléments AX
    /// eux-mêmes. Les icônes Dofus et le bandeau qui les héberge sont des objets
    /// stables tant qu'aucun client ne se lance ni ne se ferme ; seules leur
    /// position et leur taille bougent. Retrouver ces éléments coûte cher —
    /// enfants du Dock, enfants de chaque liste, titre de **chaque** icône, puis
    /// sous-rôle et état de lancement des icônes Dofus — et dix fois par seconde,
    /// c'étaient trente à cinquante allers-retours vers le Dock. D'où ce cache,
    /// tenu par `DockGeometryReader`, qui n'est reconstruit qu'à bon escient.
    struct Structure {
        let dockPID: pid_t
        /// La liste qui héberge les icônes Dofus, quand elle a pu être lue.
        let strip: AXHandle?
        /// Icônes des clients Dofus lancés, dans l'ordre d'abscisse à la
        /// découverte. L'ordre de rang est recalculé à chaque relevé.
        let items: [(title: String, element: AXHandle)]
        let date: Date
    }

    /// Icônes du Dock appartenant à des clients Dofus lancés, de gauche à droite.
    static func dofusItems() -> [Item] { inventory().items }

    /// Tour complet : découverte structurelle puis relevé géométrique.
    static func inventory() -> Inventory {
        guard let structure = discoverStructure(now: Date()),
              let inventory = geometry(of: structure)
        else { return Inventory(items: [], strip: nil) }
        return inventory
    }

    /// Le tour complet : retrouve les éléments AX des icônes Dofus et du bandeau.
    /// Rend `nil` si le Dock n'est pas lancé.
    static func discoverStructure(now: Date) -> Structure? {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }

        let axDock = AXHandle.application(dock.processIdentifier)
        var items: [(title: String, x: CGFloat, element: AXHandle)] = []
        var strip: AXHandle?

        for list in AccessibilityReader.children(axDock) {
            var holdsDofus = false
            for element in AccessibilityReader.children(list) {
                guard let title = AccessibilityReader.stringAttribute(element, kAXTitleAttribute),
                      title.lowercased().contains("dofus"),
                      AccessibilityReader.stringAttribute(element, kAXSubroleAttribute) == applicationDockItem,
                      // Une app seulement épinglée ou « récente » ne rebondit pas :
                      // la retenir décalerait les rangs sans jamais servir.
                      AccessibilityReader.boolAttribute(element, "AXIsApplicationRunning") == true,
                      let position = AccessibilityReader.pointAttribute(element, kAXPositionAttribute)
                else { continue }
                items.append((title, position.x, element))
                holdsDofus = true
            }
            // Le bandeau retenu est celui qui héberge réellement les icônes.
            if holdsDofus { strip = list }
        }

        return Structure(
            dockPID: dock.processIdentifier,
            strip: strip,
            items: items.sorted { $0.x < $1.x }.map { ($0.title, $0.element) },
            date: now
        )
    }

    /// Le tour léger : position et taille de chaque élément connu, en **un seul**
    /// aller-retour par élément. Rend `nil` dès qu'un élément ne répond plus
    /// comme attendu — icône disparue, Dock relancé — : c'est le signal que la
    /// structure est périmée et qu'il faut la redécouvrir.
    static func geometry(of structure: Structure) -> Inventory? {
        var items: [(title: String, position: CGPoint, size: CGSize)] = []
        for item in structure.items {
            guard let frame = AccessibilityReader.frame(of: item.element) else { return nil }
            items.append((item.title, frame.origin, frame.size))
        }
        var strip: CGRect?
        if let element = structure.strip {
            guard let frame = AccessibilityReader.frame(of: element) else { return nil }
            strip = frame
        }
        return Inventory(
            items: items
                .sorted { $0.position.x < $1.position.x }
                .enumerated()
                .map { Item(title: $1.title, position: $1.position, size: $1.size, rank: $0) },
            strip: strip
        )
    }

    /// Cadre couvrant les icônes, élargi de la place que prend la magnification :
    /// elle écarte les icônes voisines et les fait monter bien au-delà de leur
    /// cadre au repos. Sert à savoir si le curseur est sur le Dock.
    static func boundingFrame(_ items: [Item]) -> CGRect? {
        guard var box = items.first?.frame else { return nil }
        for item in items.dropFirst() { box = box.union(item.frame) }
        return box.insetBy(dx: -60, dy: -80)
    }

    static func snapshots(matching filter: String = "") -> [Snapshot] {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return [] }

        let axDock = AXHandle.application(dock.processIdentifier)
        let needle = filter.lowercased()
        var result: [Snapshot] = []

        for list in AccessibilityReader.children(axDock) {
            for item in AccessibilityReader.children(list) {
                guard let title = AccessibilityReader.stringAttribute(item, kAXTitleAttribute) else { continue }
                if !needle.isEmpty && !title.lowercased().contains(needle) { continue }

                var attributes: [String: String] = [:]
                for name in AccessibilityReader.attributeNames(item) {
                    guard let raw = AccessibilityReader.value(item, name) else { continue }
                    attributes[name] = String(describing: raw)
                        .replacingOccurrences(of: "\n", with: " ")
                }
                result.append(Snapshot(title: title, attributes: attributes))
            }
        }
        return result
    }

    // MARK: - Mode ligne de commande

    static func runCommandLine(filter: String, seconds: Double) -> Never {
        guard AXIsProcessTrusted() else {
            print("NON_AUTORISE — accordez l'accès Accessibilité à cette app.")
            exit(2)
        }
        var previous: [String: [String: String]] = [:]
        let deadline = Date().addingTimeInterval(seconds)
        var first = true

        while Date() < deadline {
            for snapshot in snapshots(matching: filter) {
                let old = previous[snapshot.title]
                if first || old == nil {
                    print("=== \(snapshot.title) ===")
                    for (key, value) in snapshot.attributes.sorted(by: { $0.key < $1.key }) {
                        print("  \(key) = \(value.prefix(100))")
                    }
                } else if let old, old != snapshot.attributes {
                    let stamp = Date().formatted(date: .omitted, time: .standard)
                    for (key, value) in snapshot.attributes.sorted(by: { $0.key < $1.key })
                    where old[key] != value {
                        print("[\(stamp)] \(snapshot.title) :: \(key) : \(old[key] ?? "∅") → \(value)")
                    }
                    for key in old.keys where snapshot.attributes[key] == nil {
                        print("[\(stamp)] \(snapshot.title) :: \(key) DISPARU")
                    }
                }
                previous[snapshot.title] = snapshot.attributes
            }
            first = false
            Thread.sleep(forTimeInterval: 0.25)
        }
        print("--- fin du relevé ---")
        exit(0)
    }
}
