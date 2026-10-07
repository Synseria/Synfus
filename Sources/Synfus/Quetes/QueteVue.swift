import SwiftUI

/// Une quête : son nom, les ressources à réunir, puis chaque étape et ses
/// objectifs. Un clic sur une ressource copie son nom (pour l'hôtel de
/// vente), sur un objectif situé copie son trajet, zaap compris.
struct QueteVue: View {
    static let largeur: CGFloat = 340

    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    /// La ligne qui vient d'être copiée, le temps de le dire.
    @State private var copiee: String?
    /// Une fiche donnée (captures de la documentation) ; `nil` : celle du panneau.
    var ficheImposee: FicheQuete?

    private var fiche: FicheQuete? {
        ficheImposee ?? panneau.queteID.flatMap { store.quetes?.fiche($0, en: L10n.courante.langue) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            if let fiche {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !fiche.ressources.isEmpty { ressources(fiche) }
                        ForEach(Array(fiche.etapes.enumerated()), id: \.offset) { rang, etape in
                            etapeVue(rang, etape)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 460)
            }
        }
        .frame(width: Self.largeur)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }

    private var entete: some View {
        HStack(spacing: 8) {
            Image(systemName: "scroll").foregroundStyle(Couleurs.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(fiche?.nom ?? "").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let fiche {
                    Text(L("quete.niveau", fiche.niveau, fiche.etapes.count))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button { QuetePanel.shared.fermer() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("quete.fermer"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WindowDragArea())
    }

    private func ressources(_ fiche: FicheQuete) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                titreSection(L("quete.ressources"))
                Spacer()
                Button(L("quete.toutCopier")) {
                    copier(fiche.ressources.map { L("quete.ressource", $0.nom, $0.quantite) }.joined(separator: ", "),
                           ligne: "ressources")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            }
            ForEach(Array(fiche.ressources.enumerated()), id: \.offset) { indice, ressource in
                ligne(id: "ressource:\(indice)", icone: "shippingbox",
                      texte: L("quete.ressource", ressource.nom, ressource.quantite), detail: nil) {
                    copier(ressource.nom, ligne: "ressource:\(indice)")
                }
            }
        }
    }

    private func etapeVue(_ rang: Int, _ etape: FicheQuete.Etape) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titreSection(L("quete.etape", rang + 1, etape.nom))
            ForEach(Array(etape.objectifs.enumerated()), id: \.offset) { indice, objectif in
                let id = "objectif:\(rang):\(indice)"
                if let position = objectif.position {
                    ligne(id: id, icone: "mappin.and.ellipse", texte: objectif.texte,
                          detail: "\(position.x),\(position.y)") {
                        ZaapClipboard.shared.copierTrajet(vers: (position.x, position.y))
                        signaler(id)
                    }
                } else {
                    ligne(id: id, icone: "circle", texte: objectif.texte, detail: nil, action: nil)
                }
            }
        }
    }

    private func titreSection(_ texte: String) -> some View {
        Text(texte)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Une ligne ; cliquable quand elle copie quelque chose.
    private func ligne(id: String, icone: String, texte: String, detail: String?,
                      action: (() -> Void)?) -> some View {
        let faite = copiee == id
        return Button { action?() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: faite ? "checkmark" : icone)
                    .font(.system(size: 10))
                    .foregroundStyle(faite ? Couleurs.accent : Color.secondary)
                    .frame(width: 14)
                Text(texte).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if faite {
                    Text(L("quete.copie")).font(.system(size: 10, weight: .semibold)).foregroundStyle(Couleurs.accent)
                } else if let detail {
                    Text(detail).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(faite ? Couleurs.accent.opacity(0.15) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .help(action == nil ? "" : (detail == nil ? L("quete.copierNom") : L("quete.copierTrajet")))
    }

    private func copier(_ texte: String, ligne: String) {
        PressePapiers.copier(texte)
        signaler(ligne)
    }

    private func signaler(_ ligne: String) {
        copiee = ligne
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copiee == ligne { copiee = nil }
        }
    }
}
