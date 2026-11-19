// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu bc4f33effc055101
// Les noms qu'un rapport peut porter, et ses valeurs (pur).

import Foundation

/// Un nom de compteur, de réglage ou de mesure tel que le collecteur le garde (`[a-z0-9_]+`) :
/// il ne se construit que valide, si bien qu'une clé jetée en silence par le filtre du collecteur
/// ne peut pas s'écrire.
public struct CleDeTelemetrie: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let texte: String

    /// `nil` si `texte` sort de `[a-z0-9_]+`.
    public init?(_ texte: String) {
        guard !texte.isEmpty, texte.utf8.allSatisfy(Self.permis) else { return nil }
        self.texte = texte
    }

    /// Un identifiant de code ramené à la forme du collecteur : `extraireTexte` → `extraire_texte`,
    /// tout caractère hors de `[a-z0-9_]` devient `_`.
    public init(convertissant source: String) {
        var sortie = ""
        for caractere in source.unicodeScalars {
            if ("A"..."Z").contains(caractere) {
                if !sortie.isEmpty, sortie.last != "_" { sortie.append("_") }
                sortie.append(Character(caractere).lowercased())
            } else if caractere.isASCII, Self.permis(UInt8(caractere.value)) {
                sortie.append(Character(caractere))
            } else {
                sortie.append("_")
            }
        }
        texte = sortie.isEmpty ? "_" : sortie
    }

    public var description: String { texte }

    public static func < (a: Self, b: Self) -> Bool { a.texte < b.texte }

    public init(from decoder: Decoder) throws {
        let texte = try decoder.singleValueContainer().decode(String.self)
        guard let cle = Self(texte) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "clé hors de [a-z0-9_]+"))
        }
        self = cle
    }

    public func encode(to encoder: Encoder) throws {
        var conteneur = encoder.singleValueContainer()
        try conteneur.encode(texte)
    }

    static func permis(_ octet: UInt8) -> Bool {
        (0x61...0x7A).contains(octet) || (0x30...0x39).contains(octet) || octet == 0x5F
    }
}

/// Une valeur d'attribut OTLP.
public enum ValeurDeTelemetrie: Equatable, Sendable, Codable {
    case texte(String), entier(Int), reel(Double), booleen(Bool)

    /// OTLP JSON : un entier 64 bits s'écrit en chaîne.
    var json: [String: Any] {
        switch self {
        case .texte(let texte): ["stringValue": texte]
        case .entier(let entier): ["intValue": String(entier)]
        case .reel(let reel): ["doubleValue": reel]
        case .booleen(let booleen): ["boolValue": booleen]
        }
    }
}
