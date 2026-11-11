// Le rapport envoyé : des jours d'utilisation en OTLP/HTTP JSON (pur).

import CryptoKit
import Foundation
import IOKit

/// Ce qui décrit l'installation dans chaque rapport.
struct ContexteUsage: Equatable, Sendable {
    /// `IdentifiantInstallation.courant` : 64 caractères hexadécimaux.
    var installation: String
    var version: String
    var systeme: String
    var architecture: String

    /// La version de macOS sans le correctif (`26.1`).
    static func systeme(_ version: OperatingSystemVersion) -> String {
        "\(version.majorVersion).\(version.minorVersion)"
    }

    static var architectureCourante: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}

/// Le corps d'un envoi au collecteur : un enregistrement `rapport` par jour,
/// au format OTLP/HTTP JSON. Le collecteur jette toute clé qu'il ne connaît
/// pas ; ce qui est écrit ici est donc exactement ce qui peut être gardé.
enum RapportUsage {
    static let service = "synfus"

    enum Valeur: Equatable, Sendable {
        case texte(String), entier(Int), reel(Double), booleen(Bool)

        /// OTLP JSON : un entier 64 bits s'écrit en chaîne.
        var json: [String: Any] {
            switch self {
            case .texte(let texte): return ["stringValue": texte]
            case .entier(let entier): return ["intValue": String(entier)]
            case .reel(let reel): return ["doubleValue": reel]
            case .booleen(let booleen): return ["boolValue": booleen]
            }
        }
    }

    /// Les attributs d'un jour, triés par clé.
    static func attributs(_ jour: JourUsage, installation: String) -> [(cle: String, valeur: Valeur)] {
        var attributs: [(String, Valeur)] = [
            ("installation.id", .texte(installation)),
            ("jour", .texte(jour.jour)),
            ("persos.max", .entier(jour.persosMax)),
            ("persos.joues", .entier(jour.persosJoues.count)),
        ]
        if let langue = jour.langue { attributs.append(("langue", .texte(langue))) }
        if let moyenne = jour.persosMoyenne {
            attributs.append(("persos.moyenne", .reel((moyenne * 100).rounded() / 100)))
        }
        for (cle, actif) in jour.reglages { attributs.append(("reglage.\(cle)", .booleen(actif))) }
        for evenement in EvenementUsage.allCases where jour.nombre(evenement) > 0 {
            attributs.append(("usage.\(evenement.rawValue)", .entier(jour.nombre(evenement))))
        }
        return attributs.sorted { $0.0 < $1.0 }
    }

    static func attributs(_ diagnostic: DiagnosticUsage, installation: String) -> [(cle: String, valeur: Valeur)] {
        [
            ("diagnostic.contenu", .texte(diagnostic.contenu)),
            ("diagnostic.type", .texte(diagnostic.genre.rawValue)),
            ("diagnostic.version", .texte(diagnostic.version)),
            ("installation.id", .texte(installation)),
        ]
    }

    /// Le corps à envoyer, ou à montrer tel quel (`lisible`).
    static func corps(_ jours: [JourUsage], diagnostics: [DiagnosticUsage] = [], contexte: ContexteUsage,
                      envoi: Date, lisible: Bool = false) -> Data {
        // L'instant d'envoi, pas le jour décrit (attribut `jour`) : Loki
        // refuse une entrée trop en arrière d'un flux partagé.
        let horodatage = String(Int64(envoi.timeIntervalSince1970 * 1_000_000_000))
        func enregistrement(_ corps: String, _ attributs: [(cle: String, valeur: Valeur)]) -> [String: Any] {
            ["timeUnixNano": horodatage, "body": ["stringValue": corps], "attributes": attributs.map(attribut)]
        }
        let enregistrements = jours.map { enregistrement("rapport", attributs($0, installation: contexte.installation)) }
            + diagnostics.map { enregistrement("diagnostic", attributs($0, installation: contexte.installation)) }
        let ressource: [(String, Valeur)] = [
            ("service.name", .texte(service)),
            ("service.version", .texte(contexte.version)),
            ("os.version", .texte(contexte.systeme)),
            ("host.arch", .texte(contexte.architecture)),
        ]
        let racine: [String: Any] = [
            "resourceLogs": [[
                "resource": ["attributes": ressource.map(attribut)],
                "scopeLogs": [["logRecords": enregistrements]],
            ]],
        ]
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        if lisible { options.insert(.prettyPrinted) }
        return (try? JSONSerialization.data(withJSONObject: racine, options: options)) ?? Data()
    }

    /// Le même corps, indenté, tel que l'onglet Usage le montre.
    static func texte(_ jours: [JourUsage], diagnostics: [DiagnosticUsage], contexte: ContexteUsage, envoi: Date) -> String {
        String(bytes: corps(jours, diagnostics: diagnostics, contexte: contexte, envoi: envoi, lisible: true),
               encoding: .utf8) ?? ""
    }

    private static func attribut(_ paire: (cle: String, valeur: Valeur)) -> [String: Any] {
        ["key": paire.cle, "value": paire.valeur.json]
    }
}

/// Ce que le collecteur répond d'un envoi.
enum ReponseCollecteur: Equatable, Sendable {
    case acceptee
    /// Le contenu est en cause (trop gros, mal formé) : renvoyé tel quel, il
    /// serait refusé de même.
    case refusee
    /// Réseau, serveur, jeton ou débit : un autre essai, plus tard, peut passer.
    case echec

    init(statut: Int?) {
        switch statut {
        case .some(200..<300): self = .acceptee
        case .some(401), .some(403), .some(408), .some(429): self = .echec
        case .some(400..<500): self = .refusee
        default: self = .echec
        }
    }
}

/// L'identifiant de l'installation : l'UUID matériel du Mac haché avec
/// l'identifiant de l'app — stable d'une réinstallation à l'autre, propre à
/// Synfus (une autre app en tire un autre), sans rien dire du Mac.
enum IdentifiantInstallation {
    static func calculer(materiel: String, app: String) -> String {
        SHA256.hash(data: Data("\(app):\(materiel)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// `nil` si le Mac ne donne pas son UUID (jamais vu) : l'appelant tire
    /// alors un UUID au hasard et le garde.
    static func materiel() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        // `kIOPlatformUUIDKey`, macro C.
        return IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}
