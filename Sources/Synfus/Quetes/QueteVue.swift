import SwiftUI

/// Les quêtes épinglées : un en-tête d'une ligne (le menu des quêtes et du
/// suivi lu à l'écran), puis les ressources à réunir, l'étape en cours
/// (consigne, objectifs, récompenses) et les quêtes qui s'ouvrent ensuite. Un
/// clic sur une ressource copie son nom (pour l'hôtel de vente), sur un
/// objectif son trajet, zaap compris — et le met en cours ; seule la coche le
/// valide. Un objectif fait reste à sa place, grisé, sur une ligne ; au
/// survol d'un objectif, la vue de sa carte en grand. Une ressource, un
/// monstre ou un objet cité se déplient sur où les trouver (`OuTrouverVue`).
/// Tailles : `MetriquesQuete`.
struct QueteVue: View {
    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var lecture = LectureSuivi.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    /// Les cartes intérieures, venues après la carte.
    @ObservedObject private var cartes = CarteStore.shared
    /// La ligne qui vient d'être copiée, le temps de le dire.
    @State private var copiee: String?
    @State private var guideEnCours = false
    /// Les lignes dépliées sur où trouver leur objet ou leur monstre.
    @State private var deplies: Set<OuTrouver.Sujet> = []
    /// Incrémenté pour ramener la fiche en haut (« Étape suivante » en pied).
    @State private var remontees = 0
    /// Une fiche donnée (captures de la documentation) ; `nil` : celles du panneau.
    var ficheImposee: FicheQuete?
    /// L'étape montrée et les objectifs cochés de la fiche donnée.
    var etapeImposee = 0
    var validesImposes: Set<Int> = []

    private var fiche: FicheQuete? {
        ficheImposee ?? panneau.idMontre.flatMap { store.fiche($0) }
    }

    private var metriques: MetriquesQuete { .pour(compact: prefs.quetesCompact) }

