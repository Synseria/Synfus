// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 040a56e0df16d7e2 · contenu b1d91877e29ef7ed
// Le numéro de version des apps : `X.Y.Z` ou `X.Y.Z-rc.N`, la seule source de sa lecture et de son ordre
// (mises à jour, télémétrie).

/// Un numéro de version, comparé composant par composant : « 0.10.0 » suit « 0.9.0 », ce qu'une
/// comparaison de textes ne verrait pas. Une préversion précède sa stable :
/// 0.11.0-rc.1 < 0.11.0-rc.2 < 0.11.0 < 0.11.1-rc.1 — un comparateur qui ignorerait `-rc.N`
/// retiendrait la stable suivante derrière une rc installée.
public struct NumeroDeVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// Sans le « v » d'un tag : « 0.11.0-rc.2 ».
    public let texte: String
    private let composants: [Int]
    /// Le N de « -rc.N » ; nil pour une stable.
    private let candidate: Int?

    public var estPreliminaire: Bool { candidate != nil }
    public var description: String { texte }

    /// Accepte un tag (« v0.9.0 ») et le seul suffixe « -rc.N », N en chiffres ASCII. Nil pour tout
    /// le reste : une version qu'on ne sait pas ordonner ne se propose pas.
    public init?(_ brut: String) {
        let texte = brut.hasPrefix("v") ? String(brut.dropFirst()) : brut
        let parties = texte.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let composants = parties[0].split(separator: ".", omittingEmptySubsequences: false).map(Self.entier)
        guard !composants.contains(nil) else { return nil }
        if parties.count == 2 {
            guard parties[1].hasPrefix("rc."), let rang = Self.entier(parties[1].dropFirst(3)) else { return nil }
            candidate = rang
        } else {
            candidate = nil
        }
        self.texte = texte
        self.composants = composants.compactMap(\.self)
    }

    /// Le numéro qui ouvre `texte` (« 0.13.0 (412) » → « 0.13.0 ») : la forme `X.Y.Z(-rc.N)` seule,
    /// trois composants exigés. Nil si `texte` ne commence pas ainsi.
    public static func prefixe(de texte: String) -> NumeroDeVersion? {
        texte.prefixMatch(of: /\d+\.\d+\.\d+(-rc\.\d+)?/).flatMap { NumeroDeVersion(String($0.output.0)) }
    }

    public static func < (gauche: Self, droite: Self) -> Bool {
        let longueur = max(gauche.composants.count, droite.composants.count)
        for index in 0..<longueur {
            let (a, b) = (gauche.composant(index), droite.composant(index))
            if a != b { return a < b }
        }
        switch (gauche.candidate, droite.candidate) {
        case let (a?, b?): return a < b
        case (_?, nil): return true
        default: return false
        }
    }

    /// « 1.0 » et « 1.0.0 » sont la même version.
    public static func == (gauche: Self, droite: Self) -> Bool { !(gauche < droite) && !(droite < gauche) }

    public func hash(into hasher: inout Hasher) {
        var significatifs = composants
        while significatifs.last == 0 { significatifs.removeLast() }
        hasher.combine(significatifs)
        hasher.combine(candidate)
    }

    private func composant(_ index: Int) -> Int { index < composants.count ? composants[index] : 0 }

    /// Des chiffres ASCII seuls : `Int` accepterait « +1 ».
    private static func entier(_ texte: Substring) -> Int? {
        guard !texte.isEmpty, texte.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(texte)
    }
}
