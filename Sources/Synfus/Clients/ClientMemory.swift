import ApplicationServices

/// Règles pures d'affichage des persos : ordre de la barre, mémoire des
/// processus silencieux, persos découverts à travers les espaces.
enum ClientMemory {
    /// L'ordre de la barre : rang dans `characterOrder`, les inconnus en fin —
    /// c'est ce qui laisse les clients au login et les homonymes suffixés
    /// derrière sans décaler personne —, puis pid croissant, l'ordre de
    /// lancement, pour que deux inconnus ne s'échangent pas d'un tour à l'autre.
    static func sorted(_ clients: [DofusClient], by order: [String]) -> [DofusClient] {
        // Premier rang en cas de doublon : `firstIndex` faisait de même.
        var rank: [String: Int] = [:]
        for (index, name) in order.enumerated() where rank[name] == nil {
            rank[name] = index
        }
        return clients.sorted { lhs, rhs in
            let li = rank[lhs.name] ?? Int.max
            let ri = rank[rhs.name] ?? Int.max
            if li != ri { return li < ri }
            return lhs.pid < rhs.pid
        }
    }

    /// Complète les persos trouvés de ceux dont le processus vit encore mais ne
    /// rend plus aucune fenêtre — `silentPIDs`. Isolée et pure : c'est la règle
    /// qui décide ce que la barre affiche, elle mérite d'être testée.
    ///
    /// Un client rendu à l'écran de connexion n'en fait délibérément pas partie :
    /// il rend bien une fenêtre, simplement sans perso. Le ressusciter afficherait
    /// un perso qui n'est plus en jeu.
    static func withRemembered(
        found: [DofusClient],
        remembered: [pid_t: [DofusClient]],
        silentPIDs: Set<pid_t>
    ) -> [DofusClient] {
        let visible = Set(found.map(\.pid))
        let dormant = remembered
            .filter { silentPIDs.contains($0.key) && !visible.contains($0.key) }
            // Tri par pid : le dictionnaire n'a pas d'ordre, et la barre ne doit
            // pas se réorganiser d'un rafraîchissement à l'autre.
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
            .map { $0.remembered() }
        return found + dormant
    }

    /// Persos découverts à travers les espaces par CGWindowList : les pids
    /// vivants, muets pour l'Accessibilité et sans aucune mémoire. Pure, comme
    /// `withRemembered` : c'est une règle d'affichage, elle se teste.
    ///
    /// L'élément AX fourni est celui de l'application, pas d'une fenêtre — pour
    /// un perso dormant il ne sert à rien, l'activation du processus fait tout.
    /// Les homonymes sont suffixés comme ceux de l'inventaire, en comptant les
    /// noms déjà pris.
    static func discoveredAcrossSpaces(
        titles: [pid_t: String],
        existingNames: Set<String>,
        appElement: (pid_t) -> AXHandle
    ) -> [DofusClient] {
        var taken = existingNames
        // Tri par pid : l'ordre d'un dictionnaire changerait d'un inventaire à
        // l'autre, et les suffixes d'homonymes avec lui.
        return titles.sorted { $0.key < $1.key }.compactMap { pid, title in
            guard WindowTitle.isCharacterWindow(title: title) else { return nil }
            let base = WindowTitle.characterName(fromTitle: title)
            var name = base
            var seen = 1
            while taken.contains(name) {
                seen += 1
                name = "\(base) (\(seen))"
            }
            taken.insert(name)
            return DofusClient(
                pid: pid, slotKey: "\(pid)#cg", axWindow: appElement(pid),
                rawTitle: title, name: name,
                characterClass: WindowTitle.characterClass(fromTitle: title), dormant: true
            )
        }
    }
}
