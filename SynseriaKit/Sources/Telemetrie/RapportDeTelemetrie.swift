// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit ac80a4e0b47b7314 · contenu 5de2835fd54b350d
// Le rapport envoyé : des jours d'utilisation en OTLP/HTTP JSON, et ce qui le décrit (pur).
// Contrat du collecteur : Flux-Domus, docs/11_telemetrie.md.

import CryptoKit
import Foundation
import IOKit

/// Ce qui décrit l'installation dans chaque rapport.
public struct ContexteDeTelemetrie: Equatable, Sendable {
    /// `service.name` : l'app, telle que le collecteur la connaît (`synfus`, `synthetic`).
    public var service: CleDeTelemetrie
    /// `IdentifiantDInstallation` : 64 caractères hexadécimaux.
    public var installation: String
    public var version: String
    public var systeme: String
    public var architecture: String
    /// Le genre de build, `nil` s'il n'envoie rien (build de développement).
    public var distribution: DistributionDeTelemetrie?

    public init(service: CleDeTelemetrie, installation: String, version: String,
                systeme: String = systeme(ProcessInfo.processInfo.operatingSystemVersion),
                architecture: String = architectureCourante, distribution: DistributionDeTelemetrie?) {
        self.service = service
        self.installation = installation
        self.version = Self.version(version)
        self.systeme = systeme
        self.architecture = architecture
        self.distribution = distribution
    }

    /// `X.Y.Z` ou `X.Y.Z-rc.N` seuls : le collecteur jette en silence (réponse 200) toute autre
    /// forme, si bien qu'un suffixe de plus verrait ses jours acquittés puis perdus.
    public static func version(_ version: String) -> String {
        version.prefixMatch(of: /\d+\.\d+\.\d+(-rc\.\d+)?/).map { String($0.output.0) } ?? version
    }

    /// La version de macOS sans le correctif (`26.1`).
    public static func systeme(_ version: OperatingSystemVersion) -> String {
        "\(version.majorVersion).\(version.minorVersion)"
    }

    public static var architectureCourante: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}

/// Le genre de build qui envoie, rapporté en `deployment.environment` : les chiffres des builds
/// du propriétaire se séparent de ceux des utilisateurs.
public enum DistributionDeTelemetrie: String, Sendable {
    /// Une release publiée.
    case release
    /// Un build installé par le développeur (`sh run.sh --install`).
    case local
}

/// Le corps d'un envoi au collecteur : un enregistrement `rapport` par jour, un `diagnostic` par
/// rapport de MetricKit, au format OTLP/HTTP JSON. Le collecteur jette toute clé qu'il ne connaît
/// pas ; ce qui est écrit ici est donc exactement ce qui peut être gardé.
public enum RapportDeTelemetrie {
    /// En octets : le collecteur refuse un corps plus gros.
    public static let tailleMaximale = 64 * 1024

    /// Les attributs d'un jour, triés par clé. `espaceDesMesures` préfixe les mesures de l'app
    /// (`persos` → `persos.max`).
    static func attributs(_ jour: JourDeTelemetrie, installation: String,
                          espaceDesMesures: CleDeTelemetrie?) -> [(cle: String, valeur: ValeurDeTelemetrie)] {
        var attributs: [(String, ValeurDeTelemetrie)] = [
            ("installation.id", .texte(installation)),
            ("jour", .texte(jour.jour)),
        ]
        if let langue = jour.langue { attributs.append(("langue", .texte(langue))) }
        if let espace = espaceDesMesures {
            for (cle, valeur) in jour.mesures where CleDeTelemetrie(cle) != nil {
                attributs.append(("\(espace.texte).\(cle)", valeur))
            }
        }
        for (cle, actif) in jour.reglages where CleDeTelemetrie(cle) != nil {
            attributs.append(("reglage.\(cle)", .booleen(actif)))
        }
        for (cle, nombre) in jour.compteurs where nombre > 0 && CleDeTelemetrie(cle) != nil {
            attributs.append(("usage.\(cle)", .entier(nombre)))
        }
        return attributs.sorted { $0.0 < $1.0 }
    }

    static func attributs(_ diagnostic: DiagnosticDeTelemetrie, installation: String) -> [(cle: String, valeur: ValeurDeTelemetrie)] {
        [
            ("diagnostic.contenu", .texte(diagnostic.contenu)),
            ("diagnostic.type", .texte(diagnostic.genre.rawValue)),
            ("diagnostic.version", .texte(diagnostic.version)),
            ("installation.id", .texte(installation)),
        ]
    }

