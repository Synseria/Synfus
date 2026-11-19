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
        // L'en-tête sur le verre, le contenu sur une plaque pleine.
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            entete
            Group {
                if indicesIndisponibles {
                    indisponibles
                } else {
                    VStack(alignment: .leading, spacing: Jetons.espace2) {
                        depart
                        boussole.frame(maxWidth: .infinity)
                        if !previews.authorized { LigneAutorisation() }
                        indice
                        lus
                        resultat
                    }
                    .padding(.vertical, Jetons.espace2)
                    .padding(.horizontal, Jetons.espace1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plaquePleine()
        }
        .padding([.horizontal, .bottom], Jetons.espace2)
        .padding(.top, Jetons.espace1)
        .frame(width: Jetons.largeurPanneauChasse, alignment: .leading)
        .font(Jetons.typoMeta.font)
        .surfaceFlottante()
    }

    private var entete: some View {
        EnTetePanneau(icone: BoutonBarre.chasse.symbole, teinte: Color.jeton(\.accentTexte)) {
            Text(L("chasse.titre")).font(Jetons.typoTitreCarte.font)
                .padding(.horizontal, Jetons.espace1)
                .padding(.vertical, Jetons.espace1)
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
        EtatVide(L("chasse.indices.indisponibles"), symbole: "exclamationmark.circle", ton: .danger) {
            Button { Task { await modele.chargerIndices(forcer: true) } } label: {
                Label(L("commun.reessayer"), systemImage: "arrow.clockwise")
            }
        }
        .frame(minHeight: Jetons.hauteurRangee * 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Départ

    /// Les coordonnées de départ, centrées sous l'en-tête, avec la position du personnage à reprendre.
    private var depart: some View {
        HStack(spacing: Jetons.espace1) {
            Image(systemName: "flag").foregroundStyle(Color.jeton(\.encre2))
                .help(L("chasse.depart"))
            TextField("x", value: $modele.departX, format: .number.grouping(.never), prompt: Text("x"))
                .frame(width: 52)
            TextField("y", value: $modele.departY, format: .number.grouping(.never), prompt: Text("y"))
                .frame(width: 52)
            Button { modele.reprendrePosition() } label: { Image(systemName: "location") }
                .buttonStyle(BoutonTertiaire())
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
        Grid(horizontalSpacing: Jetons.espace1, verticalSpacing: Jetons.espace1) {
            GridRow {
                Color.clear.frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
                fleche(.nord)
                Color.clear.frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
            }
            GridRow {
                fleche(.ouest)
                centre
                fleche(.est)
            }
            GridRow {
                Color.clear.frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
                fleche(.sud)
                Color.clear.frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
            }
        }
    }

    private func fleche(_ direction: Direction) -> some View {
        let choisie = modele.direction == direction
        return Button { modele.choisir(direction) } label: {
            Image(systemName: direction.symbole)
                .font(Jetons.typoSection.font)
                .frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
        }
        .buttonStyle(.etat(choisi: choisie))
        .disabled(modele.enAttenteDesIndices)
        .aide(direction.libelle)
    }

    private var centre: some View {
        Button { modele.lire() } label: {
            Image(systemName: "text.viewfinder")
                .font(Jetons.typoSection.font)
                .frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
        }
        .buttonStyle(.etat(courant: true))
        .disabled(!previews.authorized || modele.lectureEnCours || modele.indices.isEmpty)
        .aide(L("chasse.lire.aide"))
    }

    // MARK: - Indice

    private var indice: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
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
                        .padding(.horizontal, Jetons.espace1)
                        .padding(.vertical, Jetons.espace1)
                }
                .buttonStyle(.etat(nue: true))
            }
        }
    }

    // MARK: - Indices lus

    /// Les indices lus à l'écran, à choisir d'un clic.
    private var lus: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            if modele.rienLu {
                HStack(spacing: Jetons.espace1) {
                    Text(L("chasse.rienLu")).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                    Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                        .buttonStyle(BoutonBorde())
                        .help(L("chasse.lire.aide"))
                }
            }
            ForEach(modele.lues, id: \.self) { cible in
                Button { modele.choisir(cible) } label: {
                    Text(cible.nom(en: modele.langue))
                        .font(Jetons.typoMeta.font)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Jetons.espace1)
                        .padding(.vertical, Jetons.espace1)
                }
                .buttonStyle(.etat(choisi: modele.cible == cible, nue: true))
            }
        }
    }

    // MARK: - Résultat

    @ViewBuilder
    private var resultat: some View {
        if let echec = modele.echec {
            HStack(spacing: Jetons.espace1) {
                Text(L("chasse.echec", echec)).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.danger))
                Spacer(minLength: 0)
                boutonEtapePrecedente
            }
        } else if let constat = modele.constat {
            VStack(alignment: .leading, spacing: Jetons.espace1) {
                HStack(spacing: Jetons.espace1) {
                    Image(systemName: constat.direction.symbole).foregroundStyle(Color.jeton(\.encre2))
                    Text(constat.cible.nom(en: modele.langue))
                        .font(Jetons.typoMeta.font)
                        .foregroundStyle(Color.jeton(\.encre2))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    boutonEtapePrecedente
                    if case .trouve = constat.resultat {
                        Button {
                            modele.copier()
                            copie.signaler("trajet")
                        } label: {
                            IconeCopie(icone: "doc.on.doc", copie: copie.affiche("trajet"))
                                .foregroundStyle(Color.jeton(\.encre2))
                        }
                        .buttonStyle(BoutonTertiaire())
                        .aide(L("chasse.copier"))
                    }
                }
                Group {
                    switch constat.resultat {
                    case .trouve(let x, let y, let distance):
                        Text(L("chasse.trouve", nombre: distance, Coordonnees.texte(x, y), distance)).font(Jetons.typoTitreCarte.font)
                    case .introuvable:
                        Text(L("chasse.introuvable", EtapeChasse.portee)).foregroundStyle(Color.jeton(\.danger))
                    case .phorreur:
                        Text(L("chasse.phorreur.suivre", constat.direction.libelle))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .carte(marge: Jetons.espace2)
        }
    }

    private var boutonEtapePrecedente: some View {
        Button { modele.etapePrecedente() } label: { Image(systemName: "arrow.uturn.backward") }
            .buttonStyle(BoutonTertiaire())
            .disabled(!modele.etapePrecedenteDisponible)
            .aide(L("chasse.etape.precedente"))
    }
}
