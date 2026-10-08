import Foundation

/// Tous les repères du jeu, datés : la liste intégrée à Synfus, ou la dernière
/// téléchargée de DofusDB (`CarteDofusDB`). Les zaaps en sont tirés — une seule
/// liste, une seule mise à jour —, et les sous-zones du Monde des Douze qui
/// choisissent le zaap d'un `/travel` (`ReseauSousZones`).
struct Carte: Codable, Equatable, Sendable {
    let date: Date
    let lieux: [Lieu]
    /// Les sous-zones du Monde des Douze, triées par identifiant.
    let sousZones: [SousZoneCarte]
    /// La sous-zone de chaque case du Monde des Douze, par « x,y ».
    let cases: [String: Int]

    /// Moins de repères que cela : une réponse tronquée, pas la carte du jeu.
    static let minimumPlausible = 300
    /// Le Monde des Douze en compte un peu plus de six mille.
    static let minimumCasesPlausible = 5000

    static let vide = Carte(date: .distantPast, lieux: [], sousZones: [], cases: [:])

    static func cle(_ x: Int, _ y: Int) -> String { "\(x),\(y)" }

    /// Un zaap par case, nommé par sa sous-zone.
    var zaaps: [Zaap] {
        var vus: Set<String> = []
        return lieux.filter(\.estZaap).compactMap { lieu in
            let zaap = Zaap(lieu.x, lieu.y, monde: lieu.monde,
                            noms: lieu.sousZone.isEmpty ? lieu.noms : lieu.sousZone, zone: lieu.zone,
                            idCarte: lieu.idCarte, idSousZone: lieu.idSousZone)
            return vus.insert(zaap.cle).inserted ? zaap : nil
        }
    }

    /// `Resources/Carte.json`, relevée par `--exporter-carte`.
    static let integree: Carte = {
        guard let url = Ressources.url("Carte.json"), let donnees = try? Data(contentsOf: url) else { return .vide }
        return (try? JSONDecoder().decode(Carte.self, from: donnees)) ?? .vide
    }()
}