    /// Le corps à envoyer, ou à montrer tel quel (`lisible`).
    public static func corps(_ jours: [JourDeTelemetrie], diagnostics: [DiagnosticDeTelemetrie] = [],
                             contexte: ContexteDeTelemetrie, espaceDesMesures: CleDeTelemetrie? = nil,
                             envoi: Date, lisible: Bool = false) -> Data {
        // L'instant d'envoi, pas le jour décrit (attribut `jour`) : Loki refuse une entrée trop
        // en arrière d'un flux partagé.
        let horodatage = String(Int64(envoi.timeIntervalSince1970 * 1_000_000_000))
        func enregistrement(_ corps: String, _ attributs: [(cle: String, valeur: ValeurDeTelemetrie)]) -> [String: Any] {
            ["timeUnixNano": horodatage, "body": ["stringValue": corps], "attributes": attributs.map(attribut)]
        }
        let enregistrements = jours.map {
            enregistrement("rapport", attributs($0, installation: contexte.installation, espaceDesMesures: espaceDesMesures))
        } + diagnostics.map { enregistrement("diagnostic", attributs($0, installation: contexte.installation)) }
        var ressource: [(String, ValeurDeTelemetrie)] = [
            ("service.name", .texte(contexte.service.texte)),
            ("service.version", .texte(contexte.version)),
            ("os.version", .texte(contexte.systeme)),
            ("host.arch", .texte(contexte.architecture)),
        ]
        if let distribution = contexte.distribution {
            ressource.append(("deployment.environment", .texte(distribution.rawValue)))
        }
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

    /// Le même corps, indenté, tel que l'app le montre.
    public static func texte(_ jours: [JourDeTelemetrie], diagnostics: [DiagnosticDeTelemetrie] = [],
                             contexte: ContexteDeTelemetrie, espaceDesMesures: CleDeTelemetrie? = nil, envoi: Date) -> String {
        String(bytes: corps(jours, diagnostics: diagnostics, contexte: contexte, espaceDesMesures: espaceDesMesures,
                            envoi: envoi, lisible: true), encoding: .utf8) ?? ""
    }

    private static func attribut(_ paire: (cle: String, valeur: ValeurDeTelemetrie)) -> [String: Any] {
        ["key": paire.cle, "value": paire.valeur.json]
    }
}

/// Ce que le collecteur répond d'un envoi.
public enum ReponseDuCollecteur: Equatable, Sendable {
    case acceptee
    /// Le contenu est en cause (trop gros, mal formé) : renvoyé tel quel, il serait refusé de même.
    case refusee
    /// Réseau, serveur, jeton ou débit : un autre essai, plus tard, peut passer.
    case echec

    public init(statut: Int?) {
        switch statut {
        case .some(200..<300): self = .acceptee
        case .some(401), .some(403), .some(408), .some(429): self = .echec
        case .some(400..<500): self = .refusee
        default: self = .echec
        }
    }
}

/// L'identifiant de l'installation : l'UUID matériel du Mac haché avec l'identifiant de l'app —
/// stable d'une réinstallation à l'autre, propre à chaque app (deux apps n'en tirent pas le même),
/// sans rien dire du Mac.
public enum IdentifiantDInstallation {
    public static func calculer(materiel: String, app: String) -> String {
        SHA256.hash(data: Data("\(app):\(materiel)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// L'identifiant tiré de `materiel`, ou, si le Mac ne le donne pas, d'un UUID tiré au hasard
    /// une fois et gardé dans `secours`.
    public static func fixer(materiel: String?, app: String, secours: inout String?) -> String {
        if let materiel { return calculer(materiel: materiel, app: app) }
        let tire = secours ?? UUID().uuidString
        secours = tire
        return calculer(materiel: tire, app: app)
    }

    /// `nil` si le Mac ne donne pas son UUID (jamais vu).
    public static func materiel() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        // `kIOPlatformUUIDKey`, macro C.
        return IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}

/// Où, avec quoi et pour quel genre de build envoyer : trois clés de l'Info.plist, posées par le
/// `build.sh` de l'app quand le coffre les lui donne. Il en manque une — build de développement —
/// : l'app compte, n'envoie rien.
public struct ConfigurationDeTelemetrie: Equatable, Sendable {
    public static let cleURL = "SynseriaTelemetrieURL"
    public static let cleJeton = "SynseriaTelemetrieJeton"
    public static let cleDistribution = "SynseriaDistribution"

    public let url: URL
    public let jeton: String
    public let distribution: DistributionDeTelemetrie

    public init(url: URL, jeton: String, distribution: DistributionDeTelemetrie) {
        self.url = url
        self.jeton = jeton
        self.distribution = distribution
    }

    /// `nil` sans l'une des trois clés, ou pour une adresse qui n'est pas en HTTPS.
    public init?(info: [String: Any]) {
        guard let texte = info[Self.cleURL] as? String, let url = URL(string: texte), url.scheme == "https",
              let jeton = info[Self.cleJeton] as? String, !jeton.isEmpty,
              let distribution = (info[Self.cleDistribution] as? String).flatMap(DistributionDeTelemetrie.init(rawValue:))
        else { return nil }
        self.init(url: url, jeton: jeton, distribution: distribution)
    }

    /// Celle de l'app qui tourne.
    public static var duBundle: ConfigurationDeTelemetrie? {
        Bundle.main.infoDictionary.flatMap { ConfigurationDeTelemetrie(info: $0) }
    }
}
