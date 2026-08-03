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
    struct Item {
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

    /// Icônes du Dock appartenant à des clients Dofus lancés, de gauche à droite.
    static func dofusItems() -> [Item] {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return [] }

        let axDock = AXUIElementCreateApplication(dock.processIdentifier)
        var items: [(title: String, position: CGPoint, size: CGSize)] = []

        for list in children(axDock) {
            for element in children(list) {
                guard let title = value(element, kAXTitleAttribute) as? String,
                      title.lowercased().contains("dofus"),
                      value(element, kAXSubroleAttribute) as? String == applicationDockItem,
                      // Une app seulement épinglée ou « récente » ne rebondit pas :
                      // la retenir décalerait les rangs sans jamais servir.
                      value(element, "AXIsApplicationRunning") as? Bool == true,
                      let position = point(element, kAXPositionAttribute),
                      let size = dimension(element, kAXSizeAttribute)
                else { continue }
                items.append((title, position, size))
            }
        }
        return items
            .sorted { $0.position.x < $1.position.x }
            .enumerated()
            .map { Item(title: $1.title, position: $1.position, size: $1.size, rank: $0) }
    }

    /// Cadre couvrant les icônes, élargi de la place que prend la magnification :
    /// elle écarte les icônes voisines et les fait monter bien au-delà de leur
    /// cadre au repos. Sert à savoir si le curseur est sur le Dock.
    static func boundingFrame(_ items: [Item]) -> CGRect? {
        guard var box = items.first?.frame else { return nil }
        for item in items.dropFirst() { box = box.union(item.frame) }
        return box.insetBy(dx: -60, dy: -80)
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &result) else { return nil }
        return result
    }

    private static func dimension(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &result) else { return nil }
        return result
    }

    static func snapshots(matching filter: String = "") -> [Snapshot] {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return [] }

        let axDock = AXUIElementCreateApplication(dock.processIdentifier)
        let needle = filter.lowercased()
        var result: [Snapshot] = []

        for list in children(axDock) {
            for item in children(list) {
                guard let title = value(item, kAXTitleAttribute) as? String else { continue }
                if !needle.isEmpty && !title.lowercased().contains(needle) { continue }

                var names: CFArray?
                AXUIElementCopyAttributeNames(item, &names)
                guard let attributeNames = names as? [String] else { continue }

                var attributes: [String: String] = [:]
                for name in attributeNames {
                    guard let raw = value(item, name) else { continue }
                    attributes[name] = String(describing: raw)
                        .replacingOccurrences(of: "\n", with: " ")
                }
                result.append(Snapshot(title: title, attributes: attributes))
            }
        }
        return result
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        guard let raw = value(element, kAXChildrenAttribute), let list = raw as? [AXUIElement] else { return [] }
        return list
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
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
