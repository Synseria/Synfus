import SwiftUI

/// Onglet Stream Deck : la liaison, le miroir de l'appareil — composé par le
/// même code que ce qu'il affiche —, la disposition (générique ou propre à un
/// perso, éditée touche par touche), les gestes, la détection de combat.
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
            Section {
                Toggle("Liaison active", isOn: $prefs.streamDeckEnabled)
                if prefs.streamDeckEnabled {
                    HStack {
                        Text(link.status).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text(link.grilles.map { "\($0.colonnes) × \($0.lignes)" }.sorted().joined(separator: ", "))
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            } header: {
                SectionTitle("Liaison", help: "Ouvre un socket local, réservé à ton compte, sur lequel le plugin "
                             + "SynfusDeck reçoit ce que chaque touche montre et fait. Il ne peut demander que ce que "
                             + "fait la barre : perso suivant, précédent, barre suivante, menu. C'est le plugin qui "
                             + "frappe la touche du jeu ; Synfus n'émet jamais rien.\n\n" + StreamDeckLink.socketURL.path)
            }

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
                    }
                )) {
                    ForEach(DeckSettings.Kind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Appui long sur un sort : le sort d'en face, en vignette dans le coin", isOn: Binding(
                    get: { deck.wrappedValue.sortLong },
                    set: { var d = deck.wrappedValue; d.sortLong = $0; deck.wrappedValue = d }
                ))
                .disabled(deck.wrappedValue.kind == .personnalisee)
                if deck.wrappedValue.kind == .parRangee { pagesEditor }
                if deck.wrappedValue.kind == .personnalisee {
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
                             + "réimporter, le changement est immédiat. « Barre par barre » : la barre active sur les "
                             + "touches, « barre suivante » passe à l'autre ; en appui long, la même case de la barre "
                             + "suivante. « Une barre par rangée » : la barre 1 sur la première rangée, la 2 sur la "
                             + "seconde, par fenêtres de cinq cases — choisis les pages et leur ordre ; en appui long, "
                             + "la case de la fenêtre suivante (1 → 6). « Personnalisée » : n'importe quelle case de "
                             + "n'importe quelle barre sur n'importe quelle touche, un second sort en appui long, une "
                             + "commande. Générique pour tous les persos, ou propre à un perso (dans son profil).")
            }

            Section {
                Stepper("Appui long : \(prefs.appuiLongMs) ms", value: $prefs.appuiLongMs, in: 150...1000, step: 50)
            } header: {
                SectionTitle("Gestes", help: "Un appui court joue au relâchement ; une touche maintenue au-delà de "
                             + "cette durée joue son action longue (perso précédent, première barre, corps à corps, "
                             + "second sort…) et le relâchement ne fait plus rien. Pas de double-clic : deux appuis sont "
                             + "deux frappes, comme au clavier — lancer deux fois un sort doit rester possible. Une touche "
                             + "sans action longue joue dès l'enfoncement.")
            }

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

            if !message.isEmpty {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

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

    /// Les pages du mode par rangée : lesquelles, dans quel ordre.
    private var pagesEditor: some View {
        let all = 0..<DeckLayout.pageCountParRangee(colonnes: grille.colonnes, lignes: grille.lignes)
        let order = deck.wrappedValue.pagesParRangee(colonnes: grille.colonnes, lignes: grille.lignes)
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(order.enumerated()), id: \.element) { rank, page in
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(get: { true }, set: { _ in setPages(order.filter { $0 != page }) }))
                        .labelsHidden().disabled(order.count == 1)
                    Text("\(rank + 1). " + DeckLayout.pageLabelParRangee(page, colonnes: grille.colonnes, lignes: grille.lignes))
                        .font(.system(size: 11))
                    Button { var o = order; o.swapAt(rank, rank - 1); setPages(o) } label: { Image(systemName: "chevron.up") }
                        .disabled(rank == 0)
                    Button { var o = order; o.swapAt(rank, rank + 1); setPages(o) } label: { Image(systemName: "chevron.down") }
                        .disabled(rank == order.count - 1)
                }
                .buttonStyle(.borderless)
            }
            ForEach(all.filter { !order.contains($0) }, id: \.self) { page in
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(get: { false }, set: { _ in setPages(order + [page]) })).labelsHidden()
                    Text(DeckLayout.pageLabelParRangee(page, colonnes: grille.colonnes, lignes: grille.lignes))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func setPages(_ pages: [Int]) {
        var d = deck.wrappedValue
        let all = Array(0..<DeckLayout.pageCountParRangee(colonnes: grille.colonnes, lignes: grille.lignes))
        d.pages = pages == all ? [] : pages
        deck.wrappedValue = d
        link.execute(DeckCommand(type: .barrePremiere))
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
                            .overlay(alignment: .bottomTrailing) {
                                if let corner = touche?.iconeLong, let d = Data(base64Encoded: corner), let small = NSImage(data: d) {
                                    Image(nsImage: small).resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: size * 0.24, height: size * 0.24)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        .padding(2).background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.08)))
                                        .offset(x: 4, y: 4)
                                }
                            }
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
            if touche?.long != nil {
                Image(systemName: "hand.tap").font(.system(size: 8)).foregroundStyle(.white.opacity(0.7)).padding(4)
            }
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
                                                   .barrePrecedente, .barrePremiere, .menu, .finDeTour, .corpsACorps]

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
