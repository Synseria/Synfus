import SwiftUI

/// Un zaap dans les réglages : étiquette (au clic), favori, activation ; en
/// fond, la vue de sa carte du jeu (`zaapsVueCarte`).
struct CarteZaapReglages: View {
    let zaap: Zaap
    let langue: Langue
    @ObservedObject private var prefs = Preferences.shared
    @Environment(\.colorScheme) private var apparence

    var body: some View {
        let actif = CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                BoutonEtiquette(cle: zaap.cle)
                Spacer(minLength: 0)
                BoutonFavori(cle: zaap.cle)
                Toggle(L("palette.reglages.actif"), isOn: Binding(
                    get: { actif }, set: { prefs.zaapsChoix[zaap.cle] = $0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            Text(zaap.nom(en: langue))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(zaap.zone(en: langue) ?? (prefs.zaapsAjoutes.contains(zaap) ? L("zaap.ajoute") : ""))
                    .lineLimit(1)
                if zaap.monde != Zaap.mondeDesDouze {
                    Text(L("zaap.autreCarte")).foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
                Text(Coordonnees.texte(zaap.x, zaap.y)).font(.system(size: 11, design: .monospaced))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background { fond }
        .opacity(actif ? 1 : 0.55)
        .contextMenu {
            if prefs.zaapsAjoutes.contains(zaap) {
                Button(L("zaap.supprimer"), role: .destructive) {
                    prefs.zaapsAjoutes.removeAll { $0.cle == zaap.cle }
                    prefs.zaapsChoix[zaap.cle] = nil
                    prefs.zaapsFavoris.removeAll { $0 == zaap.cle }
                    prefs.etiquettes[zaap.cle] = nil
                }
            }
        }
    }
}

extension CarteZaapReglages {
    private static let forme = RoundedRectangle(cornerRadius: 9, style: .continuous)

    /// La vue à un quart d'opacité sur un fond uni, assombrie vers le bas où
    /// sont la zone et les coordonnées : le texte reste lisible sur
    /// n'importe quelle carte. Le fond uni tient la taille de la case, l'image
    /// en déborde et la forme la rogne.
    @ViewBuilder
    private var fond: some View {
        if prefs.zaapsVueCarte, let idCarte = zaap.idCarte {
            let sombre = apparence == .dark
            Color(white: sombre ? 0.17 : 0.95)
                .overlay { ImageDofusDB(url: DofusDB.imageCarte(idCarte)).scaledToFill().opacity(0.25) }
                .overlay {
                    LinearGradient(colors: [.clear, Color(white: sombre ? 0.12 : 1).opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .clipShape(Self.forme)
        } else {
            Self.forme.fill(Color.primary.opacity(0.05))
        }
    }
}

/// La dernière case de la grille : un zaap que la carte ne connaît pas encore.
struct AjoutZaap: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var ouvert = false
    @State private var nom = ""
    @State private var x = ""
    @State private var y = ""

    var body: some View {
        Button { ouvert = true } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                Text(L("zaap.ajout")).font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 62)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(dash: [4, 3])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $ouvert, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("zaap.ajout.aide")).font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 260, alignment: .leading)
                HStack(spacing: 6) {
                    TextField(L("zaap.ajout.nom"), text: $nom)
                    TextField("x", text: $x).frame(width: 50)
                    TextField("y", text: $y).frame(width: 50)
                }
                .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button(L("zaap.ajout.bouton")) {
                        guard let zaap = nouveau else { return }
                        prefs.zaapsAjoutes.append(zaap)
                        nom = ""
                        x = ""
                        y = ""
                        ouvert = false
                    }
                    .disabled(nouveau == nil)
                }
            }
            .padding(12)
        }
    }

    private var nouveau: Zaap? {
        let nom = nom.trimmingCharacters(in: .whitespaces)
        guard !nom.isEmpty,
              let x = Int(x.trimmingCharacters(in: .whitespaces)),
              let y = Int(y.trimmingCharacters(in: .whitespaces)),
              abs(x) <= PositionCarte.borne, abs(y) <= PositionCarte.borne
        else { return nil }
        let zaap = Zaap(x, y, noms: [L10n.courante.langue.rawValue: nom])
        // Déjà connu : il suffit de l'activer dans la grille.
        return prefs.zaapsConnus.contains { $0.cle == zaap.cle } ? nil : zaap
    }
}
