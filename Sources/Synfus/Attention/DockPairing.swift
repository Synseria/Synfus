import ApplicationServices

/// À quel perso appartient l'icône du Dock qui vient de rebondir.
///
/// L'hypothèse reste la même qu'avant — rang dans le Dock (trié par abscisse)
/// ↔ rang par pid croissant, les deux suivant l'ordre de lancement — mais elle
/// est appliquée au bon grain. Une icône du Dock appartient à un **processus**,
/// alors que `clients` porte un perso par **fenêtre** : apparier les deux
/// listes rang à rang ne tient que si elles ont exactement la même longueur, et
/// c'est faux dès qu'un client Dofus est resté à l'écran de connexion. Il a son
/// icône, il n'a pas de perso ; tous les rangs suivants se décalaient, un
/// rebond désignait le voisin, et le passage automatique basculait sur le
/// mauvais perso. Deux persos dans un même processus produisaient le décalage
/// inverse.
///
/// D'où ce foyer : on apparie **processus à processus** — c'est déjà le compte
/// de processus, et non celui des persos, qui périme le cache de structure du
/// Dock (`DockGeometryReader`) — puis on remonte du pid au perso. Pure, donc
/// testable sans Dock ni écran.
enum DockPairing {

    /// Les pids appariés aux `nombreIcones` icônes du Dock, dans leur ordre
    /// d'affichage. `nil` pour une icône sans pid connu — il y a alors plus
    /// d'icônes que de processus Dofus vivants, et l'appariement n'est plus
    /// digne de confiance (cf. `fiable`).
    static func pids(nombreIcones: Int, pidsVivants: Set<pid_t>) -> [pid_t?] {
        let ordonnes = pidsVivants.sorted()
        return (0..<max(nombreIcones, 0)).map { rang in
            rang < ordonnes.count ? ordonnes[rang] : nil
        }
    }

    /// Le perso de chaque icône du Dock. Un processus qui n'a pas encore de
    /// perso en jeu — écran de connexion — garde son icône et sa place, sans
    /// perso : c'est exactement ce qui manquait.
    ///
    /// Un processus qui porte plusieurs persos rend le premier de la liste ;
    /// c'est celui que le tri par pid puis par ordre de la barre place devant,
    /// et le Dock n'a de toute façon qu'une icône à lui donner.
    static func apparier(
        nombreIcones: Int, pidsVivants: Set<pid_t>, clients: [DofusClient]
    ) -> [DofusClient?] {
        var parPID: [pid_t: DofusClient] = [:]
        for client in clients where parPID[client.pid] == nil { parPID[client.pid] = client }
        return pids(nombreIcones: nombreIcones, pidsVivants: pidsVivants).map { pid in
            pid.flatMap { parPID[$0] }
        }
    }

    /// L'appariement est-il digne de confiance ? Une icône par processus
    /// vivant, ni plus ni moins. Sinon c'est qu'une entrée du Dock nous a
    /// échappé — une fenêtre réduite, une app tierce dont le titre contient
    /// « dofus » — et le Diagnostic doit le dire plutôt que de laisser croire.
    static func fiable(nombreIcones: Int, pidsVivants: Set<pid_t>) -> Bool {
        nombreIcones == pidsVivants.count
    }
}
