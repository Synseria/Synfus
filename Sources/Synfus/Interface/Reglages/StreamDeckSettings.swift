import SwiftUI

/// Onglet Stream Deck : la liaison, le miroir de l'appareil — composé par le
/// même code que ce qu'il affiche —, la disposition (générique ou propre à un
/// perso), les gestes, la détection de combat, l'installation.
struct StreamDeckSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var store = SpellProfileStore.shared
    @ObservedObject private var link = StreamDeckLink.shared
    @ObservedObject private var combat = CombatWatcher.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @State private var perso = ""
    @State private var message = ""

    private var grille: StreamDeckLink.Grille { link.grilles.sorted { $0.colonnes * $0.lignes > $1.colonnes * $1.lignes }.first ?? .defaut }
    private var classe: String? { manager.clients.first { $0.name == perso }?.characterClass ?? store.profiles[perso]?.classe }
    private var profile: SpellProfile { store.profile(for: perso, classe: classe) }
    private var specifique: Bool { store.profiles[perso]?.deck != nil }

    /// Le réglage en cours d'édition : celui du perso s'il en a un, le générique sinon.
    private var deck: Binding<DeckSettings> {
        Binding(
            get: { store.profiles[perso]?.deck ?? prefs.deck },
            set: { new in
                if specifique { var p = profile; p.deck = new; store.save(p) } else { prefs.deck = new }
            }
        )
    }

    var body: some View {
        Form {
            liaison
            // Tant que la liaison est coupée, rien d'autre n'a de sens : ni
            // disposition, ni gestes, ni combat — et l'onglet Sorts est masqué.
            if prefs.streamDeckEnabled {
                installation
                disposition
                gestes
                combatSection
            }
            if !message.isEmpty {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Sections

    private var liaison: some View {
        Section {
            Toggle("Utiliser un Stream Deck", isOn: $prefs.streamDeckEnabled)
            if !prefs.streamDeckEnabled {
                Text("Les sorts du perso devant sous les doigts, la frappe faite par le plugin Elgato. "
                     + "Active pour voir les réglages, installer le plugin et remplir les profils de sorts (onglet Sorts).")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if prefs.streamDeckEnabled {
                HStack {
                    Text(link.status).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text(link.grilles.map { "\($0.colonnes) × \($0.lignes)" }.sorted().joined(separator: ", "))
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
        } header: {
            SectionTitle("Stream Deck (optionnel)", help: "Ouvre un socket local, réservé à ton compte, sur lequel le plugin "
                         + "SynfusDeck reçoit ce que chaque touche montre et fait. Il ne peut demander que ce que "
                         + "fait la barre : perso suivant, précédent, barre suivante, menu. C'est le plugin qui "
                         + "frappe la touche du jeu ; Synfus n'émet jamais rien.\n\n" + StreamDeckLink.socketURL.path)
        }
    }

    private var disposition: some View {
        Section {
            HStack {
                PersoPicker(perso: $perso)
                Toggle("Réglage propre à ce perso", isOn: Binding(
                    get: { specifique },
                    set: { on in var p = profile; p.deck = on ? prefs.deck : nil; store.save(p) }
                ))
                .disabled(perso.isEmpty)
                Spacer()
            }
            Picker("Mode", selection: Binding(
                get: { deck.wrappedValue.kind },
                set: { kind in
                    var d = deck.wrappedValue
                    if kind == .personnalisee, d.custom == nil {
                        d.custom = d.layout(colonnes: grille.colonnes, lignes: grille.lignes, page: 0)
                    }
                    d.kind = kind
                    deck.wrappedValue = d
                    link.execute(DeckCommand(type: .barrePremiere))
                }
            )) {
                ForEach(DeckSettings.Kind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if deck.wrappedValue.kind != .personnalisee {
                HStack(alignment: .firstTextBaseline) {
                    Text("Appui long").frame(width: 90, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { deck.wrappedValue.sortLong },
                        set: { var d = deck.wrappedValue; d.sortLong = $0; deck.wrappedValue = d }
                    )) {
                        Text("rien").tag(SortLong.aucun)
                        Text(deck.wrappedValue.kind == .parRangee ? "long → 5 cases plus loin" : "long → barre suivante").tag(SortLong.unNiveau)
                        Text(deck.wrappedValue.kind == .parRangee ? "long → +5, très long → +10" : "long → barre 2, très long → barre 3").tag(SortLong.deuxNiveaux)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    HelpTip("Ce qu'une touche de sort joue quand on la tient. Avec deux niveaux, les trois barres "
                            + "tiennent sous dix touches : un appui court joue la barre affichée, tenu il passe à la "
                            + "suivante, tenu plus longtemps à celle d'après — les vignettes en bas à gauche et à "
                            + "droite de la touche montrent lesquels. Une case d'en face vide ne joue rien.")
                }
                HStack(alignment: .top) {
                    Text(deck.wrappedValue.kind == .parRangee ? "Pages" : "Barres").frame(width: 90, alignment: .leading)
                    PageChips(deck: deck, colonnes: grille.colonnes, lignes: grille.lignes) {
                        link.execute(DeckCommand(type: .barrePremiere))
                    }
                    HelpTip("Ce que « barre suivante » parcourt, dans cet ordre. Clique pour retirer ou remettre "
                            + "une page, glisse pour réordonner. Avec l'appui long à deux niveaux, une seule barre "
                            + "suffit souvent : les autres sont sous les doigts.")
                }
            } else {
                HStack(spacing: 8) {
                    Text("Repartir de :").font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("barre par barre") { setCustom(.parBarre(colonnes: grille.colonnes, lignes: grille.lignes, sortLong: deck.wrappedValue.sortLong)) }
                    Button("une barre par rangée") { setCustom(.parRangee(colonnes: grille.colonnes, lignes: grille.lignes, page: 0, sortLong: deck.wrappedValue.sortLong)) }
                    Spacer()
                    Text("Clique une touche pour la régler, glisse-la pour la déplacer.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                .font(.system(size: 11))
            }

            DeckMirror(page: link.previewPage(grille: grille, mode: deck.wrappedValue, perso: perso.isEmpty ? nil : perso, classe: classe),
                       layout: layoutBinding, profile: profile, commands: prefs.gameCommands)
            HStack(spacing: 8) {
                Button("Barre suivante") { link.execute(DeckCommand(type: .barreSuivante)) }
                Button("Première barre") { link.execute(DeckCommand(type: .barrePremiere)) }
                Button(link.menuOuvert ? "Fermer le menu" : "Menu") { link.execute(DeckCommand(type: .menu)) }
                if link.menuOuvert { Button("Page du menu") { link.execute(DeckCommand(type: .pageMenuSuivante)) } }
                Spacer()
                Text("Ces boutons font ce que les touches font : l'appareil suit.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
        } header: {
            SectionTitle("Disposition", help: "Ce que le Stream Deck montre, composé par Synfus — aucun profil à "
                         + "réimporter, le changement est immédiat. « Barre par barre » : une barre sur les touches, "
                         + "« barre suivante » passe à l'autre. « Une barre par rangée » : la barre 1 sur la première "
                         + "rangée, la 2 sur la seconde, par fenêtres de cinq cases. « Personnalisée » : n'importe "
                         + "quelle case de n'importe quelle barre sur n'importe quelle touche, une commande, trois "
                         + "niveaux d'appui. Générique pour tous les persos, ou propre à un perso (dans son profil).")
        }
    }

    private var gestes: some View {
        Section {
            HStack {
                Text("Appui long à partir de")
                Spacer()
                Stepper("\(prefs.appuiLongMs) ms", value: $prefs.appuiLongMs, in: 80...1000, step: 10)
                    .onChange(of: prefs.appuiLongMs) { _, v in if prefs.appuiTresLongMs <= v { prefs.appuiTresLongMs = v + 100 } }
            }
            HStack {
                Text("Appui très long à partir de")
                Spacer()
                Stepper("\(prefs.appuiTresLongMs) ms", value: $prefs.appuiTresLongMs, in: 120...2000, step: 10)
                    .onChange(of: prefs.appuiTresLongMs) { _, v in if prefs.appuiLongMs >= v { prefs.appuiLongMs = max(80, v - 100) } }
            }
            Toggle("Sélection progressive des sorts", isOn: $prefs.appuiProgressif)
            Toggle("Nom des sorts sous les icônes", isOn: $prefs.deckTitres)
        } header: {
            SectionTitle("Gestes", help: "Trois niveaux : court, long, très long. En sélection progressive, une "
                         + "touche de sort joue chaque niveau à son seuil, sans attendre le relâchement : le jeu "
                         + "montre le sort sélectionné — sa portée — pendant que tu tiens, et tu lâches quand c'est "
                         + "le bon ; la touche passe au bleu puis à l'orange pour dire où elle en est. Sans elle, le "
                         + "niveau atteint joue au relâchement. Les autres touches (perso, barre, commandes) jouent "
                         + "toujours au relâchement — deux actions d'affilée s'y contrediraient. Pas de double-clic : "
                         + "deux appuis sont deux frappes.")
        }
    }

    private var combatSection: some View {
        Section {
            HStack {
                Button("Référence en combat") { calibrate(true) }
                Button("Référence hors combat") { calibrate(false) }
                Spacer()
                Text(combat.calibrated ? combat.status : "non calibrée")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .disabled(!previews.authorized)
            if let reading = combat.lastReading {
                Text(String(format: "dernier relevé : combat %.2f · hors combat %.2f · %d ms",
                            reading.correlationCombat, reading.correlationHors, Int(combat.lastDuration * 1000)))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
        } header: {
            SectionTitle("Détection de combat", help: "La touche « fin de tour » s'allume en combat. Le jeu ne le "
                         + "dit pas : Synfus compare, une fois par seconde, la bande basse de la fenêtre à deux "
                         + "références que tu captures toi-même — une fois en combat, une fois hors combat, perso "
                         + "devant. Le coût du relevé s'affiche ici.")
        }
    }

    private var installation: some View {
        Section {
            HStack(spacing: 8) {
                Button("Installer le plugin et son profil…") { openBundled("fr.synseria.synfus", "streamDeckPlugin") }
                    .disabled(bundled("fr.synseria.synfus", "streamDeckPlugin") == nil)
                Button("Importer le profil 5 × 3 seul…") { openBundled("Synfus", "streamDeckProfile") }
                    .disabled(bundled("Synfus", "streamDeckProfile") == nil)
                Spacer()
            }
            .font(.system(size: 11))
            if bundled("fr.synseria.synfus", "streamDeckPlugin") == nil {
                Text("Ce build n'embarque pas le plugin — relance ./build.sh --install.")
                    .font(.system(size: 10)).foregroundStyle(.orange)
            }
        } header: {
            SectionTitle("Installation", help: "Le plugin et le profil « Synfus » (quinze touches Synfus, 5 × 3) "
                         + "sont embarqués dans l'app. « Installer » ouvre le paquet dans le logiciel Stream Deck, "
                         + "qui demande confirmation et enregistre le profil avec le plugin — c'est ce qui permet "
                         + "d'y basculer quand Dofus passe devant. « Importer le profil seul » l'ajoute à tes "
                         + "profils, à lier à Dofus dans le logiciel si tu préfères ne pas laisser Synfus basculer. "
                         + "Ensuite, Synfus compose tout : rien à réimporter.")
        }
    }

    // MARK: - Utilitaires

    /// La grille éditable — `nil` tant que le mode n'est pas personnalisé.
    private var layoutBinding: Binding<DeckLayout>? {
        guard deck.wrappedValue.kind == .personnalisee else { return nil }
        return Binding(
            get: { deck.wrappedValue.custom ?? .parBarre(colonnes: grille.colonnes, lignes: grille.lignes) },
            set: { setCustom($0) }
        )
    }

    private func setCustom(_ layout: DeckLayout) {
        var d = deck.wrappedValue
        d.custom = layout
        deck.wrappedValue = d
    }

    private func bundled(_ name: String, _ ext: String) -> URL? { Bundle.main.url(forResource: name, withExtension: ext) }

    private func openBundled(_ name: String, _ ext: String) {
        guard let url = bundled(name, ext) else { return }
        NSWorkspace.shared.open(url)
    }

    private func calibrate(_ enCombat: Bool) {
        Task { message = await CombatWatcher.shared.calibrate(enCombat: enCombat) }
    }
}

/// Les pages en pastilles : celles que « barre suivante » parcourt, numérotées
/// dans l'ordre, puis les écartées, grisées. Clic pour basculer, glisser pour
/// réordonner.
private struct PageChips: View {
    let deck: Binding<DeckSettings>
    let colonnes: Int
    let lignes: Int
    let onChange: () -> Void

    var body: some View {
        let d = deck.wrappedValue
        let all = d.allPages(colonnes: colonnes, lignes: lignes)
        let order = d.pageOrder(colonnes: colonnes, lignes: lignes)
        let out = all.filter { !order.contains($0) }
        FlowLayout(spacing: 6) {
            ForEach(Array(order.enumerated()), id: \.element) { rank, page in
                chip(label: d.pageLabel(page, colonnes: colonnes, lignes: lignes), rank: rank + 1, active: true)
                    .onTapGesture { if order.count > 1 { set(order.filter { $0 != page }) } }
                    .draggable("\(page)")
                    .dropDestination(for: String.self) { items, _ in
                        guard let from = items.first.flatMap(Int.init), let i = order.firstIndex(of: from), from != page else { return false }
                        var o = order
                        o.remove(at: i)
                        o.insert(from, at: o.firstIndex(of: page) ?? o.endIndex)
                        set(o)
                        return true
                    }
                    .help("Clique pour retirer, glisse pour réordonner")
            }
            ForEach(out, id: \.self) { page in
                chip(label: d.pageLabel(page, colonnes: colonnes, lignes: lignes), rank: nil, active: false)
                    .onTapGesture { set(order + [page]) }
                    .help("Clique pour remettre en fin de parcours")
            }
        }
    }

    private func chip(label: String, rank: Int?, active: Bool) -> some View {
        HStack(spacing: 5) {
            if let rank {
                Text("\(rank)").font(.system(size: 9, weight: .bold, design: .rounded))
                    .frame(width: 15, height: 15).background(Circle().fill(Color.accentColor)).foregroundStyle(.white)
            } else {
                Image(systemName: "plus").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(label).font(.system(size: 11))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(active ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05)))
        .overlay(Capsule().strokeBorder(active ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 0.5))
        .foregroundStyle(active ? Color.primary : Color.secondary)
        .contentShape(Capsule())
    }

    private func set(_ pages: [Int]) {
        var d = deck.wrappedValue
        d.pages = pages == d.allPages(colonnes: colonnes, lignes: lignes) ? [] : pages
        deck.wrappedValue = d
        onChange()
    }
}

/// Des vues à la file, qui passent à la ligne quand la largeur manque.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Le miroir : la grille telle que l'appareil la montre, dessinée depuis la
/// même `DeckPage`. Avec une disposition à éditer, chaque touche s'ouvre au
/// clic et se déplace au glisser.
private struct DeckMirror: View {
    let page: DeckPage
    let layout: Binding<DeckLayout>?
    let profile: SpellProfile
    let commands: [GameCommand]
    @State private var editing: Int?

    private let size: CGFloat = 84

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<page.lignes, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<page.colonnes, id: \.self) { column in
                        let index = row * page.colonnes + column
                        tile(index)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.85)))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let touche = page.touches.first { $0.index == index }
        let base = DeckKeyView(touche: touche, size: size)
        if let layout {
            base
                .onTapGesture { editing = index }
                .draggable("\(index)")
                .dropDestination(for: String.self) { items, _ in
                    guard let from = items.first.flatMap(Int.init), from != index,
                          layout.wrappedValue.touches.indices.contains(from), layout.wrappedValue.touches.indices.contains(index)
                    else { return false }
                    var l = layout.wrappedValue
                    l.touches.swapAt(from, index)
                    layout.wrappedValue = l
                    return true
                }
                .popover(isPresented: Binding(get: { editing == index }, set: { if !$0 { editing = nil } }), arrowEdge: .bottom) {
                    TileEditor(tile: Binding(
                        get: { layout.wrappedValue.touches.indices.contains(index) ? layout.wrappedValue.touches[index] : .vide },
                        set: { var l = layout.wrappedValue; if l.touches.indices.contains(index) { l.touches[index] = $0 }; layout.wrappedValue = l }
                    ), profile: profile, commands: commands)
                }
                .help(touche.map { help($0) } ?? "")
        } else {
            base.help(touche.map { help($0) } ?? "")
        }
    }

    private func help(_ t: DeckTouche) -> String {
        var parts: [String] = []
        if let c = t.court { parts.append("Appui : \(c.nom)") }
        if let l = t.long { parts.append("Appui long : \(l.nom)") }
        if let l = t.tresLong { parts.append("Appui très long : \(l.nom)") }
        return parts.joined(separator: "\n")
    }
}

/// Une touche du miroir, au rendu de l'appareil : fond sombre, icône en
/// retrait ou symbole, titre en bas ; atténuée comme lui.
struct DeckKeyView: View {
    let touche: DeckTouche?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.16))
            VStack(spacing: 2) {
                Group {
                    if let icone = touche?.icone, let data = Data(base64Encoded: icone), let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(alignment: .bottomLeading) { corner(touche?.iconeLong).offset(x: -4, y: 4) }
                            .overlay(alignment: .bottomTrailing) { corner(touche?.iconeTresLong).offset(x: 4, y: 4) }
                    } else if let symbole = touche?.symbole {
                        Image(systemName: symbole).font(.system(size: size * 0.32)).foregroundStyle(.white)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: size * 0.55, height: size * 0.55)
                Text(touche?.titre ?? "").font(.system(size: 8)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineLimit(2).frame(height: 20)
            }
            .padding(.top, 4)
        }
        .frame(width: size, height: size)
        .opacity(touche?.attenuee == true ? 0.45 : 1)
        .overlay(alignment: .topTrailing) {
            if touche?.long != nil || touche?.tresLong != nil {
                Image(systemName: "hand.tap").font(.system(size: 8)).foregroundStyle(.white.opacity(0.7)).padding(4)
            }
        }
    }

    /// La vignette d'un niveau d'appui, dans un coin.
    @ViewBuilder
    private func corner(_ base64: String?) -> some View {
        if let base64, let d = Data(base64Encoded: base64), let small = NSImage(data: d) {
            Image(nsImage: small).resizable().aspectRatio(contentMode: .fit)
                .frame(width: size * 0.24, height: size * 0.24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(2).background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.08)))
        }
    }
}

/// Le réglage d'une touche : ce que l'appui court fait, ce que l'appui long fait.
private struct TileEditor: View {
    @Binding var tile: DeckTile
    let profile: SpellProfile
    let commands: [GameCommand]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SourcePicker(label: "Appui court", selection: Binding(get: { Optional(tile.court) }, set: { tile.court = $0 ?? .vide }),
                         allowsNone: false, profile: profile, commands: commands)
            SourcePicker(label: "Appui long", selection: $tile.long, allowsNone: true, profile: profile, commands: commands)
            SourcePicker(label: "Appui très long", selection: $tile.tresLong, allowsNone: true, profile: profile, commands: commands)
        }
        .padding(12)
        .frame(width: 320)
    }
}

/// Toutes les sources possibles, par familles, dans un menu.
private struct SourcePicker: View {
    let label: String
    @Binding var selection: DeckSource?
    let allowsNone: Bool
    let profile: SpellProfile
    let commands: [GameCommand]

    private static let navigation: [DeckSource] = [.persoSuivant, .persoPrecedent, .persoActif, .barreSuivante,
                                                   .barrePrecedente, .barrePremiere, .menu, .finDeTour, .corpsACorps, .reconnaitre]

    var body: some View {
        Picker(label, selection: $selection) {
            if allowsNone { Text("Aucune").tag(DeckSource?.none) }
            Text("Vide").tag(Optional(DeckSource.vide))
            Section("Navigation") {
                ForEach(Self.navigation, id: \.self) { Text($0.label).tag(Optional($0)) }
            }
            Section("Barre active") {
                ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { p in
                    Text("Case \(p + 1)").tag(Optional(DeckSource.sortActif(position: p)))
                }
            }
            Section("Barre suivante (par rapport à l'active)") {
                ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { p in
                    Text("Case \(p + 1)").tag(Optional(DeckSource.sortBarreDecalee(position: p, decalage: 1)))
                }
            }
            Section("Barre d'après") {
                ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { p in
                    Text("Case \(p + 1)").tag(Optional(DeckSource.sortBarreDecalee(position: p, decalage: 2)))
                }
            }
            ForEach(profile.barres.indices, id: \.self) { b in
                Section(profile.barres[b].nom) {
                    ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { p in
                        Text("\(p + 1) · \(profile.slot(bar: b, position: p)?.nom ?? "—")").tag(Optional(DeckSource.sort(barre: b, position: p)))
                    }
                }
            }
            Section("Commandes du jeu") {
                ForEach(commands) { Text($0.nom).tag(Optional(DeckSource.commande($0.id))) }
            }
        }
    }
}
