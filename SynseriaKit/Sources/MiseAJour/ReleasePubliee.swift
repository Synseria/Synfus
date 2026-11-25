// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 82592cc8aa023014 · contenu 24f1dc07f0cc60eb
// Ce qu'une release publiée dit d'elle, le canal qui la choisit, et le macOS qu'elle exige (pur).

import Foundation
import Versions

/// D'où vient la mise à jour : les seules versions stables, ou aussi les préversions. Les valeurs
/// brutes sont persistées par les apps.
public enum CanalDeMiseAJour: String, CaseIterable, Sendable {
    case stable
    case beta
}

/// Un fichier joint à une release.
public struct FichierDeRelease: Equatable, Sendable {
    public let nom: String
    /// Son adresse de téléchargement, quand la source en donne une (l'API publique) ; une source qui
    /// télécharge par son outil (`gh`) n'en a pas besoin.
    public let adresse: URL?

    public init(nom: String, adresse: URL? = nil) {
        self.nom = nom
        self.adresse = adresse
    }
}

/// Une release, telle que la source de l'app la décrit.
public struct ReleasePubliee: Equatable, Sendable {
    /// Le tag tel que publié (« v0.11.0-rc.2 »).
    public let tag: String
    public let numero: NumeroDeVersion
    /// Une pre-release : vue du seul canal Bêta. Un numéro `-rc.N` en est toujours une, quoi que dise
    /// la source : une rc publiée sans le drapeau ne passe pas en Stable.
    public let preliminaire: Bool
    /// Les notes de version, en Markdown.
    public let notes: String
    /// La page de la release, pour lire les nouveautés ou télécharger à la main.
    public let page: URL?
    public let fichiers: [FichierDeRelease]
    /// Le macOS le plus ancien qui ouvre cette version (« 26 », « 26.1 »), quand la source le sait
    /// avant tout téléchargement : une version que ce Mac n'ouvrirait pas ne se propose pas.
    public let macOSMinimum: String?

    public init(tag: String, numero: NumeroDeVersion, preliminaire: Bool? = nil, notes: String = "", page: URL? = nil,
                fichiers: [FichierDeRelease] = [], macOSMinimum: String? = nil) {
        self.tag = tag
        self.numero = numero
        self.preliminaire = preliminaire == true || numero.estPreliminaire
        self.notes = notes
        self.page = page
        self.fichiers = fichiers
        self.macOSMinimum = macOSMinimum
    }

    /// Nil si `tag` n'est pas un numéro de version.
    public init?(tag: String, preliminaire: Bool? = nil, notes: String = "", page: URL? = nil,
                 fichiers: [FichierDeRelease] = [], macOSMinimum: String? = nil) {
        guard let numero = NumeroDeVersion(tag) else { return nil }
        self.init(tag: tag, numero: numero, preliminaire: preliminaire, notes: notes, page: page, fichiers: fichiers,
                  macOSMinimum: macOSMinimum)
    }

    /// La release à suivre sur `canal` : Stable, la plus haute des releases finales ; Bêta, la plus
    /// haute de toutes, préversions comprises.
    public static func plusHaute(parmi releases: [ReleasePubliee], canal: CanalDeMiseAJour) -> ReleasePubliee? {
        releases
            .filter { canal == .beta || !$0.preliminaire }
            .max { $0.numero < $1.numero }
    }

    /// Vrai si un Mac sous `systeme` ouvre cette version.
    public func ouvrable(sur systeme: OperatingSystemVersion) -> Bool {
        MacOSMinimum.atteint(macOSMinimum, par: systeme)
    }
}

/// Le macOS qu'exige une app, écrit comme `LSMinimumSystemVersion` (« 26 », « 26.0 », « 26.1.2 »).
public enum MacOSMinimum {
    /// Vrai si `systeme` atteint `minimum` ; un minimum absent n'exige rien, un minimum illisible
    /// n'ouvre rien.
    public static func atteint(_ minimum: String?, par systeme: OperatingSystemVersion) -> Bool {
        guard let minimum else { return true }
        guard let exige = lire(minimum) else { return false }
        return ![systeme.majorVersion, systeme.minorVersion, systeme.patchVersion]
            .lexicographicallyPrecedes([exige.majorVersion, exige.minorVersion, exige.patchVersion])
    }

    /// « 26 », « 26.1 » ou « 26.1.2 » ; nil pour tout autre texte.
    public static func lire(_ texte: String) -> OperatingSystemVersion? {
        let nombres = texte.split(separator: ".", omittingEmptySubsequences: false)
            .map { morceau in morceau.allSatisfy { $0.isASCII && $0.isNumber } ? Int(morceau) : nil }
        guard (1...3).contains(nombres.count), let majeur = nombres[0], majeur > 0, !nombres.contains(nil) else { return nil }
        return OperatingSystemVersion(majorVersion: majeur, minorVersion: nombres.count > 1 ? nombres[1] ?? 0 : 0,
                                      patchVersion: nombres.count > 2 ? nombres[2] ?? 0 : 0)
    }
}

/// Ce que l'app sait de la version qui tourne, d'un lancement à l'autre.
public enum VersionInstallee {
    /// Vrai si la version qui tourne n'est pas celle du lancement précédent (par une mise à jour ou
    /// à la main). Une sauvegarde qui ne la connaît pas (`derniere` absente) vient forcément d'une
    /// version plus ancienne ; au premier lancement, rien n'a changé.
    public static func apresMiseAJour(derniere: String?, courante: String?, premierLancement: Bool) -> Bool {
        guard let courante, !premierLancement else { return false }
        return derniere != courante
    }

    /// `--simuler-version X.Y.Z` : la version comparée aux releases à la place de celle du bundle,
    /// pour essayer une mise à jour sur un build déjà à jour.
    public static func simulee(_ arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--simuler-version"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
