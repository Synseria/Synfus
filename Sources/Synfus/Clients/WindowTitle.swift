import Foundation

/// Ce que le titre d'une fenêtre Dofus dit du perso — « Nom - Classe - version - Release ».
/// Logique pure, sans Accessibilité : c'est elle qui décide ce qui est un perso.
enum WindowTitle {
    /// Séparateurs rencontrés dans les titres du client selon les versions.
    static let separators = [" - ", " – ", " — ", " | ", " • "]

    /// Un client qui n'a pas encore de perso en jeu — écran de connexion,
    /// sélection de personnage, chargement — s'intitule simplement « Dofus ».
    /// Ce n'est pas un perso : il n'a rien à faire dans la barre, et lui donner
    /// un emplacement décalerait les raccourcis des vrais persos.
    ///
    /// Un perso connecté porte toujours « Nom - Classe - version - Release ».
    static func isCharacterWindow(title: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.lowercased() != "dofus" else { return false }
        return separators.contains { cleaned.contains($0) }
    }

    /// Extrait le nom du perso du titre de la fenêtre. Le client Dofus n'a pas de
    /// format garanti : on prend ce qui précède le premier séparateur, et à défaut
    /// le titre entier. Le panneau de diagnostic affiche les titres bruts pour
    /// vérifier ce que ça donne réellement.
    static func characterName(fromTitle title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Sans titre" }

        for separator in separators {
            guard let range = cleaned.range(of: separator) else { continue }
            let head = String(cleaned[..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            if !head.isEmpty && head.lowercased() != "dofus" {
                return head
            }
        }
        return cleaned
    }

    /// Mots que le client affiche quand il n'a encore personne en jeu. Ils ne
    /// nomment aucun perso, et un nom qui n'est fait que de ceux-là ne mérite
    /// pas d'entrer dans la liste des persos connus.
    static let clientOnlyWords: Set<String> = ["dofus", "release", "beta", "alpha", "retail"]

    /// Un nom digne d'être mémorisé dans l'ordre des persos.
    ///
    /// Deux formes doivent rester visibles dans la barre — on veut pouvoir
    /// cliquer dessus — sans pour autant s'inscrire à demeure dans les réglages :
    ///
    /// - « Dofus 3.3.4.9 » : un client resté à l'écran de connexion, dont le
    ///   titre n'annonce que la version. Le perso qui s'y connectera portera son
    ///   vrai nom, et cette entrée-là resterait à jamais dans la liste, à changer
    ///   à chaque mise à jour du jeu.
    /// - « Machin (2) » : le suffixe de désambiguïsation ajouté par `refresh()`,
    ///   qui dépend de l'ordre de découverte et ne désigne donc aucun perso en
    ///   propre.
    ///
    /// Non mémorisés, ces clients se retrouvent simplement en fin de barre : le
    /// tri les relègue derrière tous les noms connus, sans décaler personne.
    static func isPersistableName(_ name: String) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !hasDuplicateSuffix(cleaned) else { return false }

        // Découpé sur les espaces et les séparateurs : un titre peut être repris
        // en entier faute de segment exploitable (« Dofus - 3.3.4.9 - Release »).
        let words = cleaned
            .components(separatedBy: CharacterSet(charactersIn: " -–—|•"))
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        return words.contains { !clientOnlyWords.contains($0) && !isVersionNumber($0) }
    }

    /// « Machin (2) » — le suffixe que `refresh()` ajoute lui-même aux homonymes.
    static func hasDuplicateSuffix(_ name: String) -> Bool {
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else { return false }
        let digits = name[name.index(after: open)..<name.index(before: name.endIndex)]
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// « 3.3.4.9 », « 2.70 » — des chiffres et des points, rien d'autre.
    static func isVersionNumber(_ word: String) -> Bool {
        !word.isEmpty
            && word.contains(where: \.isNumber)
            && word.allSatisfy { $0.isNumber || $0 == "." }
    }

    /// Deuxième segment du titre. Le client Dofus y place la classe, juste après
    /// le nom du perso — plus fiable que l'icône du Dock, identique pour tous les
    /// clients puisqu'ils partagent le même bundle.
    static func characterClass(fromTitle title: String) -> String? {
        let parts = title.components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        let candidate = parts[1]
        // Écarte un numéro de version qui occuperait cette position.
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .letters) != nil,
              !candidate.allSatisfy({ $0.isNumber || $0 == "." })
        else { return nil }
        return candidate
    }
}
