import Foundation

/// Les classes depuis l'API de DofusDB (`breeds`), téléchargées au démarrage
/// puis tous les 30 jours, gardées sur le disque. La fusion avec la table
/// intégrée est pure ; le réseau n'est qu'autour.
enum ClassesDofusDB {
    struct ClasseAPI: Codable, Sendable {
        let id: Int
        let shortName: DofusDB.Noms
        let img: String?

        static let champs = ["id", "shortName", "img"]
    }

    /// Ce qui est gardé sur le disque : la liste telle que DofusDB l'a rendue.
    struct Gardees: Codable {
        static let formatActuel = 1
        let format: Int
        let date: Date
        let classes: [ClasseAPI]
    }

    /// Une liste plus courte est une réponse tronquée, pas un jeu qui a perdu
    /// ses classes : on garde la précédente.
    static let minimumPlausible = 15

    enum Echec: LocalizedError {
        case listeSuspecte(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("classes.maj.suspecte", nombre)
            }
        }
    }

    /// `~/Library/Application Support/Synfus/Classes.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Classes.json", directoryHint: .notDirectory)
    }

    static func gardees() -> Gardees? {
        (try? Data(contentsOf: fichier)).flatMap(relire)
    }

    /// `nil` aussi pour un fichier d'une autre forme : il se retélécharge.
    static func relire(_ donnees: Data) -> Gardees? {
        guard let gardees = try? JSONDecoder().decode(Gardees.self, from: donnees),
              gardees.format == Gardees.formatActuel
        else { return nil }
        return gardees
    }

    static func garder(_ gardees: Gardees) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(gardees).write(to: fichier, options: .atomic)
    }

    static func telecharger(maintenant: Date = Date()) async throws -> Gardees {
        let classes: [ClasseAPI] = try await DofusDB.toutes("breeds", DofusDB.selection(ClasseAPI.champs))
        guard classes.count >= minimumPlausible else { throw Echec.listeSuspecte(classes.count) }
        return Gardees(format: Gardees.formatActuel, date: maintenant, classes: classes)
    }

    /// La table intégrée, rafraîchie par DofusDB : une classe connue (même
    /// identifiant) garde sa clé et sa couleur, prend les noms et l'emblème
    /// de DofusDB et reste reconnue sous ses anciens noms ; une classe que la
    /// table n'a pas s'ajoute à la suite, en teinte dérivée — sans attendre
    /// une mise à jour de Synfus.
    static func catalogue(_ telechargees: [ClasseAPI]) -> DofusClass.Catalogue {
        let parId = Dictionary(telechargees.map { ($0.id, $0) }, uniquingKeysWith: { premiere, _ in premiere })
        let connues = DofusClass.integrees.map { integree -> DofusClass.Breed in
            guard let api = parId[integree.idDofusDB] else { return integree }
            let noms = api.shortName.parLangue
            return DofusClass.Breed(
                key: integree.key, idDofusDB: integree.idDofusDB,
                noms: integree.noms.merging(noms) { _, dofusDB in dofusDB },
                alias: integree.alias.union(noms.values), color: integree.color,
                embleme: api.embleme)
        }
        let idsConnus = Set(DofusClass.integrees.map(\.idDofusDB))
        // Une clé déjà prise ferait deux lignes du même nom dans les réglages.
        let clesConnues = Set(connues.map(\.key))
        let nouvelles = telechargees
            .filter { !idsConnus.contains($0.id) }
            .sorted { $0.id < $1.id }
            .compactMap { api -> DofusClass.Breed? in
                guard let fr = api.shortName.fr, let key = DofusClass.cle(fr), !clesConnues.contains(key)
                else { return nil }
                let noms = api.shortName.parLangue
                return DofusClass.Breed(key: key, idDofusDB: api.id, noms: noms, alias: Set(noms.values),
                                        color: DofusClass.couleurDerivee(key), embleme: api.embleme)
            }
        return DofusClass.Catalogue(connues + nouvelles)
    }
}

private extension ClassesDofusDB.ClasseAPI {
    var embleme: URL { img.flatMap(URL.init(string:)) ?? DofusDB.emblemeClasse(id) }
}