    /// La colonne des coches.
    private static let colonneCoche: CGFloat = 18
    /// Le repère du haut de la fiche, où elle revient.
    private static let haut = "haut"
    /// Le trait au bord d'un objectif que le suivi du jeu montre à faire.
    private static let traitAFaire: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            enTete
            Divider()
            if let fiche {
                // Une autre quête, ou l'étape suivante prise en pied : la fiche
                // repart du haut, sans quoi elle s'ouvre là où l'autre défilait.
                ScrollViewReader { defilement in
                    ScrollView {
                        VStack(alignment: .leading, spacing: metriques.ecartSections) {
                            entete(fiche).id(Self.haut)
                            let ressources = fiche.ressources.filter { !(prefs.quetesMasquerObjets && $0.objetDeQuete) }
                            if !ressources.isEmpty { self.ressources(ressources) }
                            if !fiche.etapes.isEmpty { etape(fiche) }
                            if !fiche.suivantes.isEmpty { suivantes(fiche) }
                        }
                        .padding(metriques.marge)
                        .padding(.bottom, Jetons.Espace.deux)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: fiche.id) { defilement.scrollTo(Self.haut, anchor: .top) }
                    .onChange(of: remontees) { defilement.scrollTo(Self.haut, anchor: .top) }
                }
            } else {
                vide
            }
        }
        .frame(minWidth: QuetePanel.tailleMinimale.width, maxWidth: .infinity,
               minHeight: QuetePanel.tailleMinimale.height, maxHeight: .infinity, alignment: .top)
        .surfaceFlottante()
        .bordsRedimensionnables(coin: poignee)
    }

    /// Sans quête épinglée : celles que le suivi du jeu montre, à épingler
    /// d'un clic, et où en chercher une autre. Quêtes indisponibles : le nom,
    /// et de quoi réessayer.
    private var vide: some View {
        VStack(spacing: Jetons.Espace.deux) {
            if store.quetes == nil, !store.chargement, store.echec != nil {
                Text(L("quete.indisponible"))
                    .font(Jetons.Typo.note.police)
                    .foregroundStyle(Color.jeton(\.alerte))
                    .multilineTextAlignment(.center)
                Button(L("quete.reessayer")) { Task { try? await store.mettreAJour() } }
            } else {
                Text(store.chargement ? L("palette.quetes.chargement") : L("quete.aucune"))
                    .font(Jetons.Typo.note.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .multilineTextAlignment(.center)
                    .help(L("quete.aucune.aide"))
                let lues = lecture.reconnues.compactMap { reconnue in store.nom(reconnue.id).map { (reconnue, $0) } }
                if !lues.isEmpty {
                    Text(L("quete.vide.suivi")).font(Jetons.Typo.raccourci.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    ForEach(lues, id: \.0.id) { reconnue, nom in
                        Button { lecture.choisir(reconnue) } label: { Label(nom, systemImage: "pin") }
                            .buttonStyle(.bouton(.tertiaire, dense: true))
                    }
                }
            }
            Button(L("quete.chercher")) {
                PalettePanel.shared.ouvrir()
                PaletteModele.shared.requete = "/quete "
            }
            .buttonStyle(.bouton(.principal, dense: true))
        }
        .padding(Jetons.Espace.quatre)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Le coin bas droit, à saisir pour agrandir le panneau.
    private var poignee: some View {
        Image(systemName: "arrow.down.right")
            .font(Jetons.Typo.micro.police)
            .foregroundStyle(Color.jeton(\.encreTertiaire))
            .frame(width: Jetons.Taille.touche, height: Jetons.Taille.touche)
            .padding(Jetons.Espace.un)
    }

    // MARK: - En-tête du panneau

    /// Le menu des quêtes au nom de la montrée, seul endroit où il paraît, puis de quoi
    /// la désépingler et cacher le panneau. Tout l'en-tête déplace le panneau,
    /// sauf les boutons ; un clic sur le titre ouvre le menu (`EnTetePanneau`).
    private var enTete: some View {
        let montree = ficheImposee?.id ?? panneau.idMontre
        return EnTetePanneau(icone: "scroll", teinte: Color.jeton(\.primaire),
                             menu: ficheImposee == nil ? { @MainActor in QuetePanel.shared.menu() } : nil) {
            menuQuetes(titre: ficheImposee?.nom ?? montree.flatMap { store.nom($0) } ?? L("quete.menu.titre"))
            if lecture.etat == .enCours { ProgressView().controlSize(.mini).padding(.leading, Jetons.Espace.un) }
        } boutons: {
            if let montree {
                BoutonEnTete(icone: "pin.slash", aide: L("quete.desepingler")) { QuetePanel.shared.desepingler(montree) }
            }
            BoutonEnTete(icone: "minus", aide: L("quete.fermer")) { QuetePanel.shared.fermer() }
        }
    }

    /// Le nom de la quête montrée, ▾ : le menu (`QuetePanel.menu`, ouvert par
    /// `EnTetePanneau`). Une pastille y compte les quêtes du suivi que le
    /// panneau n'a pas encore.
    private func menuQuetes(titre: String) -> some View {
        let nouvelles = MenuQuetes.nouvelles(lecture.reconnues, epinglees: prefs.quetesEpinglees)
        return HStack(spacing: Jetons.Espace.un) {
            Text(titre).font(metriques.titreFort.police).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                .help(titre)
            Image(systemName: "chevron.down").font(Jetons.Typo.micro.police).foregroundStyle(Color.jeton(\.encreSecondaire))
            if nouvelles > 0, ficheImposee == nil {
                Text("\(nouvelles)")
                    .font(Jetons.Typo.micro.police)
                    .foregroundStyle(Color.jeton(\.encreSurPrimaire))
                    .padding(.horizontal, Jetons.Espace.un)
                    .background(Capsule().fill(Color.jeton(\.primaire)))
                    .help(L("quete.menu.nouvelles"))
            }
        }
        .padding(.horizontal, Jetons.Espace.un)
        .padding(.vertical, Jetons.Espace.un)
        .background(RoundedRectangle(cornerRadius: Jetons.Rayon.controle).fill(Color.jeton(\.creux)))
    }

    // MARK: - En-tête

    /// Le niveau et le guide, sur deux lignes quand le panneau est trop étroit
    /// pour une, sous les étiquettes. Le nom est au titre du panneau.
    private func entete(_ fiche: FicheQuete) -> some View {
        let niveau = Text(L("quete.niveau", nombre: fiche.etapes.count, fiche.niveau, fiche.etapes.count))
        return VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            if fiche.groupe || fiche.donjon {
                HStack(spacing: Jetons.Espace.un) { badges(fiche) }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Jetons.Espace.un) {
                    niveau
                    Spacer(minLength: Jetons.Espace.un)
                    boutonGuide(fiche)
                }
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    niveau
                    boutonGuide(fiche)
                }
            }
            .font(metriques.detail.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            if let exigences = Self.exigences(fiche.exigences, classes: ClassesStore.shared.catalogue) {
                Label(L("quete.exigences", exigences), systemImage: "lock")
                    .font(metriques.detail.police)
                    .foregroundStyle(Color.jeton(\.safranTexte))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Sortie du suivi du jeu entre deux lectures (`HistoriqueSuivi`) :
            // finie, sans doute, mais seul le joueur le sait.
            if ficheImposee == nil, lecture.terminees.contains(fiche.id) {
                Button { QuetePanel.shared.desepingler(fiche.id) } label: {
                    Label(L("quete.terminee"), systemImage: "flag.checkered")
                }
                .buttonStyle(.bouton(.secondaire, dense: true))
                .help(L("quete.terminee.aide"))
            }
        }
    }

    @ViewBuilder
    private func badges(_ fiche: FicheQuete) -> some View {
        if fiche.groupe { badge(L("quete.groupe"), icone: "person.3") }
        if fiche.donjon { badge(L("quete.donjon"), icone: "building.columns") }
    }

    private func boutonGuide(_ fiche: FicheQuete) -> some View {
        Button {
            guideEnCours = true
            Task {
                await DofusPourLesNoobs.ouvrir(fiche.nomFrancais)
                guideEnCours = false
            }
        } label: {
            HStack(spacing: Jetons.Espace.un) {
                if guideEnCours { ProgressView().controlSize(.mini) }
                Text(L("quete.guide"))
                Image(systemName: "arrow.up.right.square")
            }
        }
        .buttonStyle(.bouton(.tertiaire, dense: true))
        .disabled(guideEnCours)
    }

    /// « Roublard · dès le niveau 110 · Alchimiste niveau 80 · Bontarien, alignement 20 ».
    static func exigences(_ exigences: [FicheQuete.Exigence], classes: DofusClass.Catalogue) -> String? {
        let parties = exigences.compactMap { exigence -> String? in
            switch exigence {
            case .classe(let id): return classes.breed(idDofusDB: id)?.nomLocalise ?? "#\(id)"
            case .niveau(let niveau): return L("quete.exigence.niveau", niveau)
            case .metier(let nom, let niveau): return L("quete.exigence.metier", nom, niveau)
            case .alignement(let camp?, let niveau?): return L("quete.exigence.alignement", camp, niveau)
            case .alignement(let camp?, nil): return camp
            case .alignement(nil, let niveau?): return L("quete.exigence.alignementSeul", niveau)
            case .alignement(nil, nil): return nil
            }
        }
        return parties.isEmpty ? nil : parties.joined(separator: " · ")
    }

    private func badge(_ texte: String, icone: String) -> some View {
        Label(texte, systemImage: icone)
            .font(metriques.detail.police)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Jetons.Espace.un)
            .padding(.vertical, Jetons.Espace.un)
            .background(Capsule().fill(Color.jeton(\.safranFond)))
            .foregroundStyle(Color.jeton(\.safranTexte))
    }

    // MARK: - Ressources

    private func ressources(_ ressources: [FicheQuete.Ressource]) -> some View {
        VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            HStack {
                titreSection(L("quete.ressources"))
                Spacer()
                Button(copiee == "ressources" ? L("quete.copie") : L("quete.toutCopier")) {
                    copier(ressources.map { L("quete.ressource", $0.nom, $0.quantite) }.joined(separator: ", "),
                           ligne: "ressources")
                }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .font(metriques.detail.police)
            }
            ForEach(Array(ressources.enumerated()), id: \.offset) { indice, ressource in
                let id = "ressource:\(indice)"
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ligneCopiable(id: id, aide: L("quete.copierNom"), action: { copier(ressource.nom, ligne: id) }) {
                        HStack(alignment: .firstTextBaseline, spacing: Jetons.Espace.un) {
                            Image(systemName: copiee == id ? "checkmark" : "shippingbox")
                                .font(metriques.icone.police)
                                .foregroundStyle(copiee == id ? Color.jeton(\.primaireEncre) : Color.jeton(\.encreSecondaire))
                                .frame(width: Jetons.Taille.case)
                            // Le nom d'abord : à l'étroit, c'est la catégorie qui se tronque.
                            Text(L("quete.ressource", ressource.nom, ressource.quantite))
                                .font(metriques.texte.police)
                                .layoutPriority(1)
                            Spacer(minLength: Jetons.Espace.un)
                            detail(id: id, ressource.categorie, monospace: false)
                        }
                    }
                    deplier(.objet(ressource.objet))
                }
                ouTrouver(.objet(ressource.objet), retrait: 14 + 6)
            }
        }
    }

    // MARK: - Où trouver

    /// Le chevron qui déplie, sous la ligne, où trouver l'objet ou le monstre.
    private func deplier(_ sujet: OuTrouver.Sujet) -> some View {
        let deplie = deplies.contains(sujet)
        return Button {
            if deplie { deplies.remove(sujet) } else { deplies.insert(sujet) }
        } label: {
            Image(systemName: deplie ? "chevron.down" : "chevron.right")
                .font(metriques.icone.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .frame(width: Jetons.Espace.quatre)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .aide(sujet.estUnMonstre ? L("ouTrouver.aide.monstre") : L("ouTrouver.aide.objet"))
    }

    /// `retrait` : sous le texte de la ligne, pas sous son icône.
    @ViewBuilder
    private func ouTrouver(_ sujet: OuTrouver.Sujet, retrait: CGFloat) -> some View {
        if deplies.contains(sujet) {
            // Un autre sujet à la même place (autre quête) : une autre vue, qui
            // fait sa demande en paraissant.
            OuTrouverVue(sujet: sujet, metriques: metriques)
                .id(sujet)
                .padding(.leading, retrait + metriques.ligneHorizontale)
                .padding(.trailing, metriques.ligneHorizontale)
                .padding(.bottom, metriques.ligneVerticale)
        }
    }

    // MARK: - Étape

    /// L'étape en cours. Plusieurs : ‹ › en tête, « Étape suivante » en pied ;
    /// le panneau s'en souvient d'une ouverture à l'autre.
    private func etape(_ fiche: FicheQuete) -> some View {
        let plusieurs = fiche.etapes.count > 1
        let rang = min(rangEtape(fiche), fiche.etapes.count - 1)
        let etape = fiche.etapes[rang]
        let coches = valides(fiche.id)
        let ici = lecteur.positionDuPersoDevant.map { PNJ.Position(x: $0.x, y: $0.y) }
        let enCours = ficheImposee == nil ? prefs.quetesEnCours[String(fiche.id)] : nil
        // Le suivi du perso devant, lu tout à l'heure : ce que le jeu montre.
        let lu = ficheImposee == nil ? lecture.reconnue(fiche.id) : nil
        let suggeres = ficheImposee == nil ? etape.suggeres(en: ici, valides: coches, enCours: enCours,
                                                                  combatFini: lecteur.combatFiniDevant, lu: lu) : []
        let aFaire = Set(lu?.aFaire ?? [])
        let nonOuverts = etape.nonOuverts(valides: coches, lu: lu)
        let lus = ficheImposee == nil
            ? lecture.historique.persos(fiche.id, etape: rang, seule: !plusieurs, maintenant: Date()) : []
        let tournee = ficheImposee == nil
            ? Self.tournee(etape, aFaire: aFaire, valides: coches, reseau: CarteStore.shared.reseau) : []
        let numeros = Dictionary(uniqueKeysWithValues: tournee.enumerated().map { ($1, $0 + 1) })
        return VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            if plusieurs {
                HStack(spacing: Jetons.Espace.un) {
                    Button { changerEtape(fiche, rang - 1) } label: { Image(systemName: "chevron.left") }
                        .disabled(rang == 0)
                        .aide(L("quete.etapePrecedente"))
                    titreSection(etape.nom == fiche.nom ? L("quete.etape", rang + 1, fiche.etapes.count)
                                                        : L("quete.etapeSur", rang + 1, fiche.etapes.count, etape.nom))
                        .lineLimit(1)
                        .help(etape.nom)
                    persosLus(lus)
                    Spacer(minLength: 0)
                    Button { changerEtape(fiche, rang + 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(rang >= fiche.etapes.count - 1)
                        .aide(L("quete.etapeSuivante"))
                }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .tint(Color.jeton(\.encreSecondaire))
            } else {
                HStack(spacing: Jetons.Espace.un) {
                    titreSection(L("quete.objectifs"))
                    persosLus(lus)
                }
            }
            if prefs.quetesConsigne, let description = etape.description {
                Text(description)
                    .font(metriques.consigne.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Jetons.Espace.un)
            }
            let coordonnees = CoordonneesObjectifs.affichees(etape.objectifs)
            ForEach(etape.objectifs, id: \.id) { objectif in
                ligneObjectif(objectif, quete: fiche.id, coordonnee: coordonnees.contains(objectif.id),
                              etat: .init(valide: coches.contains(objectif.id), suggere: suggeres.contains(objectif.id),
                                          enCours: enCours == objectif.id, aFaire: aFaire.contains(objectif.id),
                                          nonOuvert: nonOuverts.contains(objectif.id), numero: numeros[objectif.id]))
            }
            if let premier = etape.objectifs.first(where: { $0.id == tournee.first }) {
                Button { copierTrajet(premier, quete: fiche.id) } label: {
                    Label(L("quete.tournee"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .buttonStyle(.bouton(.secondaire, dense: true))
                .help(L("quete.tournee.aide"))
            }
            if !etape.recompenses.vides {
                Text(L("quete.recompenses", Self.recompenses(etape.recompenses)))
                    .font(metriques.detail.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, metriques.ecartLignes)
            }
            if plusieurs, rang < fiche.etapes.count - 1 {
                etapeSuivante(fiche, rang: rang, achevee: etape.objectifs.allSatisfy { coches.contains($0.id) })
            }
        }
    }

    /// « Étape suivante », en pied ; en avant quand tous les objectifs de
    /// l'étape sont cochés.
    @ViewBuilder
    private func etapeSuivante(_ fiche: FicheQuete, rang: Int, achevee: Bool) -> some View {
        let bouton = Button {
            changerEtape(fiche, rang + 1)
            remontees += 1
        } label: {
            Label(L("quete.etapeSuivante"), systemImage: "chevron.right")
                .labelStyle(TitreAvantIcone())
        }
        HStack {
            Spacer()
            bouton.buttonStyle(.bouton(achevee ? .principal : .secondaire, dense: true))
        }
        .padding(.top, metriques.ecartLignes)
    }

    /// Combien de persos leur suivi du jeu montre à cette étape ; au survol,
    /// lesquels et quand. Jamais tiré des coches, communes à tous les persos.
    @ViewBuilder
    private func persosLus(_ lus: [HistoriqueSuivi.EtapeLue]) -> some View {
        if !lus.isEmpty {
            let maintenant = Date()
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: "person.fill")
                Text("\(lus.count)")
            }
            .font(metriques.detailFort.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .fixedSize()
            .help(L("quete.persos", nombre: lus.count, lus.count,
                    lus.map { Self.lu($0, maintenant: maintenant) }.joined(separator: "\n")))
        }
    }

    /// « Aeryn — lu il y a 5 min ».
    static func lu(_ lue: HistoriqueSuivi.EtapeLue, maintenant: Date) -> String {
        let minutes = Int(maintenant.timeIntervalSince(lue.date) / 60)
        if minutes < 1 { return L("quete.persos.luALInstant", lue.perso) }
        if minutes < 60 { return L("quete.persos.lu", lue.perso, minutes) }
        return L("quete.persos.luHeures", lue.perso, minutes / 60)
    }

    /// « 4 377 903 XP (niveau 177) · 1 200 kamas · Vaccin × 1 · émote Pierre ».
    static func recompenses(_ recompenses: FicheQuete.Recompenses) -> String {
        var parties: [String] = []
        if recompenses.experience > 0 {
            parties.append(L("quete.recompense.xp", recompenses.experience.formatted(), recompenses.niveau))
        }
        if recompenses.kamas > 0 { parties.append(L("quete.recompense.kamas", recompenses.kamas.formatted())) }
        parties += recompenses.objets.map { L("quete.ressource", $0.nom, $0.quantite) }
        parties += recompenses.emotes.map { L("quete.recompense.emote", $0) }
        parties += recompenses.titres.map { L("quete.recompense.titre", $0) }
        return parties.joined(separator: " · ")
    }

    private static func idLigne(_ objectif: FicheQuete.Objectif) -> String { "objectif:\(objectif.id)" }

    /// Les objectifs que le suivi montre ouverts ensemble, situés, dans l'ordre
    /// le plus court depuis le perso (`ZaapClipboard.tournee`) : le suivi
    /// n'affiche que les objectifs ouverts, plusieurs à la fois se font dans
    /// n'importe quel ordre. Un seul : rien à ordonner. Hors du Monde des
    /// Douze, aucun coût ne se compte : ceux-là restent hors de l'ordre.
    private static func tournee(_ etape: FicheQuete.Etape, aFaire: Set<Int>, valides: Set<Int>,
                                reseau: ReseauSousZones) -> [Int] {
        let ouverts = etape.objectifs.compactMap { objectif -> (id: Int, x: Int, y: Int, sousZone: Int?)? in
            guard aFaire.contains(objectif.id), !valides.contains(objectif.id), let position = objectif.position,
                  !reseau.horsDesDouze(objectif.sousZone)
            else { return nil }
            return (objectif.id, position.x, position.y, objectif.sousZone)
        }
        guard ouverts.count > 1 else { return [] }
        return ZaapClipboard.shared.tournee(ouverts) ?? []
    }

    /// Copie le trajet de l'objectif, zaap compris, et le met en cours. Sans
    /// case, celui du repaire le plus proche du monstre qu'il cite.
    private func copierTrajet(_ objectif: FicheQuete.Objectif, quete: Int) {
        let id = Self.idLigne(objectif)
        if let position = objectif.position {
            ZaapClipboard.shared.copierTrajet(vers: (position.x, position.y), sousZone: objectif.sousZone,
                                              dansLesDouze: !CarteStore.shared.reseau.horsDesDouze(objectif.sousZone))
            signaler(id)
        } else if case .monstre(let monstre)? = objectif.sujet {
            // Rien qui le situe, ou DofusDB muet : un bip plutôt que rien.
            Task { if await OuTrouverStore.shared.copierLePlusProche(monstre: monstre) { signaler(id) } else { NSSound.beep() } }
        }
        prefs.mettreEnCours(objectif.id, de: quete)
    }

    private static func aide(_ objectif: FicheQuete.Objectif) -> String {
        if objectif.position != nil { return L("quete.copierTrajet") }
        if objectif.sujet?.estUnMonstre == true { return L("quete.copierTrajetMonstre") }
        return L("quete.enCours.aide")
    }

    /// Ce qu'on sait d'un objectif, du plus sûr au moins sûr : fait (coche
    /// verte), le perso sur sa carte (`suggere`, coche violette qui propose
    /// de valider), en cours (le dernier dont on a copié le trajet : coche en
    /// cible, texte appuyé), encore à faire d'après le suivi du jeu lu tout à
    /// l'heure (`aFaire`, trait et fond ambre), ou tu par ce suivi lu en
    /// entier (`nonOuvert` : pas encore ouvert, en retrait). Fait, il n'est
    /// rien d'autre. `numero` : son rang dans le plus court chemin des
    /// objectifs ouverts ensemble (`tournee`).
    private struct EtatObjectif {
        let valide: Bool
        let suggere: Bool
        let enCours: Bool
        let aFaire: Bool
        let nonOuvert: Bool
        var numero: Int?

        var icone: String {
            valide ? "checkmark.circle.fill" : suggere ? "location.circle.fill"
                : enCours ? "smallcircle.filled.circle" : nonOuvert ? "circle.dashed" : "circle"
        }

        @MainActor var teinte: Color {
            valide ? Color.jeton(\.primaire) : suggere ? Color.jeton(\.suggestionSynfus) : enCours ? Color.jeton(\.encre) : Color.jeton(\.encreSecondaire)
        }
    }

    /// La coche, puis le texte, et dessous sa position quand elle diffère de celle de l'objectif
    /// d'avant (`CoordonneesObjectifs`). Un clic sur la ligne copie toujours le trajet et met
    /// l'objectif en cours ; seule la coche valide ou dévalide. Fait, il reste
    /// à sa place — l'ordre de la quête ne bouge pas — sur une ligne grisée,
    /// sans sa position, une fois le « Copié » passé. La vue de la carte paraît
    /// en grand au survol de la ligne, en vignette avec `quetesVignettes`.
    private func ligneObjectif(_ objectif: FicheQuete.Objectif, quete: Int, coordonnee: Bool, etat: EtatObjectif) -> some View {
        let id = Self.idLigne(objectif)
        let valide = etat.valide, suggere = etat.suggere && !valide
        let replie = valide && copiee != id
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Jetons.Espace.un) {
                Button { prefs.cocher(objectif.id, de: quete, !valide) } label: {
                    Image(systemName: etat.icone)
                        .font(metriques.coche.police)
                        .foregroundStyle(etat.teinte)
                        .frame(width: Self.colonneCoche)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(objectif.texte)
                .accessibilityAddTraits(valide ? .isSelected : [])
                .help(suggere ? (objectif.combat ? L("quete.suggestion.combat.aide") : L("quete.suggestion.aide"))
                    : etat.aFaire && !valide ? L("quete.aFaire.aide")
                    : etat.nonOuvert && !valide ? L("quete.nonOuvert.aide") : "")
                // Fait et sans trajet, la ligne n'a plus rien à faire.
                let action: (() -> Void)? = valide && objectif.position == nil ? nil : { copierTrajet(objectif, quete: quete) }
                ligneCopiable(id: id, aide: Self.aide(objectif), action: action) {
                    VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                        texteObjectif(objectif, etat: etat, replie: replie)
                        if !replie {
                            HStack(spacing: Jetons.Espace.un) {
                                if let numero = etat.numero, !valide {
                                    Text(L("quete.ordre", numero))
                                        .font(metriques.detailFort.police)
                                        .foregroundStyle(Color.jeton(\.safranTexte))
                                }
                                if let position = objectif.position {
                                    // Masquée, la ligne garde son « Copié » : le texte est vide, la voix de l'état reste.
                                    detail(id: id, coordonnee ? Coordonnees.texte(position.x, position.y) : nil, monospace: true)
                                    if cartes.interieurs.contient(objectif.carte), copiee != id {
                                        EtiquetteInterieur(taille: metriques.detail)
                                    }
                                    if suggere, copiee != id {
                                        Text(L("quete.suggestion"))
                                            .font(metriques.detailFort.police)
                                            .foregroundStyle(Color.jeton(\.suggestionSynfus))
                                    }
                                } else {
                                    detail(id: id, L("quete.nonSitue"), monospace: false)
                                }
                                if etat.nonOuvert, !valide, copiee != id {
                                    Text(L("quete.nonOuvert"))
                                        .font(metriques.detail.police)
                                        .foregroundStyle(Color.jeton(\.encreTertiaire))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if prefs.quetesVignettes, let carte = objectif.carte {
                                    MiniatureCarte(carte: carte, taille: metriques.vignette, agrandir: false)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let sujet = objectif.sujet, !replie { deplier(sujet) }
            }
            .background {
                if etat.aFaire, !valide {
                    RoundedRectangle(cornerRadius: Jetons.Rayon.controle)
                        .fill(Color.jeton(\.safranFond))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.jeton(\.safran)).frame(width: Self.traitAFaire).padding(.vertical, Jetons.Espace.un)
                        }
                }
            }
            // Sur la ligne entière, coche comprise : le bouton d'une ligne faite
            // et non située est désactivé, et n'aurait pas de survol.
            .apercuCarteAuSurvol(objectif.carte)
            if let sujet = objectif.sujet, !replie { ouTrouver(sujet, retrait: Self.colonneCoche + 2) }
        }
    }

    /// Le texte d'un objectif : sur une ligne grisée une fois fait, appuyé quand il est en cours.
    @ViewBuilder
    private func texteObjectif(_ objectif: FicheQuete.Objectif, etat: EtatObjectif, replie: Bool) -> some View {
        if replie {
            Text(objectif.texte)
                .font(metriques.texte.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(objectif.texte)
                .font((etat.enCours && !etat.valide ? metriques.texteFort : metriques.texte).police)
                .foregroundStyle(etat.valide || etat.nonOuvert ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encre))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func valides(_ quete: Int) -> Set<Int> {
        ficheImposee == nil ? Set(prefs.quetesValides[String(quete)] ?? []) : validesImposes
    }

    private func rangEtape(_ fiche: FicheQuete) -> Int {
        ficheImposee == nil ? prefs.quetesEtape[String(fiche.id)] ?? 0 : etapeImposee
    }

    private func changerEtape(_ fiche: FicheQuete, _ rang: Int) {
        guard ficheImposee == nil else { return }
        prefs.quetesEtape[String(fiche.id)] = max(rang, 0)
    }

    // MARK: - Suivantes

    /// Les quêtes que celle-ci ouvre : un clic l'épingle et la montre.
    private func suivantes(_ fiche: FicheQuete) -> some View {
        VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            titreSection(L("quete.suivantes"))
            ForEach(fiche.suivantes, id: \.id) { suivante in
                ligneCopiable(id: "suivante:\(suivante.id)", aide: nil, action: { QuetePanel.shared.ouvrir(suivante.id) }) {
                    HStack(alignment: .firstTextBaseline, spacing: Jetons.Espace.un) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(metriques.icone.police)
                            .foregroundStyle(Color.jeton(\.encreSecondaire))
                            .frame(width: Jetons.Taille.case)
                        Text(suivante.nom).font(metriques.texte.police).layoutPriority(1)
                        Spacer(minLength: Jetons.Espace.un)
                        detail(id: "suivante:\(suivante.id)", L("quete.niveauCourt", suivante.niveau), monospace: false)
                    }
                }
            }
        }
    }

    // MARK: - Lignes

    private func titreSection(_ texte: String) -> some View {
        Text(texte)
            .font(metriques.detailFort.police)
            .foregroundStyle(Color.jeton(\.encreSecondaire))
    }

    /// Le détail d'une ligne, en petit et en gris, ou « Copié » le temps de
    /// le dire. Sur une ligne, il se tronque avant le texte principal.
    @ViewBuilder
    private func detail(id: String, _ texte: String?, monospace: Bool) -> some View {
        if copiee == id {
            Text(L("quete.copie")).font(metriques.detailFort.police).foregroundStyle(Color.jeton(\.primaireEncre))
        } else if let texte {
            Text(texte)
                .font((monospace ? Jetons.Typo.codeInterface : metriques.detail).police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .lineLimit(1)
        }
    }

    /// Une ligne ; cliquable quand elle fait quelque chose.
    private func ligneCopiable(id: String, aide: String?, action: (() -> Void)?,
                               @ViewBuilder contenu: () -> some View) -> some View {
        Button { action?() } label: {
            contenu()
                .padding(.horizontal, metriques.ligneHorizontale)
                .padding(.vertical, metriques.ligneVerticale)
        }
        .buttonStyle(.etat(choisi: copiee == id, nue: true))
        .disabled(action == nil)
        .help(action == nil ? "" : aide ?? "")
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

/// Le texte puis l'icône : « Étape suivante › ».
private struct TitreAvantIcone: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Jetons.Espace.un) {
            configuration.title
            configuration.icon
        }
    }
}
