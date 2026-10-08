import SwiftUI

/// Les quêtes épinglées : un onglet par quête, le suivi du jeu lu à l'écran,
/// puis les ressources à réunir, l'étape en cours (consigne, objectifs,
/// récompenses) et les quêtes qui s'ouvrent ensuite. Un clic sur une ressource copie son nom (pour l'hôtel
/// de vente), sur un objectif situé son trajet, zaap compris — et le coche.
struct QueteVue: View {
    @ObservedObject private var panneau = QuetePanel.shared
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var lecture = LectureSuivi.shared
    /// La ligne qui vient d'être copiée, le temps de le dire.
    @State private var copiee: String?
    @State private var guideEnCours = false
    /// Une fiche donnée (captures de la documentation) ; `nil` : celles du panneau.
    var ficheImposee: FicheQuete?
    /// L'étape montrée et les objectifs cochés de la fiche donnée.
    var etapeImposee = 0
    var validesImposes: Set<Int> = []

    private var idMontre: Int? { panneau.montree ?? prefs.quetesEpinglees.last }

    private var fiche: FicheQuete? {
        ficheImposee ?? idMontre.flatMap { store.fiche($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            onglets
            Divider()
            if ficheImposee == nil {
                suivi
                Divider()
            }
            if let fiche {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        entete(fiche)
                        if !fiche.ressources.isEmpty { ressources(fiche) }
                        if !fiche.etapes.isEmpty { etape(fiche) }
                        if !fiche.suivantes.isEmpty { suivantes(fiche) }
                    }
                    .padding(12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                vide
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .overlay(alignment: .bottomTrailing) { poignee }
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
            .overlay(PoigneeRedimension())
            .padding(2)
    }

    // MARK: - Onglets

    /// Une pastille par quête épinglée, sur autant de lignes qu'il faut :
    /// tout le fond de la bande déplace le panneau (une liste qui défile
    /// garderait le glisser pour elle).
    private var onglets: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "scroll").foregroundStyle(Couleurs.accent).padding(.top, 3)
            RangeeQuiPasse(espacement: 4) {
                if let ficheImposee {
                    onglet(id: ficheImposee.id, nom: ficheImposee.nom, choisi: true)
                } else {
                    ForEach(prefs.quetesEpinglees, id: \.self) { id in
                        onglet(id: id, nom: store.nom(id) ?? "…", choisi: id == idMontre)
                    }
                }
            }
            Spacer(minLength: 0)
            Button { QuetePanel.shared.fermer() } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("quete.fermer"))
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    // MARK: - Suivi du jeu

    /// Le suivi de quêtes du jeu : le bouton qui le lit, puis les quêtes
    /// reconnues — un clic épingle et montre, à l'étape lue.
    private var suivi: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { LectureSuivi.shared.lire() } label: {
                HStack(spacing: 3) {
                    if lecture.etat == .enCours {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "text.viewfinder")
                    }
                    Text(L("quete.suivi.lire")).lineLimit(1)
                }
                .fixedSize()
            }
            .buttonStyle(.borderless)
            .disabled(lecture.etat == .enCours)
            .padding(.top, 2)
            if let message = messageSuivi {
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } else {
                RangeeQuiPasse(espacement: 4) {
                    ForEach(lecture.reconnues, id: \.id) { pastille($0) }
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var messageSuivi: String? {
        switch lecture.etat {
        case .jamaisLu, .enCours: return nil
        case .illisible: return L("quete.suivi.illisible")
        case .sansQuetes: return L("palette.quetes.chargement")
        case .lu: return lecture.reconnues.isEmpty ? L("quete.suivi.rien") : nil
        }
    }

    private func pastille(_ reconnue: SuiviQuetes.Reconnue) -> some View {
        let epinglee = prefs.quetesEpinglees.contains(reconnue.id)
        return Button { LectureSuivi.shared.choisir(reconnue) } label: {
            HStack(spacing: 3) {
                if epinglee { Image(systemName: "pin.fill").font(.system(size: 8)) }
                Text(store.nom(reconnue.id) ?? "…").lineLimit(1)
                if let etape = reconnue.etape {
                    Text(L("quete.suivi.etape", etape + 1)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Couleurs.accent.opacity(epinglee ? 0.08 : 0.18)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - En-tête

    private func entete(_ fiche: FicheQuete) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(fiche.nom).font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 4)
                if fiche.groupe { badge(L("quete.groupe"), icone: "person.3") }
                if fiche.donjon { badge(L("quete.donjon"), icone: "building.columns") }
            }
            HStack(spacing: 6) {
                Text(L("quete.niveau", nombre: fiche.etapes.count, fiche.niveau, fiche.etapes.count))
                Spacer(minLength: 4)
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
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    private func badge(_ texte: String, icone: String) -> some View {
        Label(texte, systemImage: icone)
            .font(.system(size: 10))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Couleurs.ambre.opacity(0.25)))
            .foregroundStyle(Couleurs.ambre)
    }

    // MARK: - Ressources

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
                let id = "ressource:\(indice)"
                ligneCopiable(id: id, aide: L("quete.copierNom"), action: { copier(ressource.nom, ligne: id) }) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: copiee == id ? "checkmark" : "shippingbox")
                            .font(.system(size: 10))
                            .foregroundStyle(copiee == id ? Couleurs.accent : Color.secondary)
                            .frame(width: 14)
                        Text(L("quete.ressource", ressource.nom, ressource.quantite)).font(.system(size: 12))
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
        return VStack(alignment: .leading, spacing: 4) {
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
            if let description = etape.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }
            ForEach(etape.objectifs, id: \.id) { objectif in
                ligneObjectif(objectif, quete: fiche.id)
            }
            if !etape.recompenses.vides {
                Text(L("quete.recompenses", Self.recompenses(etape.recompenses)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
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
                .padding(.top, 6)
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

    /// La coche, puis le texte : un objectif situé copie son trajet et se
    /// coche ; la coche seule se décoche.
    private func ligneObjectif(_ objectif: FicheQuete.Objectif, quete: Int) -> some View {
        let id = "objectif:\(objectif.id)"
        let valide = valides(quete).contains(objectif.id)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Button { QuetePanel.shared.cocher(objectif.id, de: quete, !valide) } label: {
                Image(systemName: valide ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(valide ? Couleurs.accent : Color.secondary)
                    .frame(width: 18)
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
                HStack(alignment: .center, spacing: 8) {
                    Text(objectif.texte)
                        .font(.system(size: 12))
                        .foregroundStyle(valide ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if let position = objectif.position {
                        detail(id: id, Coordonnees.texte(position.x, position.y), monospace: true)
                    } else {
                        detail(id: id, L("quete.nonSitue"), monospace: false)
                    }
                    if let carte = objectif.carte { MiniatureCarte(carte: carte) }
                }
            }
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
        VStack(alignment: .leading, spacing: 4) {
            titreSection(L("quete.suivantes"))
            ForEach(fiche.suivantes, id: \.id) { suivante in
                ligneCopiable(id: "suivante:\(suivante.id)", aide: nil, action: { QuetePanel.shared.ouvrir(suivante.id) }) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(suivante.nom).font(.system(size: 12))
                        Spacer(minLength: 4)
                        Text(L("quete.niveauCourt", suivante.niveau)).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Lignes

    private func titreSection(_ texte: String) -> some View {
        Text(texte)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Le détail à droite d'une ligne, ou « Copié » le temps de le dire.
    @ViewBuilder
    private func detail(id: String, _ texte: String?, monospace: Bool) -> some View {
        if copiee == id {
            Text(L("quete.copie")).font(.system(size: 10, weight: .semibold)).foregroundStyle(Couleurs.accent)
        } else if let texte {
            Text(texte)
                .font(.system(size: monospace ? 11 : 10, design: monospace ? .monospaced : .default))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    /// Une ligne ; cliquable quand elle fait quelque chose.
    private func ligneCopiable(id: String, aide: String?, action: (() -> Void)?,
                               @ViewBuilder contenu: () -> some View) -> some View {
        Button { action?() } label: {
            contenu()
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
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

/// La vue d'une carte en vignette ; au survol, en grand à côté du panneau.
/// `onHover` suit la souris sur un panneau jamais clé d'une app inactive
/// (ses zones de suivi sont actives en permanence, comme celles des pastilles
/// de la barre) — une bulle d'aide, elle, n'y apparaît pas.
private struct MiniatureCarte: View {
    let carte: Int

    var body: some View {
        ImageDofusDB(url: DofusDB.imageCarte(carte))
            .aspectRatio(contentMode: .fill)
            .frame(width: 52, height: 36)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .onHover { dedans in
                if dedans { ApercuCarte.shared.montrer(carte) } else { ApercuCarte.shared.cacher() }
            }
            .onDisappear { ApercuCarte.shared.cacher() }
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

/// Des vues côte à côte, qui passent à la ligne quand la largeur manque.
private struct RangeeQuiPasse: Layout {
    let espacement: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let lignes = disposer(subviews, largeur: proposal.width ?? .infinity)
        let largeur = lignes.map { $0.largeur }.max() ?? 0
        let hauteur = lignes.map(\.hauteur).reduce(0, +) + espacement * CGFloat(max(lignes.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, largeur) } ?? largeur, height: hauteur)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for ligne in disposer(subviews, largeur: bounds.width) {
            var x = bounds.minX
            for indice in ligne.indices {
                let taille = subviews[indice].sizeThatFits(.unspecified)
                let largeur = min(taille.width, bounds.width)
                subviews[indice].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: largeur, height: taille.height))
                x += largeur + espacement
            }
            y += ligne.hauteur + espacement
        }
    }

    private struct Ligne {
        var indices: [Int] = []
        var largeur: CGFloat = 0
        var hauteur: CGFloat = 0
    }

    private func disposer(_ subviews: Subviews, largeur maximale: CGFloat) -> [Ligne] {
        var lignes: [Ligne] = []
        var courante = Ligne()
        for indice in subviews.indices {
            let taille = subviews[indice].sizeThatFits(.unspecified)
            let largeur = min(taille.width, maximale)
            let ajout = courante.indices.isEmpty ? largeur : courante.largeur + espacement + largeur
            if !courante.indices.isEmpty, ajout > maximale {
                lignes.append(courante)
                courante = Ligne()
            }
            courante.largeur = courante.indices.isEmpty ? largeur : courante.largeur + espacement + largeur
            courante.hauteur = max(courante.hauteur, taille.height)
            courante.indices.append(indice)
        }
        if !courante.indices.isEmpty { lignes.append(courante) }
        return lignes
    }
}
