/// Les commandes et variables du tchat que la palette propose. Relevées dans
/// les guides de la communauté (JeuxOnLine, forums) : une ligne qui n'existe
/// plus dans le jeu se retire ici, sans toucher au reste.
enum CommandeJeu: CaseIterable, Sendable {
    case zaap, travel, invite, quete, pnj
    case w, p, g, a, t, r, b
    case whois, whoami, away, invisible, amiAjouter, amiRetirer
    case list, kick, spectator, time, ping, mapid, clear

    /// Ce qui se tape.
    var texte: String {
        switch self {
        case .zaap: return "/zaap"
        case .travel: return "/travel"
        case .invite: return "/invite"
        case .quete: return "/quete"
        case .pnj: return "/pnj"
        case .w: return "/w"
        case .p: return "/p"
        case .g: return "/g"
        case .a: return "/a"
        case .t: return "/t"
        case .r: return "/r"
        case .b: return "/b"
        case .whois: return "/whois"
        case .whoami: return "/whoami"
        case .away: return "/away"
        case .invisible: return "/invisible"
        case .amiAjouter: return "/f a"
        case .amiRetirer: return "/f d"
        case .list: return "/list"
        case .kick: return "/kick"
        case .spectator: return "/spectator"
        case .time: return "/time"
        case .ping: return "/ping"
        case .mapid: return "/mapid"
        case .clear: return "/clear"
        }
    }

    /// Composée par Synfus plutôt que par le jeu.
    var synfus: Bool { [.zaap, .travel, .invite, .quete, .pnj].contains(self) }

    /// L'argument attendu, montré en gris ; `nil` : la commande se suffit.
    var argument: String? {
        switch self {
        case .zaap, .pnj, .whois, .amiAjouter, .amiRetirer, .kick: return L("palette.arg.nom")
        case .quete: return L("palette.arg.quete")
        case .travel: return L("palette.arg.lieu")
        case .invite: return L("palette.arg.invite")
        case .w: return L("palette.arg.nomMessage")
        case .p, .g, .a, .t, .r, .b: return L("palette.arg.message")
        case .whoami, .away, .invisible, .list, .spectator, .time, .ping, .mapid, .clear: return nil
        }
    }

    var description: String {
        switch self {
        case .zaap: return L("palette.cmd.zaap")
        case .travel: return L("palette.cmd.travel")
        case .invite: return L("palette.cmd.invite")
        case .quete: return L("palette.cmd.quete")
        case .pnj: return L("palette.cmd.pnj")
        case .w: return L("palette.cmd.w")
        case .p: return L("palette.cmd.p")
        case .g: return L("palette.cmd.g")
        case .a: return L("palette.cmd.a")
        case .t: return L("palette.cmd.t")
        case .r: return L("palette.cmd.r")
        case .b: return L("palette.cmd.b")
        case .whois: return L("palette.cmd.whois")
        case .whoami: return L("palette.cmd.whoami")
        case .away: return L("palette.cmd.away")
        case .invisible: return L("palette.cmd.invisible")
        case .amiAjouter: return L("palette.cmd.amiAjouter")
        case .amiRetirer: return L("palette.cmd.amiRetirer")
        case .list: return L("palette.cmd.list")
        case .kick: return L("palette.cmd.kick")
        case .spectator: return L("palette.cmd.spectator")
        case .time: return L("palette.cmd.time")
        case .ping: return L("palette.cmd.ping")
        case .mapid: return L("palette.cmd.mapid")
        case .clear: return L("palette.cmd.clear")
        }
    }
}

/// Les variables que le jeu remplace à l'envoi du message.
enum VariableJeu: String, CaseIterable, Sendable {
    case pos, zone, souszone, nom, lvl, xp, vie, viemax, viep, guilde, stats

    var texte: String { "%\(rawValue)%" }

    var description: String {
        switch self {
        case .pos: return L("palette.var.pos")
        case .zone: return L("palette.var.zone")
        case .souszone: return L("palette.var.souszone")
        case .nom: return L("palette.var.nom")
        case .lvl: return L("palette.var.lvl")
        case .xp: return L("palette.var.xp")
        case .vie: return L("palette.var.vie")
        case .viemax: return L("palette.var.viemax")
        case .viep: return L("palette.var.viep")
        case .guilde: return L("palette.var.guilde")
        case .stats: return L("palette.var.stats")
        }
    }
}
