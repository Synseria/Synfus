import Foundation

/// Tous les repères du jeu, datés : la liste intégrée à Synfus, ou la dernière
/// téléchargée de DofusDB (`CarteDofusDB`). Les zaaps en sont tirés — une seule
/// liste, une seule mise à jour.
struct Carte: Codable, Equatable, Sendable {
    let date: Date
    let lieux: [Lieu]

    /// Moins de repères que cela : une réponse tronquée, pas la carte du jeu.
    static let minimumPlausible = 300

    /// Un zaap par case, nommé par sa sous-zone.
    var zaaps: [Zaap] {
        var vus: Set<String> = []
        return lieux.filter(\.estZaap).compactMap { lieu in
            let zaap = Zaap(lieu.x, lieu.y, monde: lieu.monde,
                            noms: lieu.sousZone.isEmpty ? lieu.noms : lieu.sousZone, zone: lieu.zone)
            return vus.insert(zaap.cle).inserted ? zaap : nil
        }
    }

    /// `Resources/Carte.json`, relevée par `--exporter-carte`.
    static let integree: Carte = {
        guard let url = Ressources.url("Carte.json"),
              let donnees = try? Data(contentsOf: url),
              let carte = try? JSONDecoder().decode(Carte.self, from: donnees)
        else { return Carte(date: .distantPast, lieux: []) }
        return carte
    }()
}
