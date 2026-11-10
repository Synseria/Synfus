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
    /// coupé à `tailleMaximale`.
    let contenu: String

    /// Le corps d'un envoi est borné à 64 Kio par le collecteur.
    static let tailleMaximale = 40_000

    init(genre: Genre, version: String, json: Data) {
        self.genre = genre
        self.version = version
        let texte = String(bytes: json, encoding: .utf8) ?? ""
        contenu = texte.count > Self.tailleMaximale ? String(texte.prefix(Self.tailleMaximale)) : texte
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
