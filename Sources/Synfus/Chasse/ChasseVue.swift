import SwiftUI

/// Le panneau de chasse : départ, direction, indice, résultat — de haut en
/// bas, dans l'ordre où l'on s'en sert.
struct ChasseVue: View {
    @ObservedObject private var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            depart
            directions
            indice
            lus
            resultat
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .font(.system(size: 12))
    }

    // MARK: - Départ

    private var depart: some View {
        HStack(spacing: 6) {
            Text(L("chasse.depart")).foregroundStyle(.secondary)
            TextField("x", value: $modele.departX, format: .number.grouping(.never))
                .frame(width: 50)
            TextField("y", value: $modele.departY, format: .number.grouping(.never))
                .frame(width: 50)
            Button { modele.reprendrePosition() } label: { Image(systemName: "location") }
                .buttonStyle(.borderless)
                .disabled(LecteurEcran.shared.positionDuPersoDevant == nil)
                .help(L("chasse.depart.reprendre"))
            Spacer()
        }
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Direction

    private var directions: some View {
        HStack(spacing: 6) {
            ForEach([Direction.ouest, .nord, .sud, .est]) { direction in
                let choisie = modele.direction == direction
                Button { modele.choisir(direction) } label: {
                    Image(systemName: direction.symbole)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 24)
                        .foregroundStyle(choisie ? Color.white : Color.primary)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(choisie ? Color.accentColor : Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(direction.libelle)
            }
            Spacer()
            if modele.rechercheEnCours { ProgressView().controlSize(.small) }
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

    private var lus: some View {
        HStack(spacing: 6) {
            if previews.authorized {
                Button(L("chasse.lire")) { modele.lire() }
                    .disabled(modele.lectureEnCours || modele.indices.isEmpty)
                    .help(L("chasse.lire.aide"))
            } else {
                Button(L("chasse.autoriser")) { previews.requestAuthorization() }
                    .help(L("chasse.autoriser.aide"))
            }
            if modele.lectureEnCours {
                ProgressView().controlSize(.small)
            } else if modele.rienLu {
                Text(L("chasse.rienLu")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(modele.lues, id: \.self) { cible in
                        Button { modele.choisir(cible) } label: {
                            Text(cible.nom(en: modele.langue))
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(modele.cible == cible
                                                           ? Color.accentColor.opacity(0.3)
                                                           : Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .controlSize(.small)
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
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
        }
    }
}
