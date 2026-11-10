import Foundation

/// Un monstre à son plus haut grade, tiré de DofusDB : niveau, vie, PA, PM et
/// résistances en pourcentage. De quoi choisir ses éléments avant d'entrer —
/// la même fiche pour le panneau d'aide aux boss et la fiche d'un donjon. Pur
/// (décodage) ; le réseau passe par `DofusDB`.
struct FicheCombat: Equatable, Sendable {
    enum Element: CaseIterable, Sendable {
        case neutre, terre, feu, eau, air
    }

    let niveau: Int
    let vie: Int
    let pa: Int
    let pm: Int
    let resistances: [Element: Int]

    /// Un grade tel que l'API le rend ; seuls ces champs sont lus.
    struct GradeAPI: Decodable, Sendable {
        let grade: Int
        let level: Int
        let lifePoints: Int
        let actionPoints: Int
        let movementPoints: Int
        let reductionNeutral: Int?
        let reductionEarth: Int?
        let reductionFire: Int?
        let reductionWater: Int?
        let reductionAir: Int?
    }

    struct MonstreAPI: Decodable, Sendable {
        let id: Int?
        let name: DofusDB.Noms?
        let grades: [GradeAPI]

        static let champs = ["id", "name", "grades"]
    }

    /// Le plus haut grade ; `nil` sans grade.
    init?(_ monstre: MonstreAPI) {
        guard let grade = monstre.grades.max(by: { $0.grade < $1.grade }) else { return nil }
        niveau = grade.level
        vie = grade.lifePoints
        pa = grade.actionPoints
        pm = grade.movementPoints
        resistances = [.neutre: grade.reductionNeutral ?? 0, .terre: grade.reductionEarth ?? 0,
                       .feu: grade.reductionFire ?? 0, .eau: grade.reductionWater ?? 0, .air: grade.reductionAir ?? 0]
    }

    /// Les éléments où il résiste le moins (à frapper) et le plus (à
    /// éviter), à `marge` points près ; rien quand l'écart entre extrêmes est
    /// sous `ecartUtile` : tout se vaut.
    var elements: (frapper: [Element], eviter: [Element]) {
        let valeurs = Element.allCases.map { ($0, resistances[$0] ?? 0) }
        guard let bas = valeurs.map(\.1).min(), let haut = valeurs.map(\.1).max(), haut - bas >= Self.ecartUtile
        else { return ([], []) }
        return (valeurs.filter { $0.1 <= bas + Self.marge }.map(\.0), valeurs.filter { $0.1 >= haut - Self.marge && $0.1 > bas + Self.marge }.map(\.0))
    }

    static let ecartUtile = 10
    static let marge = 5

    static func telecharger(monstre: Int) async throws -> FicheCombat? {
        let monstres: [MonstreAPI] = try await DofusDB.toutes(
            "monsters", [URLQueryItem(name: "id", value: "\(monstre)")] + DofusDB.selection(["grades"]))
        return monstres.first.flatMap(FicheCombat.init)
    }
}
