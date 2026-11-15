import Foundation

/// L'almanax de la semaine (aujourd'hui et six jours), demandé à l'entrée de sa vue : relu du
/// disque pour les jours déjà lus, téléchargé pour les autres. Un jour qui échoue reste vide — un
/// almanax d'hier tromperait — et se redemande à l'entrée suivante.
@MainActor
final class AlmanaxStore: ObservableObject {
    static let shared = AlmanaxStore()

    /// Un jour de la semaine, lu ou pas encore.
    struct Jour: Equatable {
        let jour: String
        let almanax: Almanax?
    }

    @Published private(set) var jours: [String: Almanax] = [:]
    private var demande: Task<Void, Never>?

    private init() {}

    /// Les sept jours montrés, dans l'ordre.
    func semaine(_ date: Date = Date()) -> [Jour] {
        Almanax.semaine(depuis: date).map { Jour(jour: $0, almanax: jours[$0]) }
    }

    func preparer() {
        let attendus = Almanax.semaine(depuis: Date())
        guard demande == nil, attendus.contains(where: { jours[$0] == nil }) else { return }
        demande = Task {
            let gardes = await Task.detached(priority: .utility) { Almanax.gardes() }.value
            var semaine = jours.filter { attendus.contains($0.key) }
            for almanax in gardes where attendus.contains(almanax.jour) { semaine[almanax.jour] = almanax }
            jours = semaine
            var nouveaux = false
            for jour in attendus where jours[jour] == nil {
                guard let almanax = try? await Almanax.telecharger(jour) else { continue }
                jours[jour] = almanax
                nouveaux = true
            }
            if nouveaux {
                let aGarder = attendus.compactMap { jours[$0] }
                Task.detached(priority: .utility) { try? Almanax.garder(aGarder) }
            }
            demande = nil
        }
    }

    #if DEBUG
    /// Les jours d'exemple des captures : rien ne se lit sur le disque ni ne se télécharge.
    func poserPourCaptures(_ almanax: [Almanax]) {
        demande = Task {}
        jours = Dictionary(almanax.map { ($0.jour, $0) }, uniquingKeysWith: { a, _ in a })
    }
    #endif
}
