import SwiftUI

/// Les quêtes épinglées : un en-tête d'une ligne (le menu des quêtes et du
/// suivi lu à l'écran), puis les ressources à réunir, l'étape en cours
/// (consigne, objectifs, récompenses) et les quêtes qui s'ouvrent ensuite. Un
/// clic sur une ressource copie son nom (pour l'hôtel de vente), sur un
/// objectif situé son trajet, zaap compris — et le coche. Les objectifs
/// faits se replient en une ligne ; au survol d'un objectif, la vue de sa
/// carte en grand. Tailles : `MetriquesQuete`.
struct QueteVue: View {
    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var lecture = LectureSuivi.shared
    /// La ligne qui vient d'être copiée, le temps de le dire.
    @State private var copiee: String?
    @State private var guideEnCours = false
    /// Les quêtes dont les objectifs faits sont dépliés, le temps de la session.
    @State private var faitsDeplies: Set<Int> = []
    /// Une fiche donnée (captures de la documentation) ; `nil` : celles du panneau.
    var ficheImposee: FicheQuete?
    /// L'étape montrée et les objectifs cochés de la fiche donnée.
    var etapeImposee = 0
    var validesImposes: Set<Int> = []

    private var fiche: FicheQuete? {
        ficheImposee ?? panneau.idMontre.flatMap { store.fiche($0) }
    }

    private var metriques: MetriquesQuete { .pour(compact: prefs.quetesCompact) }

