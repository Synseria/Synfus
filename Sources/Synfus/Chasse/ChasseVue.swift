import SwiftUI

/// Le panneau de chasse, au style du panneau de quêtes : transparent, un
/// en-tête par lequel on le déplace. Une seule colonne, aussi étroite que la
/// boussole le permet, pour masquer le moins de jeu possible : le départ, la
/// boussole — les quatre directions autour de « Lire » —, puis l'indice et
/// le résultat dessous.
struct ChasseVue: View {
    @ObservedObject private var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                depart
                boussole.frame(maxWidth: .infinity)
                indice
                lus
                resultat
            }
            .padding(Jetons.Espace.trois)
        }
        .frame(width: 216, alignment: .leading)
        .font(.synfus(.note))
        .surfaceFlottante()
    }

    private var entete: some View {
        EnTetePanneau(icone: "map", teinte: Couleurs.safran) {
            Text(L("chasse.titre")).font(.synfus(.corpsFort))
                .padding(.horizontal, Jetons.Espace.un)
                .padding(.vertical, Jetons.Espace.un)
            if modele.rechercheEnCours || modele.lectureEnCours { ProgressView().controlSize(.mini) }
        } boutons: {
            BoutonEnTete(icone: "minus", aide: L("quete.fermer.simple")) { ChassePanel.shared.fermer() }
        }
    }

    // MARK: - Départ

    private var depart: some View {
        HStack(spacing: Jetons.Espace.un) {
            Image(systemName: "flag").foregroundStyle(Couleurs.encreSecondaire)
                .help(L("chasse.depart"))
            TextField("x", value: $modele.departX, format: .number.grouping(.never))
                .frame(width: 52)
            TextField("y", value: $modele.departY, format: .number.grouping(.never))
                .frame(width: 52)
            Button { modele.reprendrePosition() } label: { Image(systemName: "location") }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .disabled(LecteurEcran.shared.positionDuPersoDevant == nil)
                .aide(L("chasse.depart.reprendre"))
            Spacer()
        }
        .textFieldStyle(.roundedBorder)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Boussole

    /// Nord en haut, ouest à gauche… et « Lire » au centre : l'indice lu à
    /// l'écran, ou l'autorisation à donner pour qu'il le soit.
    private var boussole: some View {
        Grid(horizontalSpacing: Jetons.Espace.un, verticalSpacing: Jetons.Espace.un) {
            GridRow {
                Color.clear.frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
                fleche(.nord)
                Color.clear.frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
            }
            GridRow {
                fleche(.ouest)
                centre
                fleche(.est)
            }
            GridRow {
                Color.clear.frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
                fleche(.sud)
                Color.clear.frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
            }
        }
    }

    private func fleche(_ direction: Direction) -> some View {
        let choisie = modele.direction == direction
        return Button { modele.choisir(direction) } label: {
            Image(systemName: direction.symbole)
                .font(.synfus(.titre))
                .frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
        }
        .buttonStyle(.etat(choisi: choisie))
        .aide(direction.libelle)
    }

    @ViewBuilder
    private var centre: some View {
        if previews.authorized {
            Button { modele.lire() } label: {
                Image(systemName: "text.viewfinder")
                    .font(.synfus(.titre))
                    .frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
            }
            .buttonStyle(.etat(courant: true))
            .disabled(modele.lectureEnCours || modele.indices.isEmpty)
            .aide(L("chasse.lire.aide"))
        } else {
            Button { previews.requestAuthorization() } label: {
                Image(systemName: "lock")
                    .frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
            }
            .buttonStyle(.etat())
            .aide(L("chasse.autoriser.aide"))
        }
    }

    // MARK: - Indice

    private var indice: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            // L'attente s'écrit dans le champ lui-même, en gris, puis il redevient « Indice ».
            TextField(L("chasse.indice"), text: $modele.saisie,
                      prompt: Text(modele.indices.isEmpty && modele.echecIndices == nil
                                   ? L("chasse.indices.chargement") : L("chasse.indice")))
                .textFieldStyle(.roundedBorder)
                .onSubmit { modele.validerSaisie() }
            ForEach(modele.suggestions, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Jetons.Espace.un)
                        .padding(.vertical, Jetons.Espace.un)
                }
                .buttonStyle(.etat(nue: true))
            }
            if modele.indices.isEmpty {
                if let echec = modele.echecIndices, !modele.chargementIndices {
                    HStack(spacing: Jetons.Espace.un) {
                        Text(L("chasse.indices.echec", echec))
                            .font(.synfus(.petit))
                            .foregroundStyle(Couleurs.alerte)
                        Button(L("quete.reessayer")) { Task { await modele.chargerIndices(forcer: true) } }
                            .buttonStyle(.bouton(.secondaire, dense: true))
                    }
                }
            }
        }
    }

    // MARK: - Indices lus

    /// Les indices lus à l'écran, à choisir d'un clic.
    private var lus: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            if modele.rienLu {
                HStack(spacing: Jetons.Espace.un) {
                    Text(L("chasse.rienLu")).font(.synfus(.petit)).foregroundStyle(Couleurs.encreSecondaire)
                    Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                        .buttonStyle(.bouton(.secondaire, dense: true))
                        .help(L("chasse.lire.aide"))
                }
            }
            ForEach(modele.lues, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .font(.synfus(.petit))
                        .lineLimit(1)
                        .padding(.horizontal, Jetons.Espace.deux)
                        .frame(height: Jetons.Taille.controleDense)
                }
                .buttonStyle(.etat(choisi: modele.cible == cible, rayon: Jetons.Rayon.capsule))
            }
        }
    }

    // MARK: - Résultat

    @ViewBuilder
    private var resultat: some View {
        if let echec = modele.echec {
            Text(L("chasse.echec", echec)).font(.synfus(.petit)).foregroundStyle(Couleurs.alerte)
        } else if let constat = modele.constat {
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: constat.direction.symbole).foregroundStyle(Couleurs.encreSecondaire)
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(constat.cible.nom(en: modele.langue))
                        .font(.synfus(.petit))
                        .foregroundStyle(Couleurs.encreSecondaire)
                    Group {
                        switch constat.resultat {
                        case .trouve(let x, let y, let distance):
                            Text(L("chasse.trouve", nombre: distance, Coordonnees.texte(x, y), distance)).font(.synfus(.corpsFort))
                        case .introuvable:
                            Text(L("chasse.introuvable", EtapeChasse.portee)).foregroundStyle(Couleurs.alerte)
                        case .phorreur:
                            Text(L("chasse.phorreur.suivre", constat.direction.libelle))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if case .trouve = constat.resultat {
                    Button { modele.copier() } label: {
                        Image(systemName: modele.copieRecente ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(modele.copieRecente ? Couleurs.primaireEncre : Couleurs.encreSecondaire)
                    }
                    .buttonStyle(.bouton(.tertiaire, dense: true))
                    .aide(L("chasse.copier"))
                }
            }
            .padding(Jetons.Espace.deux)
            .carte(rayon: Jetons.Rayon.controle)
        }
    }
}
