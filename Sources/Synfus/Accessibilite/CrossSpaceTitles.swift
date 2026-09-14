import CoreGraphics
import Foundation

/// Titres de fenêtres lus par `CGWindowListCopyWindowInfo` — la seule API qui
/// voit les fenêtres des espaces inactifs, là où `kAXWindows` rend une liste
/// vide.
///
/// Les titres n'y figurent qu'avec l'autorisation « Enregistrement de
/// l'écran », celle des aperçus. Elle n'est **jamais demandée ici** : sans
/// elle, la lecture rend simplement rien et la limite documentée demeure — un
/// client déjà sur un espace inactif au démarrage reste invisible jusqu'à ce
/// qu'on y bascule une fois.
enum CrossSpaceTitles {

    /// Le premier titre de fenêtre plausible de chaque pid demandé. Le filtre
    /// de taille écarte info-bulles et panneaux de service, comme
    /// `isGameWindow` côté Accessibilité.
    static func read(pids: Set<pid_t>) -> [pid_t: String] {
        guard !pids.isEmpty, CGPreflightScreenCaptureAccess(),
              let infos = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
                  as? [[String: Any]]
        else { return [:] }

        var titles: [pid_t: String] = [:]
        for info in infos {
            guard let owner = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  pids.contains(owner),
                  titles[owner] == nil,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let title = info[kCGWindowName as String] as? String, !title.isEmpty,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  AccessibilityReader.isGameWindow(subrole: nil, size: bounds.size)
            else { continue }
            titles[owner] = title
        }
        return titles
    }
}
