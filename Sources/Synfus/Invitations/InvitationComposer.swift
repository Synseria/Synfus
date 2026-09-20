import Foundation

/// Ce que Synfus pose dans le presse-papiers pour inviter un perso — et
/// lequel. Pur : on lui donne l'effectif et le chef, il rend un texte.
///
/// La limite est celle du dépôt : Synfus n'envoie rien au jeu. Il compose
/// `/invite Nom`, le joueur colle (⌘V ↩) dans le tchat — un geste par invité,
/// comme un clic par perso dans l'enchaînement au clic.
///
/// Le **chef** est fixé au premier appui d'un tour et le reste jusqu'au
/// dernier invité : avec le passage automatique, l'invité rebondit dans le
/// Dock et Synfus bascule dessus — sans cela, le tour reprendrait du point de
/// vue du nouveau perso et réinviterait le chef.
enum InvitationComposer {
    /// Le jeton remplacé par le nom du perso dans le format.
    static let jeton = "%nom"
    static let formatParDefaut = "/invite %nom"

    /// Les persos à inviter : l'effectif sans le chef — celui qui est devant,
    /// reconnu par son pid, dormant ou non. Les noms sont ceux du **titre**,
    /// jamais « Nom (2) » : le suffixe est celui de Synfus, le jeu ne le
    /// connaît pas. Deux homonymes donnent donc une seule invitation, et un
    /// client au login, qui ne nomme personne, aucune.
    static func candidats(_ effectif: [DofusClient], chefPID: pid_t?) -> [String] {
        var vus: Set<String> = []
        var noms: [String] = []
        for client in effectif where client.pid != chefPID {
            guard WindowTitle.isPersistableName(client.name) else { continue }
            let nom = WindowTitle.characterName(fromTitle: client.rawTitle)
            guard vus.insert(nom).inserted else { continue }
            noms.append(nom)
        }
        return noms
    }

    /// Le texte à coller. Un format sans jeton reçoit le nom en suffixe : on
    /// ne laisse jamais partir une commande sans son perso.
    static func commande(format: String, nom: String) -> String {
        guard format.contains(jeton) else {
            return format.trimmingCharacters(in: .whitespaces) + " " + nom
        }
        return format.replacingOccurrences(of: jeton, with: nom)
    }

    /// Le prochain nom à copier, en boucle sur `candidats`. Le curseur repart
    /// de zéro dès que la liste diffère de `precedents` — un autre chef, une
    /// autre équipe, un perso arrivé : on recommence le tour proprement.
    static func prochaine(
        candidats: [String], precedents: [String], curseur: Int?
    ) -> (nom: String, curseur: Int)? {
        guard !candidats.isEmpty else { return nil }
        let suivant: Int
        if candidats != precedents || curseur == nil {
            suivant = 0
        } else {
            suivant = (curseur! + 1) % candidats.count
        }
        return (candidats[suivant], suivant)
    }

    /// Le tour est fait quand le dernier candidat vient d'être copié : le
    /// prochain appui repart d'un nouveau chef — celui qui sera devant.
    static func tourTermine(curseur: Int, nombre: Int) -> Bool {
        curseur >= nombre - 1
    }
}
