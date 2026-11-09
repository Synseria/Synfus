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

    static let depot = "Synseria/Synfus"
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
    /// empreintes — une release incomplète ne se propose pas.
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
        let nomImage = "Synfus-\(numero)-\(architecture).dmg"
        func fichier(_ nom: String) -> URL? { reponse.assets.first { $0.name == nom }?.browserDownloadUrl }
        guard let image = fichier(nomImage), let empreintes = fichier("SHA256SUMS.txt") else { return nil }
        return VersionPubliee(numero: numero, page: reponse.htmlUrl, image: image, nomImage: nomImage,
                              empreintes: empreintes)
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

/// « X.Y.Z » comparé nombre par nombre : « 0.10.0 » passe après « 0.9.0 ». Un
/// suffixe de préversion (« -beta ») est ignoré.
struct NumeroVersion: Comparable {
    let nombres: [Int]

    init?(_ texte: String) {
        var reste = Substring(texte.trimmingCharacters(in: .whitespaces))
        if reste.hasPrefix("v") { reste = reste.dropFirst() }
        let base = reste.split(separator: "-", maxSplits: 1).first ?? ""
        let nombres = base.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !nombres.isEmpty, nombres.allSatisfy({ $0 != nil }) else { return nil }
        self.nombres = nombres.compactMap(\.self)
    }

    static func < (a: NumeroVersion, b: NumeroVersion) -> Bool {
        for i in 0..<max(a.nombres.count, b.nombres.count) {
            let x = i < a.nombres.count ? a.nombres[i] : 0
            let y = i < b.nombres.count ? b.nombres[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    static func == (a: NumeroVersion, b: NumeroVersion) -> Bool { !(a < b) && !(b < a) }
}
