import SwiftUI

/// Le panneau de chasse, au style du panneau de quêtes : transparent, un
/// en-tête par lequel on le déplace. Le départ, puis la boussole — les quatre
/// directions autour de « Lire » —, l'indice, et le résultat.
struct ChasseVue: View {
    @ObservedObject private var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                depart
                HStack(alignment: .top, spacing: 14) {
                    boussole
                    VStack(alignment: .leading, spacing: 6) {
                        indice
                        lus
                    }
                }
                resultat
            }
            .padding(12)
        }
        .frame(width: 360, alignment: .leading)
        .font(.system(size: 12))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }

    private var entete: some View {
        HStack(spacing: 8) {
            Image(systemName: "map").foregroundStyle(Couleurs.ambre)
            Text(L("chasse.titre")).font(.system(size: 13, weight: .semibold))
            Spacer()
            if modele.rechercheEnCours || modele.lectureEnCours { ProgressView().controlSize(.small) }
            Button { ChassePanel.shared.fermer() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("quete.fermer.simple"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WindowDragArea())
    }

    // MARK: - Départ

    private var depart: some View {
        HStack(spacing: 6) {
            Text(L("chasse.depart")).foregroundStyle(.secondary)
            TextField("x", value: $modele.departX, format: .number.grouping(.never))
                .frame(width: 54)
            TextField("y", value: $modele.departY, format: .number.grouping(.never))
                .frame(width: 54)
            Button { modele.reprendrePosition() } label: { Image(systemName: "location") }
                .buttonStyle(.borderless)
                .disabled(LecteurEcran.shared.positionDuPersoDevant == nil)
                .help(L("chasse.depart.reprendre"))
            Spacer()
        }
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Boussole

    /// Nord en haut, ouest à gauche… et « Lire » au centre : l'indice lu à
    /// l'écran, ou l'autorisation à donner pour qu'il le soit.
    private var boussole: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: 36, height: 36)
                fleche(.nord)
                Color.clear.frame(width: 36, height: 36)
            }
            GridRow {
                fleche(.ouest)
                centre
                fleche(.est)
            }
            GridRow {
                Color.clear.frame(width: 36, height: 36)
                fleche(.sud)
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    private func fleche(_ direction: Direction) -> some View {
        let choisie = modele.direction == direction
        return Button { modele.choisir(direction) } label: {
            Image(systemName: direction.symbole)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(choisie ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(choisie ? Couleurs.accent : Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(direction.libelle)
    }

    @ViewBuilder
    private var centre: some View {
        if previews.authorized {
            Button { modele.lire() } label: {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Couleurs.ambre)
                    .background(Circle().fill(Couleurs.ambre.opacity(0.18)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(modele.lectureEnCours || modele.indices.isEmpty)
            .help(L("chasse.lire.aide"))
        } else {
            Button { previews.requestAuthorization() } label: {
                Image(systemName: "lock")
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L("chasse.autoriser.aide"))
        }
    }

    // MARK: - Indice

    private var indice: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(L("chasse.indice"), text: $modele.saisie)
                .textFieldStyle(.roundedBorder)
                .onSubmit { modele.validerSaisie() }
            ForEach(modele.suggestions, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if modele.indices.isEmpty {
                Text(modele.chargementIndices ? L("chasse.indices.chargement")
                     : L("chasse.indices.echec", modele.echecIndices ?? "?"))
                    .font(.system(size: 10))
                    .foregroundStyle(modele.chargementIndices ? Color.secondary : Color.orange)
            }
        }
    }

    // MARK: - Indices lus

    /// Les indices lus à l'écran, à choisir d'un clic.
    private var lus: some View {
        VStack(alignment: .leading, spacing: 3) {
            if modele.rienLu {
                Text(L("chasse.rienLu")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ForEach(modele.lues, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(modele.cible == cible
                                                   ? Couleurs.accent.opacity(0.3)
                                                   : Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Résultat

    @ViewBuilder
    private var resultat: some View {
        if let echec = modele.echec {
            Text(L("chasse.echec", echec)).font(.system(size: 11)).foregroundStyle(.orange)
        } else if let constat = modele.constat {
            HStack(spacing: 6) {
                Image(systemName: constat.direction.symbole).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(constat.cible.nom(en: modele.langue))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    switch constat.resultat {
                    case .trouve(let x, let y, let distance):
                        Text(L("chasse.trouve", "[\(x),\(y)]", distance)).font(.system(size: 13, weight: .semibold))
                    case .introuvable:
                        Text(L("chasse.introuvable", EtapeChasse.portee)).foregroundStyle(.orange)
                    case .phorreur:
                        Text(L("chasse.phorreur.suivre", constat.direction.libelle))
                    }
                }
                Spacer()
                if case .trouve = constat.resultat {
                    Button { modele.copier() } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .help(L("chasse.copier"))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Couleurs.accent.opacity(0.12)))
        }
    }
}
