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
    private var specifique: Bool { store.profiles[perso]?.disposition != nil }

    /// Le mode en cours d'édition : celui du perso s'il en a un, le générique sinon.
    private var mode: Binding<DeckMode> {
        Binding(
            get: { store.profiles[perso]?.disposition ?? prefs.deckMode },
            set: { new in
                if specifique { var p = profile; p.disposition = new; store.save(p) } else { prefs.deckMode = new }
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
                    Toggle("Disposition propre à ce perso", isOn: Binding(
                        get: { specifique },
                        set: { on in var p = profile; p.disposition = on ? prefs.deckMode : nil; store.save(p) }
                    ))
                    .disabled(perso.isEmpty)
                    Spacer()
                }
                Picker("Mode", selection: Binding(
                    get: { mode.wrappedValue.kind },
                    set: { kind in
                        switch kind {
                        case .parBarre: mode.wrappedValue = .parBarre
                        case .parRangee: mode.wrappedValue = .parRangee
                        case .personnalisee:
                            if case .personnalisee = mode.wrappedValue { return }
                            mode.wrappedValue = .personnalisee(mode.wrappedValue.layout(colonnes: grille.colonnes, lignes: grille.lignes, page: 0))
                        }
                    }
                )) {
                    ForEach(DeckMode.Kind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if case .personnalisee = mode.wrappedValue {
                    HStack(spacing: 8) {
                        Text("Repartir de :").font(.system(size: 11)).foregroundStyle(.secondary)
                        Button("barre par barre") { mode.wrappedValue = .personnalisee(.parBarre(colonnes: grille.colonnes, lignes: grille.lignes)) }
                        Button("une barre par rangée") { mode.wrappedValue = .personnalisee(.parRangee(colonnes: grille.colonnes, lignes: grille.lignes, page: 0)) }
                        Spacer()
                        Text("Clique une touche pour la régler, glisse-la pour la déplacer.")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 11))
                }
                DeckMirror(page: link.previewPage(grille: grille, mode: mode.wrappedValue, perso: perso.isEmpty ? nil : perso, classe: classe),
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
                             + "touches, « barre suivante » passe à l'autre. « Une barre par rangée » : la barre 1 sur "
                             + "la première rangée, la 2 sur la seconde, par fenêtres de cinq cases. « Personnalisée » : "
                             + "n'importe quelle case de n'importe quelle barre sur n'importe quelle touche — pour sauter "
                             + "des sorts, les réordonner, ou en mettre un second en appui long. Générique pour tous les "
                             + "persos, ou propre à un perso (dans son profil).")
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
                CopiableCommand(command: "./build.sh --install")
            } header: {
                SectionTitle("Installation", help: "Construit l'app et le plugin, installe l'un dans /Applications et "
                             + "l'autre dans le logiciel Stream Deck. La première fois, le paquet "
                             + "dist/fr.synseria.synfus.streamDeckPlugin s'ouvre : accepte, le profil « Synfus » (quinze "
                             + "touches Synfus) s'installe avec. Ensuite, Synfus compose tout : rien à réimporter.")
            }

            if !message.isEmpty {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// La grille éditable — `nil` tant que le mode n'est pas personnalisé.
    private var layoutBinding: Binding<DeckLayout>? {
        guard case .personnalisee(let layout) = mode.wrappedValue else { return nil }
        return Binding(get: { layout }, set: { mode.wrappedValue = .personnalisee($0) })
    }

    private func calibrate(_ enCombat: Bool) {
        Task { message = await CombatWatcher.shared.calibrate(enCombat: enCombat) }
    }
}

extension DeckMode {
    enum Kind: String, CaseIterable, Identifiable {
        case parBarre, parRangee, personnalisee
        var id: String { rawValue }
        var label: String {
            switch self {
            case .parBarre: return "Barre par barre"
            case .parRangee: return "Une barre par rangée"
            case .personnalisee: return "Personnalisée"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .parBarre: return .parBarre
        case .parRangee: return .parRangee
        case .personnalisee: return .personnalisee
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
