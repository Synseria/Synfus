import Foundation

/// Ce qu'une quête exige pour commencer, lu dans son `startCriterion` DofusDB
/// (`PL>109&PG=13&Qf=2009`). Pur. Seules les conditions en ET de premier
/// niveau comptent : une alternative (`|`) ou un groupe entre parenthèses
/// n'exige rien qu'on puisse affirmer (« Ça sent le gaz » : une quête par
/// classe, au choix). Les quêtes à finir (`Qf=`) viennent déjà de `need`.
struct ConditionsQuete: Equatable, Sendable {
    struct Metier: Equatable, Sendable {
        /// L'identifiant DofusDB du métier (`jobs`).
        let id: Int
        let niveau: Int
    }

    /// L'identifiant DofusDB de la classe (`PG=13` : Roublard).
    var classe: Int?
    /// Le niveau minimum (`PL>109` : 110).
    var niveau: Int?
    /// `PJ>26,79` : Alchimiste niveau 80.
    var metiers: [Metier] = []
    /// Le camp (`Ps=1` : Bonta, `alignment-sides`) et le niveau d'alignement
    /// (`Pa=78`, `Pa>19`).
    var camp: Int?
    var alignement: Int?

    static func lire(_ critere: String?) -> ConditionsQuete {
        var conditions = ConditionsQuete()
        for terme in termes(critere ?? "") {
            let texte = Array(terme)
            guard texte.count > 3 else { continue }
            let code = String(texte[0..<2]), comparaison = texte[2], valeur = String(texte[3...])
            // `>` est strict dans le jeu : `PL>109` ouvre la quête au niveau 110.
            let minimum = comparaison == ">" ? Int(valeur).map { $0 + 1 } : comparaison == "=" ? Int(valeur) : nil
            switch code {
            case "PG" where comparaison == "=": conditions.classe = Int(valeur)
            case "PL": if let minimum { conditions.niveau = max(conditions.niveau ?? 0, minimum) }
            case "PJ" where comparaison == ">", "Pj" where comparaison == ">":
                let parties = valeur.split(separator: ",")
                if parties.count == 2, let id = Int(parties[0]), let niveau = Int(parties[1]) {
                    conditions.metiers.append(Metier(id: id, niveau: niveau + 1))
                }
            case "Ps" where comparaison == "=": conditions.camp = Int(valeur)
            case "Pa": if let minimum { conditions.alignement = minimum }
            default: break
            }
        }
        return conditions
    }

    /// Les conditions en ET du premier niveau, sans les groupes ; aucune s'il
    /// y a une alternative au premier niveau.
    static func termes(_ critere: String) -> [Substring] {
        var termes: [Substring] = []
        var profondeur = 0
        var debut = critere.startIndex
        for indice in critere.indices {
            switch critere[indice] {
            case "(": profondeur += 1
            case ")": profondeur -= 1
            case "|" where profondeur == 0: return []
            case "&" where profondeur == 0:
                termes.append(critere[debut..<indice])
                debut = critere.index(after: indice)
            default: break
            }
        }
        termes.append(critere[debut...])
        return termes.filter { !$0.isEmpty && !$0.hasPrefix("(") }
    }
}
