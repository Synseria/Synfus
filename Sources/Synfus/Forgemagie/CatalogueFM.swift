import Foundation

/// Les effets que la forgemagie touche et les runes qui les posent, tirés de
/// DofusDB : `GET /effects` (poids par point `effectPowerRate`, gabarit du
/// libellé, effet opposé = son malus) et `GET /items?typeId=78` (les runes).
/// Pur : les réponses lui sont données.
struct CatalogueFM: Equatable, Sendable {
    struct Effet: Equatable, Sendable {
        let id: Int
        /// Le poids d'un point de la caractéristique (Force 1, Vitalité 0,2, PA 100).
        let poids: Double
        /// Le nom tel que le jeu l'écrit après la valeur : « Force », « Dommages Terre ».
        let nom: String
    }

    /// Le rang d'une rune : trois d'un rang se fusionnent en une du suivant.
    enum Rang: Int, Comparable, Sendable, CaseIterable {
        case simple, pa, ra
        static func < (a: Rang, b: Rang) -> Bool { a.rawValue < b.rawValue }
    }

    struct Rune: Equatable, Sendable {
        let effet: Int
        /// Les points qu'elle ajoute (Rune Vi 5, Pa Vi 15, Ra Vi 50).
        let puissance: Int
        let rang: Rang
        /// Sa « densité » dans le jeu : puissance × poids par point.
        let poids: Double
    }

    let effets: [Int: Effet]
    /// Par effet, ses runes du plus léger au plus lourd.
    let runes: [Int: [Rune]]

    // MARK: - Réponses de DofusDB

    struct EffetDofusDB: Decodable, Sendable {
        let id: Int
        let effectPowerRate: Double?
        let description: [String: String]?
    }

    struct ObjetDofusDB: Decodable, Sendable {
        struct EffetObjet: Decodable, Sendable { let effectId: Int; let from: Int }
        let effects: [EffetObjet]?
    }

    /// Le catalogue des runes et de leurs effets. Un malus se lit comme une
    /// valeur négative de l'effet positif : l'effet opposé ne sert pas. Une rune sans effet (signature),
    /// à puissance nulle (chasse) ou dont l'effet n'a pas de poids n'en fait pas
    /// partie. Le rang suit la puissance : la plus faible d'un effet est simple.
    init(effets reponseEffets: [EffetDofusDB], runes reponseRunes: [ObjetDofusDB], langue: String = "fr") {
        var effets: [Int: Effet] = [:]
        for effet in reponseEffets {
            guard let poids = effet.effectPowerRate, poids > 0 else { continue }
            let gabarit = effet.description?[langue] ?? effet.description?["fr"] ?? ""
            effets[effet.id] = Effet(id: effet.id, poids: poids, nom: Self.nom(gabarit: gabarit))
        }
        var parEffet: [Int: [Int]] = [:]
        for objet in reponseRunes {
            guard let premier = objet.effects?.first, premier.from > 0, effets[premier.effectId] != nil else { continue }
            parEffet[premier.effectId, default: []].append(premier.from)
        }
        var runes: [Int: [Rune]] = [:]
        for (effet, liste) in parEffet {
            let poids = effets[effet]?.poids ?? 0
            runes[effet] = Array(Set(liste)).sorted().enumerated().compactMap { index, puissance in
                Rang(rawValue: index).map { Rune(effet: effet, puissance: puissance, rang: $0, poids: Double(puissance) * poids) }
            }
        }
        self.effets = effets
        self.runes = runes
    }

    /// « #1{{~1~2 à }}#2 Dommage{{~ps}}{{~zs}} Terre » → « Dommages Terre » :
    /// valeurs ôtées, au pluriel (le jeu écrit « 16 Chance », « 3 Dommages Terre »).
    static func nom(gabarit: String) -> String {
        gabarit
            .replacing(/\{\{~1~2[^}]*\}\}/, with: "")
            .replacing(/#\d/, with: "")
            .replacing("{{~ps}}", with: "s")
            .replacing(/\{\{[^}]*\}\}/, with: "")
            .replacing(/^\s*%\s*/, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Les fautes de lecture tolérées sur un nom : une, deux à partir de dix lettres.
    static func fautesTolerees(_ nom: String) -> Int { nom.count >= 10 ? 2 : 1 }

    /// L'effet dont le nom ressemble le plus au texte lu, à `fautesTolerees` près.
    func effet(nomme lu: String) -> Effet? {
        let cherche = Ressemblance.normaliser(lu)
        guard !cherche.isEmpty else { return nil }
        let candidats = effets.values.map { ($0, Ressemblance.distanceDansTexte(Ressemblance.normaliser($0.nom), cherche)
            + abs(Ressemblance.normaliser($0.nom).count - cherche.count)) }
        guard let meilleur = candidats.min(by: { ($0.1, $0.0.id) < ($1.1, $1.0.id) }),
              meilleur.1 <= Self.fautesTolerees(cherche) else { return nil }
        return meilleur.0
    }
}
