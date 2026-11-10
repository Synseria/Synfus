import Foundation

/// Un conseil tactique pour le combat d'un donjon, tiré de sa page sur Dofus
/// pour les noobs (« Conseils tactiques pour ce combat », à défaut la
/// stratégie ou le principe du combat) : la puce qui le résume,
/// l'explication qui la suit. Pur.
struct ConseilCombat: Equatable, Sendable {
    let titre: String
    let detail: String

    /// Les sections lues, la première qui en donne : les pages récentes ont
    /// leurs conseils tactiques, les anciennes seulement une stratégie ou le
    /// principe du combat, en puces aussi.
    static let sections = ["conseils-tactiques", "strategie-globale", "principe-combat"]

    static func extraire(_ html: String) -> [ConseilCombat] {
        for section in sections {
            let conseils = extraire(html, section: section)
            if !conseils.isEmpty { return conseils }
        }
        return []
    }

    /// La section commence à son ancre et s'arrête à l'ancre suivante ; une
    /// liste y porte un conseil par puce, l'explication qui la suit va au
    /// dernier. Lu bloc par bloc, sans motif qui traverse la page : le temps
    /// reste linéaire.
    private static func extraire(_ html: String, section nom: String) -> [ConseilCombat] {
        guard let ancre = html.range(of: "id=\"\(nom)\"") else { return [] }
        let reste = html[ancre.upperBound...]
        let section = reste[..<(reste.range(of: #"class="ancres-dpln""#)?.lowerBound ?? reste.endIndex)]
        return section.components(separatedBy: "<div class=\"paragraph\"").dropFirst().flatMap { paragraphe in
            let bloc = paragraphe.components(separatedBy: "</div>").first ?? ""
            return bloc.components(separatedBy: "<ul>").dropFirst().flatMap { liste in
                let morceaux = liste.components(separatedBy: "</ul>")
                // « Faire le Kimbo sans bouger le Disciple : » annonce son explication.
                let puces = morceaux[0].components(separatedBy: "<li>").dropFirst()
                    .map { texte(Substring($0)).trimmingCharacters(in: CharacterSet(charactersIn: " :")) }
                    .filter { !$0.isEmpty }
                let detail = texte(Substring(morceaux.dropFirst().joined()))
                return puces.enumerated().map { rang, titre in
                    ConseilCombat(titre: titre, detail: rang == puces.count - 1 ? detail : "")
                }
            }
        }
    }

    /// Le texte d'un morceau de page : balises ôtées, entités décodées,
    /// blancs ramenés à une espace.
    static func texte(_ html: Substring) -> String {
        let sansBalises = html.replacing(/<[^>]*>/, with: " ")
        let decode = sansBalises.replacing(/&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { trouve in
            entite(String(trouve.1)) ?? String(trouve.0)
        }
        return decode.replacing("\u{200B}", with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let nommees: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "rsquo": "’", "lsquo": "‘",
        "rdquo": "”", "ldquo": "“", "laquo": "«", "raquo": "»", "hellip": "…", "ndash": "–", "mdash": "—",
        "oelig": "œ", "OElig": "Œ", "aelig": "æ", "AElig": "Æ", "deg": "°", "times": "×", "euro": "€",
    ]

    /// Les lettres accentuées se lisent sur leur nom (`eacute` : e + accent aigu).
    private static let accents: [String: String] = [
        "acute": "\u{301}", "grave": "\u{300}", "circ": "\u{302}", "uml": "\u{308}", "cedil": "\u{327}",
        "tilde": "\u{303}", "ring": "\u{30A}",
    ]

    private static func entite(_ nom: String) -> String? {
        if nom.hasPrefix("#") {
            let hexa = nom.dropFirst().first.map { $0 == "x" || $0 == "X" } ?? false
            let valeur = hexa ? UInt32(nom.dropFirst(2), radix: 16) : UInt32(nom.dropFirst())
            return valeur.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if let texte = nommees[nom] { return texte }
        guard let lettre = nom.first,
              let marque = accents.first(where: { nom.count == $0.key.count + 1 && nom.hasSuffix($0.key) })?.value
        else { return nil }
        return (String(lettre) + marque).precomposedStringWithCanonicalMapping
    }
}
