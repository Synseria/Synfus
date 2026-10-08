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
                        .padding(.bottom, 8)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .bordsRedimensionnables(coin: poignee)
    }

    /// Sans quête épinglée : où en trouver une.
    private var vide: some View {
        VStack(spacing: 10) {
            Text(store.chargement ? L("palette.quetes.chargement") : L("quete.aucune"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("quete.chercher")) {
                PalettePanel.shared.ouvrir()
                PaletteModele.shared.requete = "/quete "
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Le coin bas droit, à saisir pour agrandir le panneau.
    private var poignee: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.tertiary)
            .frame(width: 18, height: 18)
            .padding(2)
    }

    // MARK: - En-tête du panneau

    /// Une seule ligne : le menu des quêtes au nom de la montrée, puis de quoi
    /// la désépingler et cacher le panneau. Tout l'en-tête déplace le panneau,
    /// sauf les boutons ; un clic sur le titre ouvre le menu (`EnTetePanneau`).
    private var enTete: some View {
        let montree = ficheImposee?.id ?? panneau.idMontre
        return EnTetePanneau(icone: "scroll", teinte: Couleurs.accent,
                             menu: ficheImposee == nil ? { @MainActor in QuetePanel.shared.menu() } : nil) {
            menuQuetes(titre: ficheImposee?.nom ?? montree.flatMap { store.nom($0) } ?? L("quete.menu.titre"))
            if lecture.etat == .enCours { ProgressView().controlSize(.mini).padding(.leading, 4) }
        } boutons: {
            if let montree {
                BoutonEnTete(icone: "xmark", aide: L("quete.desepingler")) { QuetePanel.shared.desepingler(montree) }
            }
            BoutonEnTete(icone: "minus", aide: L("quete.fermer")) { QuetePanel.shared.fermer() }
        }
    }

    /// Le nom de la quête montrée, ▾ : le menu (`QuetePanel.menu`, ouvert par
    /// `EnTetePanneau`). Une pastille y compte les quêtes du suivi que le
    /// panneau n'a pas encore.
    private func menuQuetes(titre: String) -> some View {
        let nouvelles = MenuQuetes.nouvelles(lecture.reconnues, epinglees: prefs.quetesEpinglees)
        return HStack(spacing: 4) {
            Text(titre).font(.system(size: metriques.texte, weight: .semibold)).lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            if nouvelles > 0, ficheImposee == nil {
                Text("\(nouvelles)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Couleurs.accent))
                    .help(L("quete.menu.nouvelles"))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
    }

    // MARK: - En-tête

    /// Le nom et ses étiquettes, puis le niveau et le guide : chaque paire
    /// passe sur deux lignes quand le panneau est trop étroit pour une.
    private func entete(_ fiche: FicheQuete) -> some View {
        let nom = Text(fiche.nom)
            .font(.system(size: metriques.titre, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
        let niveau = Text(L("quete.niveau", nombre: fiche.etapes.count, fiche.niveau, fiche.etapes.count))
        return VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            if fiche.groupe || fiche.donjon {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        nom
                        Spacer(minLength: 4)
                        badges(fiche)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        nom
                        HStack(spacing: 4) { badges(fiche) }
                    }
                }
            } else {
                nom
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    niveau
                    Spacer(minLength: 4)
                    boutonGuide(fiche)
                }
                VStack(alignment: .leading, spacing: 2) {
                    niveau
                    boutonGuide(fiche)
                }
            }
            .font(.system(size: metriques.detail))
            .foregroundStyle(.secondary)
            if let exigences = Self.exigences(fiche.exigences, classes: ClassesStore.shared.catalogue) {
                Label(L("quete.exigences", exigences), systemImage: "lock")
                    .font(.system(size: metriques.detail))
                    .foregroundStyle(Couleurs.ambre)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Sortie du suivi du jeu entre deux lectures (`HistoriqueSuivi`) :
            // finie, sans doute, mais seul le joueur le sait.
            if ficheImposee == nil, lecture.terminees.contains(fiche.id) {
                Button { QuetePanel.shared.desepingler(fiche.id) } label: {
                    Label(L("quete.terminee"), systemImage: "flag.checkered")
                }
                .controlSize(.small)
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
            HStack(spacing: 3) {
                if guideEnCours { ProgressView().controlSize(.mini) }
                Text(L("quete.guide"))
                Image(systemName: "arrow.up.right.square")
            }
        }
        .buttonStyle(.borderless)
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
            .font(.system(size: metriques.detail))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Couleurs.ambre.opacity(0.25)))
            .foregroundStyle(Couleurs.ambre)
    }

    // MARK: - Ressources

    private func ressources(_ ressources: [FicheQuete.Ressource]) -> some View {
        VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            HStack {
                titreSection(L("quete.ressources"))
                Spacer()
                Button(L("quete.toutCopier")) {
                    copier(ressources.map { L("quete.ressource", $0.nom, $0.quantite) }.joined(separator: ", "),
                           ligne: "ressources")
                }
                .buttonStyle(.borderless)
                .font(.system(size: metriques.detail))
            }
            ForEach(Array(ressources.enumerated()), id: \.offset) { indice, ressource in
                let id = "ressource:\(indice)"
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ligneCopiable(id: id, aide: L("quete.copierNom"), action: { copier(ressource.nom, ligne: id) }) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: copiee == id ? "checkmark" : "shippingbox")
                                .font(.system(size: metriques.icone))
                                .foregroundStyle(copiee == id ? Couleurs.accent : Color.secondary)
                                .frame(width: 14)
                            // Le nom d'abord : à l'étroit, c'est la catégorie qui se tronque.
                            Text(L("quete.ressource", ressource.nom, ressource.quantite))
                                .font(.system(size: metriques.texte))
                                .layoutPriority(1)
                            Spacer(minLength: 4)
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
                .font(.system(size: metriques.icone, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(sujet.estUnMonstre ? L("ouTrouver.aide.monstre") : L("ouTrouver.aide.objet"))
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
        let suggeres = ficheImposee == nil ? etape.suggeres(en: ici, valides: coches, enCours: enCours,
                                                                  combatFini: lecteur.combatFiniDevant) : []
        let aFaire = ficheImposee == nil ? lecture.aFaire(fiche.id) : []
        let lus = ficheImposee == nil
            ? lecture.historique.persos(fiche.id, etape: rang, seule: !plusieurs, maintenant: Date()) : []
        let tournee = ficheImposee == nil ? Self.tournee(etape, aFaire: aFaire, valides: coches) : []
        let numeros = Dictionary(uniqueKeysWithValues: tournee.enumerated().map { ($1, $0 + 1) })
        return VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            if plusieurs {
                HStack(spacing: 6) {
                    Button { changerEtape(fiche, rang - 1) } label: { Image(systemName: "chevron.left") }
                        .disabled(rang == 0)
                        .help(L("quete.etapePrecedente"))
                    titreSection(L("quete.etapeSur", rang + 1, fiche.etapes.count, etape.nom))
                        .lineLimit(1)
                    persosLus(lus)
                    Spacer(minLength: 0)
                    Button { changerEtape(fiche, rang + 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(rang >= fiche.etapes.count - 1)
                        .help(L("quete.etapeSuivante"))
                }
                .buttonStyle(.borderless)
            } else {
                HStack(spacing: 6) {
                    titreSection(L("quete.objectifs"))
                    persosLus(lus)
                }
            }
            if prefs.quetesConsigne, let description = etape.description {
                Text(description)
                    .font(.system(size: metriques.consigne))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }
            ForEach(etape.objectifs, id: \.id) { objectif in
                ligneObjectif(objectif, quete: fiche.id,
                              etat: .init(valide: coches.contains(objectif.id), suggere: suggeres.contains(objectif.id),
                                          enCours: enCours == objectif.id, aFaire: aFaire.contains(objectif.id),
                                          numero: numeros[objectif.id]))
            }
            if let premier = etape.objectifs.first(where: { $0.id == tournee.first }) {
                Button { copierTrajet(premier, quete: fiche.id) } label: {
                    Label(L("quete.tournee"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .controlSize(.small)
                .help(L("quete.tournee.aide"))
            }
            if !etape.recompenses.vides {
                Text(L("quete.recompenses", Self.recompenses(etape.recompenses)))
                    .font(.system(size: metriques.detail))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, metriques.ecartLignes)
            }
            if plusieurs, rang < fiche.etapes.count - 1 {
                HStack {
                    Spacer()
                    Button {
                        changerEtape(fiche, rang + 1)
                        remontees += 1
                    } label: {
                        Label(L("quete.etapeSuivante"), systemImage: "chevron.right")
                            .labelStyle(TitreAvantIcone())
                    }
                    .controlSize(.small)
                }
                .padding(.top, metriques.ecartLignes)
            }
        }
    }

    /// Combien de persos leur suivi du jeu montre à cette étape ; au survol,
    /// lesquels et quand. Jamais tiré des coches, communes à tous les persos.
    @ViewBuilder
    private func persosLus(_ lus: [HistoriqueSuivi.EtapeLue]) -> some View {
        if !lus.isEmpty {
            let maintenant = Date()
            HStack(spacing: 1) {
                Image(systemName: "person.fill")
                Text("\(lus.count)")
            }
            .font(.system(size: metriques.detail, weight: .semibold))
            .foregroundStyle(.secondary)
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
    /// n'importe quel ordre. Un seul : rien à ordonner.
    private static func tournee(_ etape: FicheQuete.Etape, aFaire: Set<Int>, valides: Set<Int>) -> [Int] {
        let ouverts = etape.objectifs.compactMap { objectif -> (id: Int, x: Int, y: Int)? in
            guard aFaire.contains(objectif.id), !valides.contains(objectif.id), let position = objectif.position
            else { return nil }
            return (objectif.id, position.x, position.y)
        }
        guard ouverts.count > 1 else { return [] }
        return ZaapClipboard.shared.tournee(ouverts) ?? []
    }

    /// Copie le trajet de l'objectif, zaap compris, et le met en cours. Sans
    /// case, celui du repaire le plus proche du monstre qu'il cite.
    private func copierTrajet(_ objectif: FicheQuete.Objectif, quete: Int) {
        let id = Self.idLigne(objectif)
        if let position = objectif.position {
            ZaapClipboard.shared.copierTrajet(vers: (position.x, position.y))
            signaler(id)
        } else if case .monstre(let monstre)? = objectif.sujet {
            Task { if await OuTrouverStore.shared.copierLePlusProche(monstre: monstre) { signaler(id) } }
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
    /// l'heure (`aFaire`, trait et fond ambre). Fait, il n'est rien d'autre.
    /// `numero` : son rang dans le plus court chemin des objectifs ouverts
    /// ensemble (`tournee`).
    private struct EtatObjectif {
        let valide: Bool
        let suggere: Bool
        let enCours: Bool
        let aFaire: Bool
        var numero: Int?

        var icone: String {
            valide ? "checkmark.circle.fill" : suggere ? "location.circle.fill"
                : enCours ? "smallcircle.filled.circle" : "circle"
        }

        var teinte: Color {
            valide ? Couleurs.accent : suggere ? Couleurs.suggestion : enCours ? Color.primary : Color.secondary
        }
    }

    /// La coche, puis le texte, et dessous sa position : toujours là, c'est
    /// ce qu'on vient chercher. Un clic sur la ligne copie le trajet et met
    /// l'objectif en cours ; seule la coche valide ou dévalide. Fait, il reste
    /// à sa place — l'ordre de la quête ne bouge pas — sur une ligne grisée,
    /// sans sa position, une fois le « Copié » passé. La vue de la carte paraît
    /// en grand au survol de la ligne, en vignette avec `quetesVignettes`.
    private func ligneObjectif(_ objectif: FicheQuete.Objectif, quete: Int, etat: EtatObjectif) -> some View {
        let id = Self.idLigne(objectif)
        let valide = etat.valide, suggere = etat.suggere && !valide
        let replie = valide && copiee != id
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Button { prefs.cocher(objectif.id, de: quete, !valide) } label: {
                    Image(systemName: etat.icone)
                        .font(.system(size: metriques.coche))
                        .foregroundStyle(etat.teinte)
                        .frame(width: Self.colonneCoche)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(suggere ? (objectif.combat ? L("quete.suggestion.combat.aide") : L("quete.suggestion.aide"))
                    : etat.aFaire && !valide ? L("quete.aFaire.aide") : "")
                // Fait et sans trajet, la ligne n'a plus rien à faire.
                let action: (() -> Void)? = valide && objectif.position == nil ? nil : { copierTrajet(objectif, quete: quete) }
                ligneCopiable(id: id, aide: Self.aide(objectif), action: action) {
                    VStack(alignment: .leading, spacing: 1) {
                        if replie {
                            Text(objectif.texte)
                                .font(.system(size: metriques.texte))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text(objectif.texte)
                                .font(.system(size: metriques.texte, weight: etat.enCours && !valide ? .semibold : .regular))
                                .foregroundStyle(valide ? Color.secondary : Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !replie {
                            HStack(spacing: 6) {
                                if let numero = etat.numero, !valide {
                                    Text(L("quete.ordre", numero))
                                        .font(.system(size: metriques.detail, weight: .bold))
                                        .foregroundStyle(Couleurs.ambre)
                                }
                                if let position = objectif.position {
                                    detail(id: id, Coordonnees.texte(position.x, position.y), monospace: true)
                                    if suggere, copiee != id {
                                        Text(L("quete.suggestion"))
                                            .font(.system(size: metriques.detail, weight: .semibold))
                                            .foregroundStyle(Couleurs.suggestion)
                                    }
                                } else {
                                    detail(id: id, L("quete.nonSitue"), monospace: false)
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Couleurs.ambre.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Couleurs.ambre).frame(width: Self.traitAFaire).padding(.vertical, 2)
                        }
                }
            }
            // Sur la ligne entière, coche comprise : le bouton d'une ligne faite
            // et non située est désactivé, et n'aurait pas de survol.
            .apercuCarteAuSurvol(objectif.carte)
            if let sujet = objectif.sujet, !replie { ouTrouver(sujet, retrait: Self.colonneCoche + 2) }
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: metriques.icone))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(suivante.nom).font(.system(size: metriques.texte)).layoutPriority(1)
                        Spacer(minLength: 4)
                        detail(id: "suivante:\(suivante.id)", L("quete.niveauCourt", suivante.niveau), monospace: false)
                    }
                }
            }
        }
    }

    // MARK: - Lignes

    private func titreSection(_ texte: String) -> some View {
        Text(texte)
            .font(.system(size: metriques.detail, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Le détail d'une ligne, en petit et en gris, ou « Copié » le temps de
    /// le dire. Sur une ligne, il se tronque avant le texte principal.
    @ViewBuilder
    private func detail(id: String, _ texte: String?, monospace: Bool) -> some View {
        if copiee == id {
            Text(L("quete.copie")).font(.system(size: metriques.detail, weight: .semibold)).foregroundStyle(Couleurs.accent)
        } else if let texte {
            Text(texte)
                .font(.system(size: metriques.detail, design: monospace ? .monospaced : .default))
                .foregroundStyle(.secondary)
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
                .background(RoundedRectangle(cornerRadius: 6).fill(copiee == id ? Couleurs.accent.opacity(0.15) : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
