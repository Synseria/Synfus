import Foundation

/// Où les réglages sont rangés. `UserDefaults` en production.
///
/// Cette indirection existe pour les tests : un `UserDefaults(suiteName:)` crée
/// un domaine persistant que `removePersistentDomain` ne supprime pas vraiment —
/// `cfprefsd` réécrit le fichier derrière, et la machine finit constellée de
/// plists de test dans `~/Library/Preferences`. Les tests se donnent donc un
/// stockage en mémoire.
///
/// Les noms diffèrent de ceux de `UserDefaults` à dessein : une surcharge de
/// `set(_:forKey:)` entrerait en ambiguïté avec la version `Any?` existante.
protocol PreferencesStore: AnyObject {
    func donnees(pour cle: String) -> Data?
    func enregistrer(_ donnees: Data, pour cle: String)
}

extension UserDefaults: PreferencesStore {
    func donnees(pour cle: String) -> Data? { data(forKey: cle) }
    func enregistrer(_ donnees: Data, pour cle: String) { set(donnees, forKey: cle) }
}

/// Ce que Synfus affiche dans la barre de menus du système.
enum MenuBarIcon: String, Codable, CaseIterable, Identifiable {
    case logo
    case symbole

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logo: return "Logo Synfus"
        case .symbole: return "Symbole système"
        }
    }
}
