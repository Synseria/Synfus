import SwiftUI

/// La racine du panneau de chasse : la vue de l'instance du perso devant —
/// chaque perso a la sienne (`Chasses`), refaite quand le perso devant change.
struct ChasseRacine: View {
    @ObservedObject private var chasses = Chasses.shared

    var body: some View {
        ChasseVue(modele: chasses.courant)
            .id(chasses.perso ?? "")
    }
}

/// Le panneau de chasse, au style du panneau de quêtes : transparent, un
/// en-tête par lequel on le déplace. Une seule colonne, aussi étroite que la
/// boussole le permet, pour masquer le moins de jeu possible : la boussole 3×3
/// (X et Y en haut, « Lire » au centre, horloge et maison en bas), puis
/// l'indice et le résultat dessous.
struct ChasseVue: View {
    @ObservedObject var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    // periphery:ignore - observé : la position du perso devant, pour le cadre de la position
    @ObservedObject private var lecteur = LecteurEcran.shared
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
                        boussole.frame(maxWidth: .infinity)
                        if !previews.authorized { LigneAutorisation() }
                        indice
                        rienLu
                        resultat
                    }
                    .padding(Jetons.espace1)
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
        // Le trajet copié tout seul à la validation d'une étape : la coche
        // verte du bouton un instant, puis il redevient le bouton copier.
        .onChange(of: modele.trajetCopie) { _, oui in if oui { copie.signaler("trajet") } }
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

    // MARK: - Historique (horloge)

    /// Le bouton horloge, à gauche des coordonnées de départ : un menu popup
    /// des étapes validées **de la chasse en cours** (avec leur carte atteinte),
    /// et celle en cours en dessous. Style `menuIcone` de la trousse : fond au
    /// survol, curseur main — on voit que c'est cliquable. Rien d'autre en haut.
    private var menuHorloge: some View {
        Menu {
            ForEach(Array(modele.etapesValidees.reversed().enumerated()), id: \.offset) { _, reprise in
                Button {
                    modele.rouvrir(reprise)
                } label: {
                    Label {
                        Text("\(reprise.direction.libelle) — \(reprise.cible.nom(en: modele.langue))\(reprise.cibleAtteinte.map { " \(Coordonnees.texte($0.x, $0.y))" } ?? "")")
                    } icon: {
                        // Jalon validé : une couleur, comme le pin jaune du jeu — jamais blanc.
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.jeton(\.accent))
                    }
                }
            }
            if let courant = modele.constat {
                Divider()
                Label {
                    Text("\(L("chasse.historique.encours")) : \(courant.direction.libelle) — \(courant.cible.nom(en: modele.langue))")
                } icon: {
                    // Jalon pas encore saisi : le pin blanc du jeu.
                    Image(systemName: "mappin").foregroundStyle(Color.jeton(\.encre))
                }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(Jetons.typoSection.font)
        }
        .menuIcone()
        .frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
        .help(L("chasse.historique"))
    }

    // MARK: - Boussole

    // MARK: - Boussole

    /// Nord en haut, ouest à gauche… et « Lire » au centre : l'indice lu à
    /// l'écran, grisé tant que l'autorisation manque.
    /// La boussole 3×3 : **X en haut à gauche, Y en haut à droite**, « Lire » au
    /// centre, l'**historique (horloge) en bas à gauche** et le **trajet vers le
    /// départ (maison) en bas à droite** — chaque bouton du même format que les flèches.
    private var boussole: some View {
        let position = lecteur.positionDuPersoDevant
        let bonX = modele.departX.flatMap { x in position.map { $0.x == x } }
        let bonY = modele.departY.flatMap { y in position.map { $0.y == y } }
        return Grid(horizontalSpacing: Jetons.espace1, verticalSpacing: Jetons.espace1) {
            GridRow {
                ChampNombre(axe: "X", valeur: $modele.departX, bon: bonX)
                fleche(.nord)
                ChampNombre(axe: "Y", valeur: $modele.departY, bon: bonY)
            }
            GridRow {
                fleche(.ouest)
                centre
                fleche(.est)
            }
            GridRow {
                menuHorloge
                fleche(.sud)
                boutonMaison
            }
        }
    }

    /// La maison, en bas à droite de la boussole : copie le trajet
    /// (`/zaap` / `/travel`) vers la zone de départ — même format que les flèches.
    private var boutonMaison: some View {
        Button { modele.copierTrajetDepart() } label: {
            Image(systemName: "house")
                .font(Jetons.typoSection.font)
                .frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
        }
        .buttonStyle(.etat(choisi: false))
        .disabled(!modele.departConnu)
        .aide(L("chasse.depart.trajet"))
    }

    private func fleche(_ direction: Direction) -> some View {
        let choisie = modele.direction == direction
        // La direction lue sûrement par le scan passe en accent, au-dessus du choisi.
        let lue = modele.directionLue == direction
        return Button { modele.choisir(direction) } label: {
            let icone = Image(systemName: direction.symbole)
                .font(Jetons.typoSection.font)
                .frame(width: Jetons.hauteurRangee, height: Jetons.hauteurRangee)
            Group { if lue { icone.foregroundStyle(Color.jeton(\.accentTexte)) } else { icone } }
        }
        .buttonStyle(.etat(choisi: choisie))
        .disabled(modele.enAttenteDesIndices)
        .aide(lue ? L("chasse.direction.lue", direction.libelle) : direction.libelle)
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
            // puis l'indice. L'indice lu par le scan y est, encadré d'accent.
            TextField(L("chasse.indice"), text: $modele.saisie, prompt: Text(modele.attente.libelle))
                .textFieldStyle(.roundedBorder)
                .disabled(modele.enAttenteDesIndices)
                .overlay {
                    if modele.cibleLue, modele.cible != nil {
                        RoundedRectangle(cornerRadius: Jetons.rayon1, style: .circular)
                            .strokeBorder(Color.jeton(\.accent), lineWidth: Jetons.epaisseurFocus)
                    }
                }
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

    // MARK: - Rien de lu

    /// Le dernier scan n'a rien reconnu : le geste qui règle la lecture. Les
    /// indices lus ne s'affichent plus en liste — le scan choisit celui de la
    /// ligne fléchée, et le champ permet d'en taper un autre.
    @ViewBuilder
    private var rienLu: some View {
        if modele.rienLu {
            HStack(spacing: Jetons.espace1) {
                Text(L("chasse.rienLu")).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                Button(L("lecture.ouvrir")) { SettingsWindowController.shared.show(section: .lecture) }
                    .buttonStyle(BoutonBorde())
                    .help(L("chasse.lire.aide"))
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
                            // La coche verte dit « copié » un instant — le bouton revient ensuite.
                            IconeCopie(icone: "doc.on.doc", copie: copie.affiche("trajet"))
                                .foregroundStyle(copie.affiche("trajet")
                                                 ? Color.jeton(\.accentTexte) : Color.jeton(\.encre2))
                        }
                        .buttonStyle(BoutonTertiaire())
                        .aide(L("chasse.copier"))
                    }
                }
                Group {
                    switch constat.resultat {
                    case .trouve(let x, let y, let distance):
                        HStack(spacing: Jetons.espace1) {
                            // Sur la carte visée : la coche « arrivé » — validez dans le jeu.
                            if let p = lecteur.positionDuPersoDevant, p.x == x, p.y == y {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.jeton(\.accentTexte))
                                    .help(L("chasse.arrive"))
                            }
                            Text(L("chasse.trouve", nombre: distance, Coordonnees.texte(x, y), distance)).font(Jetons.typoTitreCarte.font)
                        }
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
