import Foundation

/// La dernière release GitHub de Synfus, lue de l'API, et ce qu'on en compare
/// à la version installée. Pur : des octets et un texte, une décision.
struct VersionPubliee: Equatable, Sendable {
    /// « 0.11.0 », sans le « v » du tag.
    let numero: String
    /// La page de la release, pour lire les nouveautés.
    let page: URL
    /// Le DMG de l'architecture de ce Mac, et son nom dans `SHA256SUMS.txt`.
    let image: URL
    let nomImage: String
    let empreintes: URL
    /// Le macOS le plus ancien qui ouvre cette version (« 26 »), lu dans le nom du DMG avant
    /// tout téléchargement : une version qu'on ne pourrait pas ouvrir ne se propose pas.
    let macOSMinimum: String

    static let depot = "Synseria/Synfus"
    /// La page d'une release d'après son numéro : celle de la version installée, que l'API n'a pas à dire.
    static func page(de numero: String) -> URL {
        URL(string: "https://github.com/\(depot)/releases/tag/v\(numero)")!
    }

    static let api = URL(string: "https://api.github.com/repos/\(depot)/releases/latest")!

    /// L'architecture du binaire qui tourne : sous Rosetta, celle d'Intel,
    /// comme la version installée.
    static var architecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }

    /// La réponse de `releases/latest` (qui écarte d'office brouillons et
    /// préversions) ; `nil` si elle n'a pas le DMG de `architecture` ou les
    /// empreintes — une release incomplète ne se propose pas. Le DMG s'appelle
    /// `Synfus-X.Y.Z-macos<N>-<arch>.dmg` (`MACOS_MINIMUM` de build.sh) : les versions
    /// d'avant, qui ne lisent que `Synfus-X.Y.Z-<arch>.dmg`, ne voient pas une release
    /// qu'elles ne sauraient pas écarter d'un macOS trop ancien.
    static func lire(_ donnees: Data, architecture: String) -> VersionPubliee? {
        struct Reponse: Decodable {
            struct Fichier: Decodable {
                let name: String
                let browserDownloadUrl: URL
            }

            let tagName: String
            let htmlUrl: URL
            let assets: [Fichier]
        }
        let decodeur = JSONDecoder()
        decodeur.keyDecodingStrategy = .convertFromSnakeCase
        guard let reponse = try? decodeur.decode(Reponse.self, from: donnees),
              reponse.tagName.hasPrefix("v"), NumeroVersion(reponse.tagName) != nil
        else { return nil }
        let numero = String(reponse.tagName.dropFirst())
        let (debut, fin) = ("Synfus-\(numero)-macos", "-\(architecture).dmg")
        guard let dmg = reponse.assets.first(where: { fichier in
                  guard fichier.name.hasPrefix(debut), fichier.name.hasSuffix(fin) else { return false }
                  return OperatingSystemVersion(texte: String(fichier.name.dropFirst(debut.count).dropLast(fin.count))) != nil
              }),
              let empreintes = reponse.assets.first(where: { $0.name == "SHA256SUMS.txt" })?.browserDownloadUrl
        else { return nil }
        return VersionPubliee(numero: numero, page: reponse.htmlUrl, image: dmg.browserDownloadUrl, nomImage: dmg.name,
                              empreintes: empreintes,
                              macOSMinimum: String(dmg.name.dropFirst(debut.count).dropLast(fin.count)))
    }

    /// Vrai si ce Mac ouvre cette version.
    func ouvrable(sur systeme: OperatingSystemVersion) -> Bool {
        Self.ouvrable(minimum: macOSMinimum, sur: systeme)
    }

    /// Vrai si `systeme` atteint `minimum` (« 26 », « 26.0 », « 26.1.2 », comme
    /// `LSMinimumSystemVersion`) ; un minimum absent n'exige rien, un minimum illisible
    /// n'ouvre rien.
    static func ouvrable(minimum: String?, sur systeme: OperatingSystemVersion) -> Bool {
        guard let minimum else { return true }
        guard let exige = OperatingSystemVersion(texte: minimum) else { return false }
        return ![systeme.majorVersion, systeme.minorVersion, systeme.patchVersion]
            .lexicographicallyPrecedes([exige.majorVersion, exige.minorVersion, exige.patchVersion])
    }

    /// Vrai si cette release est plus récente que `installee` ; faux sans
    /// version installée lisible — un binaire nu ne se compare à rien.
    func plusRecente(que installee: String?) -> Bool {
        guard let installee = installee.flatMap(NumeroVersion.init), let publiee = NumeroVersion(numero) else { return false }
        return publiee > installee
    }

    /// L'empreinte SHA-256 de `nom` dans un `SHA256SUMS.txt` (format de `shasum` :
    /// « <hex>  <nom> »), en minuscules.
    static func empreinte(de nom: String, dans sommes: String) -> String? {
        for ligne in sommes.split(whereSeparator: \.isNewline) {
            let morceaux = ligne.split(separator: " ", omittingEmptySubsequences: true)
            guard morceaux.count == 2, morceaux[1].trimmingCharacters(in: CharacterSet(charactersIn: "*")) == nom,
                  morceaux[0].count == 64, morceaux[0].allSatisfy(\.isHexDigit)
            else { continue }
            return morceaux[0].lowercased()
        }
        return nil
    }
}

/// « X.Y.Z » ou « X.Y.Z-rc.N », comparé nombre par nombre : « 0.10.0 » passe
/// après « 0.9.0 », et `rc.1 < rc.2 < X.Y.Z < X.Y.(Z+1)-rc.1` — une rc
/// installée ne retient jamais la stable qui la suit. Tout autre suffixe n'est
/// pas une version de Synfus.
struct NumeroVersion: Comparable {
    let nombres: [Int]
    /// Le N d'une `-rc.N` ; `nil` pour une stable, qui passe après ses rc.
    let rc: Int?

    init?(_ texte: String) {
        var reste = Substring(texte.trimmingCharacters(in: .whitespaces))
        if reste.hasPrefix("v") { reste = reste.dropFirst() }
        let parties = reste.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let nombres = (parties.first ?? "").split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !nombres.isEmpty, nombres.allSatisfy({ $0 != nil }) else { return nil }
        if parties.count == 2 {
            guard parties[1].hasPrefix("rc."), let rc = Int(parties[1].dropFirst(3)) else { return nil }
            self.rc = rc
        } else {
            rc = nil
        }
        self.nombres = nombres.compactMap(\.self)
    }

    static func < (a: NumeroVersion, b: NumeroVersion) -> Bool {
        for i in 0..<max(a.nombres.count, b.nombres.count) {
            let x = i < a.nombres.count ? a.nombres[i] : 0
            let y = i < b.nombres.count ? b.nombres[i] : 0
            if x != y { return x < y }
        }
        switch (a.rc, b.rc) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        default: return false
        }
    }

    static func == (a: NumeroVersion, b: NumeroVersion) -> Bool { !(a < b) && !(b < a) }
}

extension OperatingSystemVersion {
    /// « 26 », « 26.1 » ou « 26.1.2 » ; `nil` pour tout autre texte.
    init?(texte: String) {
        let nombres = texte.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (1...3).contains(nombres.count), let majeur = nombres[0], majeur > 0,
              nombres.allSatisfy({ ($0 ?? -1) >= 0 })
        else { return nil }
        self.init(majorVersion: majeur, minorVersion: nombres.count > 1 ? nombres[1] ?? 0 : 0,
                  patchVersion: nombres.count > 2 ? nombres[2] ?? 0 : 0)
    }
}
