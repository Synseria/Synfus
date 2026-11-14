import SwiftUI

/// Le panneau de chasse, au style du panneau de quêtes : transparent, un
/// en-tête par lequel on le déplace. Une seule colonne, aussi étroite que la
/// boussole le permet, pour masquer le moins de jeu possible : le départ, la
/// boussole — les quatre directions autour de « Lire » —, puis l'indice et
/// le résultat dessous.
struct ChasseVue: View {
    @ObservedObject private var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @StateObject private var copie = SignalCopie()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            if indicesIndisponibles {
                indisponibles
            } else {
                VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                    depart
                    boussole.frame(maxWidth: .infinity)
                    if !previews.authorized { LigneAutorisation() }
                    indice
                    lus
                    resultat
                }
                .padding(Jetons.Espace.trois)
            }
        }
        .frame(width: 216, alignment: .leading)
        .font(Jetons.Typo.note.police)
        .surfaceFlottante()
    }

    private var entete: some View {
        EnTetePanneau(icone: BoutonBarre.chasse.symbole, teinte: Color.jeton(\.safran)) {
            Text(L("chasse.titre")).font(Jetons.Typo.corpsFort.police)
                .padding(.horizontal, Jetons.Espace.un)
                .padding(.vertical, Jetons.Espace.un)
            if modele.rechercheEnCours || modele.lectureEnCours || modele.enAttenteDesIndices { ProgressView().controlSize(.mini) }
        } boutons: {
            BoutonEnTete(icone: "xmark", aide: L("quete.fermer.simple")) { ChassePanel.shared.fermer() }
        }
    }

    // MARK: - Indices indisponibles

    /// Sans la liste des indices, rien ne se cherche : l'état occupe le panneau entier.
    private var indicesIndisponibles: Bool {
        modele.indices.isEmpty && modele.echecIndices != nil && !modele.chargementIndices
    }

    private var indisponibles: some View {
        VStack(spacing: Jetons.Espace.deux) {
            Text(L("chasse.indices.indisponibles")).foregroundStyle(Color.jeton(\.encreSecondaire))
            Button(L("commun.reessayer")) { Task { await modele.chargerIndices(forcer: true) } }
                .buttonStyle(.bouton(.secondaire, dense: true))
        }
        .frame(maxWidth: .infinity, minHeight: Jetons.Taille.rangeePalette * 3)
        .padding(Jetons.Espace.trois)
    }

    // MARK: - Départ

    /// Les coordonnées de départ, centrées sous l'en-tête, avec la position du personnage à reprendre.
    private var depart: some View {
        HStack(spacing: Jetons.Espace.un) {
            Image(systemName: "flag").foregroundStyle(Color.jeton(\.encreSecondaire))
                .help(L("chasse.depart"))
            TextField("x", value: $modele.departX, format: .number.grouping(.never), prompt: Text("x"))
                .frame(width: 52)
            TextField("y", value: $modele.departY, format: .number.grouping(.never), prompt: Text("y"))
                .frame(width: 52)
            Button { modele.reprendrePosition() } label: { Image(systemName: "location") }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .disabled(LecteurEcran.shared.positionDuPersoDevant == nil)
                .aide(L("chasse.depart.reprendre"))
        }
        .multilineTextAlignment(.center)
        .textFieldStyle(.roundedBorder)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Boussole

    /// Nord en haut, ouest à gauche… et « Lire » au centre : l'indice lu à
    /// l'écran, grisé tant que l'autorisation manque.
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
                .font(Jetons.Typo.titre.police)
                .frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
        }
        .buttonStyle(.etat(choisi: choisie))
        .disabled(modele.enAttenteDesIndices)
        .aide(direction.libelle)
    }

    private var centre: some View {
        Button { modele.lire() } label: {
            Image(systemName: "text.viewfinder")
                .font(Jetons.Typo.titre.police)
                .frame(width: Jetons.Taille.rangeePalette, height: Jetons.Taille.rangeePalette)
        }
        .buttonStyle(.etat(courant: true))
        .disabled(!previews.authorized || modele.lectureEnCours || modele.indices.isEmpty)
        .aide(L("chasse.lire.aide"))
    }

    // MARK: - Indice

    private var indice: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            // Ce que le champ attend s'écrit dans son texte d'exemple : le départ, puis une direction,
            // puis l'indice.
            TextField(L("chasse.indice"), text: $modele.saisie, prompt: Text(modele.attente.libelle))
                .textFieldStyle(.roundedBorder)
                .disabled(modele.enAttenteDesIndices)
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
        }
    }

    // MARK: - Indices lus

    /// Les indices lus à l'écran, à choisir d'un clic.
    private var lus: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            if modele.rienLu {
                HStack(spacing: Jetons.Espace.un) {
                    Text(L("chasse.rienLu")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                        .buttonStyle(.bouton(.secondaire, dense: true))
                        .help(L("chasse.lire.aide"))
                }
            }
            ForEach(modele.lues, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .font(Jetons.Typo.petit.police)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Jetons.Espace.un)
                        .padding(.vertical, Jetons.Espace.un)
                }
                .buttonStyle(.etat(choisi: modele.cible == cible, nue: true))
            }
        }
    }

    // MARK: - Résultat

    @ViewBuilder
    private var resultat: some View {
        if let echec = modele.echec {
            HStack(spacing: Jetons.Espace.un) {
                Text(L("chasse.echec", echec)).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.alerte))
                Spacer(minLength: 0)
                boutonEtapePrecedente
            }
        } else if let constat = modele.constat {
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                HStack(spacing: Jetons.Espace.un) {
                    Image(systemName: constat.direction.symbole).foregroundStyle(Color.jeton(\.encreSecondaire))
                    Text(constat.cible.nom(en: modele.langue))
                        .font(Jetons.Typo.petit.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    boutonEtapePrecedente
                    if case .trouve = constat.resultat {
                        Button {
                            modele.copier()
                            copie.signaler("trajet")
                        } label: {
                            IconeCopie(icone: "doc.on.doc", copie: copie.affiche("trajet"))
                                .foregroundStyle(Color.jeton(\.encreSecondaire))
                        }
                        .buttonStyle(.bouton(.tertiaire, dense: true))
                        .aide(L("chasse.copier"))
                    }
                }
                Group {
                    switch constat.resultat {
                    case .trouve(let x, let y, let distance):
                        Text(L("chasse.trouve", nombre: distance, Coordonnees.texte(x, y), distance)).font(Jetons.Typo.corpsFort.police)
                    case .introuvable:
                        Text(L("chasse.introuvable", EtapeChasse.portee)).foregroundStyle(Color.jeton(\.alerte))
                    case .phorreur:
                        Text(L("chasse.phorreur.suivre", constat.direction.libelle))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Jetons.Espace.deux)
            .carte(rayon: Jetons.Rayon.controle)
        }
    }

    private var boutonEtapePrecedente: some View {
        Button { modele.etapePrecedente() } label: { Image(systemName: "arrow.uturn.backward") }
            .buttonStyle(.bouton(.tertiaire, dense: true))
            .disabled(!modele.etapePrecedenteDisponible)
            .aide(L("chasse.etape.precedente"))
    }
}
