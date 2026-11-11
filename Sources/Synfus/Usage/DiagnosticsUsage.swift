// Plantages, blocages et excès que macOS remet à Synfus par MetricKit, le
// lendemain : ils partent avec les statistiques.

import Foundation
import MetricKit

/// Un rapport de MetricKit, réduit à des valeurs.
struct DiagnosticUsage: Codable, Equatable, Sendable {
    enum Genre: String, Codable, Sendable { case plantage, blocage, cpu, disque }

    let genre: Genre
    /// La version de Synfus qui l'a produit.
    let version: String
    /// Le JSON de MetricKit (piles d'appels, adresses, rien de l'utilisateur),
    /// réduit par `reduire`.
    let contenu: String

    /// En octets, une fois échappé dans le corps de l'envoi : le collecteur
    /// borne ce corps à 64 Kio, le reste (contexte, attributs) tient dans la marge.
    static let tailleMaximale = 60_000

    init(genre: Genre, version: String, json: Data) {
        self.genre = genre
        self.version = version
        contenu = Self.reduire(json)
    }

    /// Le rapport sous `limite` une fois échappé, et toujours du JSON valide
    /// (`Tools/symboliser.sh` le relit) : entier s'il tient, sinon les piles
    /// du fil en faute, sinon les seules métadonnées. Couper le texte casserait
    /// le JSON.
    static func reduire(_ json: Data, limite: Int = tailleMaximale) -> String {
        if let texte = String(bytes: json, encoding: .utf8), tailleEchappee(texte) <= limite { return texte }
        guard let racine = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return "{}" }
        var essais: [[String: Any]] = []
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

/// L'abonné de MetricKit. Les rapports arrivent sur une file quelconque : ils
/// y sont réduits à des `DiagnosticUsage`, puis confiés à `UsageStore` sur main.
final class AbonneDiagnostics: NSObject, MXMetricManagerSubscriber {
    @MainActor static let shared = AbonneDiagnostics()

    @MainActor func start() {
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let diagnostics = payloads.flatMap(Self.diagnostics)
        guard !diagnostics.isEmpty else { return }
        Task { @MainActor in UsageStore.shared.recevoir(diagnostics) }
    }

    nonisolated private static func diagnostics(_ payload: MXDiagnosticPayload) -> [DiagnosticUsage] {
        func reduire(_ liste: [MXDiagnostic]?, _ genre: DiagnosticUsage.Genre) -> [DiagnosticUsage] {
            (liste ?? []).map { DiagnosticUsage(genre: genre, version: $0.applicationVersion, json: $0.jsonRepresentation()) }
        }
        return reduire(payload.crashDiagnostics, .plantage) + reduire(payload.hangDiagnostics, .blocage)
            + reduire(payload.cpuExceptionDiagnostics, .cpu) + reduire(payload.diskWriteExceptionDiagnostics, .disque)
    }
}
