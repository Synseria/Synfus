import AppKit
import UserNotifications

/// La notification système d'une version trouvée : une seule par version, le jour où elle l'est. Un clic ouvre
/// la proposition d'installer.
@MainActor
final class NotificationMiseAJour: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationMiseAJour()

    /// Vrai tant que cette version n'a pas été annoncée.
    nonisolated static func aAnnoncer(_ numero: String, derniere: String?) -> Bool { numero != derniere }

    /// Au démarrage, avant toute annonce : un clic sur une notification restée dans le Centre relance Synfus et
    /// doit encore être entendu.
    func demarrer() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Sans bundle (`swift run`, tests) le centre de notifications n'existe pas : rien à faire.
    func annoncerSiNouvelle(_ version: VersionPubliee) {
        let prefs = Preferences.shared
        guard Bundle.main.bundleIdentifier != nil, Self.aAnnoncer(version.numero, derniere: prefs.derniereVersionNotifiee) else { return }
        prefs.derniereVersionNotifiee = version.numero
        let centre = UNUserNotificationCenter.current()
        let contenu = UNMutableNotificationContent()
        contenu.title = L("maj.disponible", version.numero)
        let demande = UNNotificationRequest(identifier: "maj-\(version.numero)", content: contenu, trigger: nil)
        Task {
            guard (try? await centre.requestAuthorization(options: [.alert])) == true else { return }
            try? await centre.add(demande)
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive _: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        MiseAJour.shared.proposer()
        completionHandler()
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
