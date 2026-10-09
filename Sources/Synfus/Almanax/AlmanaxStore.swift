import Foundation

/// L'almanax du jour, demandé à l'ouverture de la palette : relu du disque
/// s'il est du jour, sinon téléchargé. Un échec ne montre rien — un almanax
/// d'hier tromperait — et se retente à l'ouverture suivante.
@MainActor
final class AlmanaxStore: ObservableObject {
    static let shared = AlmanaxStore()

    @Published private(set) var almanax: Almanax?
    private var demande: Task<Void, Never>?

    private init() {}

    func preparer() {
        let jour = Almanax.jour(de: Date())
        guard almanax?.jour != jour, demande == nil else { return }
        if almanax != nil { almanax = nil }
        demande = Task {
            let gardee = await Task.detached(priority: .utility) { Almanax.gardee() }.value
            if let gardee, gardee.jour == jour {
                almanax = gardee
            } else if let nouveau = try? await Almanax.telecharger(jour) {
                almanax = nouveau
                Task.detached(priority: .utility) { try? nouveau.garder() }
            }
            demande = nil
        }
    }
}
