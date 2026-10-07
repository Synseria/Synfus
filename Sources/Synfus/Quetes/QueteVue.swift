import SwiftUI

/// Les quêtes épinglées : un onglet par quête, puis les ressources à réunir
/// et l'étape en cours, qu'on parcourt aux flèches. Un clic sur une ressource
/// copie son nom (pour l'hôtel de vente), sur un objectif situé son trajet,
/// zaap compris.
struct QueteVue: View {
    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    /// La ligne qui vient d'être copiée, le temps de le dire.
    @State private var copiee: String?
    /// Une fiche donnée (captures de la documentation) ; `nil` : celles du panneau.
    var ficheImposee: FicheQuete?

    private var langue: Langue { L10n.courante.langue }

    private var idMontre: Int? { panneau.montree ?? prefs.quetesEpinglees.last }

    private var fiche: FicheQuete? {
        ficheImposee ?? idMontre.flatMap { store.fiche($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            onglets
            Divider()
            if let fiche {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        entete(fiche)
                        if !fiche.ressources.isEmpty { ressources(fiche) }
                        if !fiche.etapes.isEmpty { etape(fiche) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(store.chargement ? L("palette.quetes.chargement") : L("quete.aucune"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }

    // MARK: - Onglets

    /// Une pastille par quête épinglée ; on déplace le panneau par cette bande.
    private var onglets: some View {
        HStack(spacing: 6) {
            Image(systemName: "scroll").foregroundStyle(Couleurs.accent)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if let ficheImposee {
                        onglet(id: 0, nom: ficheImposee.nom, choisi: true)
                    } else {
                        ForEach(prefs.quetesEpinglees, id: \.self) { id in
                            onglet(id: id, nom: store.nom(id) ?? "…", choisi: id == idMontre)
                        }
                    }
                }
            }
            Button { QuetePanel.shared.fermer() } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("quete.fermer"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(WindowDragArea())
    }

    private func onglet(id: Int, nom: String, choisi: Bool) -> some View {
        HStack(spacing: 4) {
            Text(nom).lineLimit(1)
            Button { QuetePanel.shared.desepingler(id) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help(L("quete.desepingler"))
        }
        .font(.system(size: 11, weight: choisi ? .semibold : .regular))
        .foregroundStyle(choisi ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(choisi ? Couleurs.accent : Color.primary.opacity(0.08)))
        .onTapGesture { QuetePanel.shared.montrer(id) }
    }

    // MARK: - Contenu

    private func entete(_ fiche: FicheQuete) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fiche.nom).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 6) {
                Text(L("quete.niveau", fiche.niveau, fiche.etapes.count))
                if fiche.groupe { badge(L("quete.groupe"), icone: "person.3") }
                if fiche.donjon { badge(L("quete.donjon"), icone: "building.columns") }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    private func badge(_ texte: String, icone: String) -> some View {
        Label(texte, systemImage: icone)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Couleurs.ambre.opacity(0.25)))
            .foregroundStyle(Couleurs.ambre)
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
                      texte: L("quete.ressource", ressource.nom, ressource.quantite), detail: ressource.categorie,
                      monospace: false) {
                    copier(ressource.nom, ligne: "ressource:\(indice)")
                }
            }
        }
    }

    /// L'étape en cours, ‹ › pour passer à la précédente ou à la suivante ;
    /// le panneau s'en souvient d'une ouverture à l'autre.
    private func etape(_ fiche: FicheQuete) -> some View {
        let rang = min(rangEtape, fiche.etapes.count - 1)
        let etape = fiche.etapes[rang]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button { changerEtape(rang - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(rang == 0)
                    .help(L("quete.etapePrecedente"))
                titreSection(L("quete.etapeSur", rang + 1, fiche.etapes.count, etape.nom))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button { changerEtape(rang + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(rang >= fiche.etapes.count - 1)
                    .help(L("quete.etapeSuivante"))
            }
            .buttonStyle(.borderless)
            ForEach(Array(etape.objectifs.enumerated()), id: \.offset) { indice, objectif in
                let id = "objectif:\(rang):\(indice)"
                if let position = objectif.position {
                    ligne(id: id, icone: "mappin.and.ellipse", texte: objectif.texte,
                          detail: "\(position.x),\(position.y)", monospace: true) {
                        ZaapClipboard.shared.copierTrajet(vers: (position.x, position.y))
                        signaler(id)
                    }
                } else {
                    ligne(id: id, icone: "circle", texte: objectif.texte, detail: L("quete.nonSitue"),
                          monospace: false, action: nil)
                }
            }
        }
    }

    private var rangEtape: Int {
        guard let id = idMontre else { return 0 }
        return prefs.quetesEtape[String(id)] ?? 0
    }

    private func changerEtape(_ rang: Int) {
        guard let id = idMontre else { return }
        prefs.quetesEtape[String(id)] = max(rang, 0)
    }

    private func titreSection(_ texte: String) -> some View {
        Text(texte)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Une ligne ; cliquable quand elle copie quelque chose.
    private func ligne(id: String, icone: String, texte: String, detail: String?, monospace: Bool,
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
                    Text(detail)
                        .font(.system(size: monospace ? 11 : 10, design: monospace ? .monospaced : .default))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(faite ? Couleurs.accent.opacity(0.15) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .help(action == nil ? "" : (monospace ? L("quete.copierTrajet") : L("quete.copierNom")))
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
