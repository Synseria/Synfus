// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 82592cc8aa023014 · contenu 87c65958a91bd6c4
// Plantages, blocages et excès que macOS remet à l'app par MetricKit, le lendemain : ils partent
// avec les statistiques.

import Foundation
import MetricKit

/// Un rapport de MetricKit, réduit à des valeurs.
public struct DiagnosticDeTelemetrie: Codable, Equatable, Sendable {
    public enum Genre: String, Codable, Sendable { case plantage, blocage, cpu, disque }

    public let genre: Genre
    /// La version de l'app qui l'a produit.
    public let version: String
    /// Le JSON de MetricKit (piles d'appels, adresses), sans le message d'exception, réduit par
    /// `reduire`.
    public let contenu: String

    /// En octets, une fois échappé dans le corps de l'envoi : le collecteur coupe
    /// `diagnostic.contenu` à 50 000 caractères (un JSON coupé ne se relit plus), et l'échappé
    /// n'est jamais plus court que le texte. Le reste du corps tient dans ses 64 Kio.
    public static let tailleMaximale = 49_000

    public init(genre: Genre, version: String, json: Data) {
        self.genre = genre
        self.version = version
        contenu = Self.reduire(json)
    }

    /// Le rapport sous `limite` une fois échappé, et toujours du JSON valide (on le relit pour
    /// symboliser) : entier s'il tient, sinon les piles du fil en faute, sinon les seules
    /// métadonnées. Couper le texte casserait le JSON. Le message d'une exception
    /// (`composedMessage`, `arguments`) part toujours : il peut citer un chemin, un titre, un texte.
    static func reduire(_ json: Data, limite: Int = tailleMaximale) -> String {
        guard var racine = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return "{}" }
        if var meta = racine["diagnosticMetaData"] as? [String: Any],
           var exception = meta["objectiveCexceptionReason"] as? [String: Any] {
            exception["composedMessage"] = nil
            exception["arguments"] = nil
            meta["objectiveCexceptionReason"] = exception
            racine["diagnosticMetaData"] = meta
        }
        var essais: [[String: Any]] = [racine]
        if var arbre = racine["callStackTree"] as? [String: Any], let piles = arbre["callStacks"] as? [[String: Any]] {
            // Sans fil désigné (blocage, excès), la première pile est celle du fil principal.
            let enFaute = piles.filter { $0["threadAttributed"] as? Bool == true }
            arbre["callStacks"] = enFaute.isEmpty ? Array(piles.prefix(1)) : enFaute
            var reduite = racine
            reduite["callStackTree"] = arbre
            essais.append(reduite)
        }
        essais.append(racine.filter { ["diagnosticMetaData", "version"].contains($0.key) })
        for essai in essais {
            guard let data = try? JSONSerialization.data(withJSONObject: essai, options: [.sortedKeys, .withoutEscapingSlashes]),
                  let texte = String(bytes: data, encoding: .utf8)
            else { continue }
            if tailleEchappee(texte) <= limite { return texte }
        }
        return "{}"
    }

    /// La place que prend `texte` en valeur de chaîne dans le corps JSON.
    static func tailleEchappee(_ texte: String) -> Int {
        (try? JSONSerialization.data(withJSONObject: texte, options: [.fragmentsAllowed, .withoutEscapingSlashes]))?.count
            ?? .max
    }
}

/// L'abonné de MetricKit. Les rapports arrivent sur une file quelconque : ils y sont réduits à
/// des `DiagnosticDeTelemetrie`, puis confiés à `recevoir` sur le main actor.
final class AbonneDiagnostics: NSObject, MXMetricManagerSubscriber {
    private let recevoir: @MainActor @Sendable ([DiagnosticDeTelemetrie]) -> Void

    init(recevoir: @escaping @MainActor @Sendable ([DiagnosticDeTelemetrie]) -> Void) {
        self.recevoir = recevoir
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let diagnostics = payloads.flatMap(Self.diagnostics)
        guard !diagnostics.isEmpty else { return }
        let recevoir = recevoir
        Task { @MainActor in recevoir(diagnostics) }
    }

    nonisolated private static func diagnostics(_ payload: MXDiagnosticPayload) -> [DiagnosticDeTelemetrie] {
        func reduire(_ liste: [MXDiagnostic]?, _ genre: DiagnosticDeTelemetrie.Genre) -> [DiagnosticDeTelemetrie] {
            (liste ?? []).map { DiagnosticDeTelemetrie(genre: genre, version: $0.applicationVersion, json: $0.jsonRepresentation()) }
        }
        return reduire(payload.crashDiagnostics, .plantage) + reduire(payload.hangDiagnostics, .blocage)
            + reduire(payload.cpuExceptionDiagnostics, .cpu) + reduire(payload.diskWriteExceptionDiagnostics, .disque)
    }
}