    /// La colonne des coches, que la ligne des faits repliés partage.
    private static let colonneCoche: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            enTete
            Divider()
            if let fiche {
                ScrollView {
                    VStack(alignment: .leading, spacing: metriques.ecartSections) {
                        entete(fiche)
                        let ressources = fiche.ressources.filter { !(prefs.quetesMasquerObjets && $0.objetDeQuete) }
                        if !ressources.isEmpty { self.ressources(ressources) }
                        if !fiche.etapes.isEmpty { etape(fiche) }
                        if !fiche.suivantes.isEmpty { suivantes(fiche) }
                    }
                    .padding(metriques.marge)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    /// la désépingler et cacher le panneau. L'espace libre déplace le panneau
    /// (`EnTetePanneau`).
    private var enTete: some View {
        let montree = ficheImposee?.id ?? panneau.idMontre
        return EnTetePanneau(icone: "scroll", teinte: Couleurs.accent) {
            menuQuetes(titre: ficheImposee?.nom ?? montree.flatMap { store.nom($0) } ?? L("quete.menu.titre"))
            if lecture.etat == .enCours { ProgressView().controlSize(.mini).padding(.leading, 4) }
        } boutons: {
            if let montree {
                BoutonEnTete(icone: "xmark", aide: L("quete.desepingler")) { QuetePanel.shared.desepingler(montree) }
            }
            BoutonEnTete(icone: "minus", aide: L("quete.fermer")) { QuetePanel.shared.fermer() }
        }
    }

    /// Le nom de la quête montrée, ▾ : le menu (`QuetePanel.menu`). Une
    /// pastille y compte les quêtes du suivi que le panneau n'a pas encore.
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
        .overlay { if ficheImposee == nil { DeclencheurMenu { QuetePanel.shared.menu() } } }
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
            }
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
        let garde = etape.objectifs.first { Self.idLigne($0) == copiee }?.id
        let (aFaire, faits) = Self.repli(etape.objectifs, valides: coches, garde: garde)
        return VStack(alignment: .leading, spacing: metriques.ecartLignes) {
            if plusieurs {
                HStack(spacing: 6) {
                    Button { changerEtape(fiche, rang - 1) } label: { Image(systemName: "chevron.left") }
                        .disabled(rang == 0)
                        .help(L("quete.etapePrecedente"))
                    titreSection(L("quete.etapeSur", rang + 1, fiche.etapes.count, etape.nom))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button { changerEtape(fiche, rang + 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(rang >= fiche.etapes.count - 1)
                        .help(L("quete.etapeSuivante"))
                }
                .buttonStyle(.borderless)
            } else {
                titreSection(L("quete.objectifs"))
            }
            if prefs.quetesConsigne, let description = etape.description {
                Text(description)
                    .font(.system(size: metriques.consigne))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }
            ForEach(aFaire, id: \.id) { objectif in
                ligneObjectif(objectif, quete: fiche.id, valide: coches.contains(objectif.id))
            }
            if !faits.isEmpty {
                ligneFaits(faits.count, quete: fiche.id)
                if faitsDeplies.contains(fiche.id) {
                    ForEach(faits, id: \.id) { objectif in
                        ligneObjectif(objectif, quete: fiche.id, valide: true)
                    }
                }
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
                    Button { changerEtape(fiche, rang + 1) } label: {
                        Label(L("quete.etapeSuivante"), systemImage: "chevron.right")
                            .labelStyle(TitreAvantIcone())
                    }
                    .controlSize(.small)
                }
                .padding(.top, metriques.ecartLignes)
            }
        }
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

    /// Les objectifs à faire, dans leur ordre, et les faits, repliés sous une
    /// ligne. `garde`, l'objectif qui vient d'être copié — et coché —, reste à
    /// sa place le temps de le dire.
    static func repli(_ objectifs: [FicheQuete.Objectif], valides: Set<Int>,
                      garde: Int?) -> (aFaire: [FicheQuete.Objectif], faits: [FicheQuete.Objectif]) {
        let aFaire = objectifs.filter { !valides.contains($0.id) || $0.id == garde }
        let faits = objectifs.filter { valides.contains($0.id) && $0.id != garde }
        return (aFaire, faits)
    }

    private static func idLigne(_ objectif: FicheQuete.Objectif) -> String { "objectif:\(objectif.id)" }

    /// La coche, puis le texte, et dessous sa position : toujours là, c'est
    /// ce qu'on vient chercher. Un objectif situé copie son trajet et se
    /// coche ; la coche seule se décoche. La vue de la carte paraît en grand
    /// au survol de la ligne, en vignette avec `quetesVignettes`.
    private func ligneObjectif(_ objectif: FicheQuete.Objectif, quete: Int, valide: Bool) -> some View {
        let id = Self.idLigne(objectif)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Button { QuetePanel.shared.cocher(objectif.id, de: quete, !valide) } label: {
                Image(systemName: valide ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: metriques.coche))
                    .foregroundStyle(valide ? Couleurs.accent : Color.secondary)
                    .frame(width: Self.colonneCoche)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            let action: (() -> Void)? = objectif.position.map { position in
                {
                    ZaapClipboard.shared.copierTrajet(vers: (position.x, position.y))
                    QuetePanel.shared.cocher(objectif.id, de: quete, true)
                    signaler(id)
                }
            }
            ligneCopiable(id: id, aide: L("quete.copierTrajet"), action: action) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(objectif.texte)
                        .font(.system(size: metriques.texte))
                        .foregroundStyle(valide ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if let position = objectif.position {
                            detail(id: id, Coordonnees.texte(position.x, position.y), monospace: true)
                        } else {
                            detail(id: id, L("quete.nonSitue"), monospace: false)
                        }
                        Spacer(minLength: 0)
                        if prefs.quetesVignettes, let carte = objectif.carte {
                            MiniatureCarte(carte: carte, taille: metriques.vignette, agrandir: false)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Sur la ligne entière, coche comprise : le bouton d'un objectif non
        // situé est désactivé, et n'aurait pas de survol.
        .apercuCarteAuSurvol(objectif.carte)
    }

    /// « ✓ 3 faits › » : un clic déplie ou replie les objectifs faits.
    private func ligneFaits(_ nombre: Int, quete: Int) -> some View {
        let deplies = faitsDeplies.contains(quete)
        return Button {
            if deplies { faitsDeplies.remove(quete) } else { faitsDeplies.insert(quete) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: metriques.coche))
                    .foregroundStyle(Couleurs.accent)
                    .frame(width: Self.colonneCoche)
                HStack(spacing: 4) {
                    Text(L("quete.faits", nombre: nombre, nombre)).font(.system(size: metriques.texte))
                    Image(systemName: deplies ? "chevron.down" : "chevron.right")
                        .font(.system(size: metriques.icone, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, metriques.ligneHorizontale)
                Spacer(minLength: 0)
            }
            .padding(.vertical, metriques.ligneVerticale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
