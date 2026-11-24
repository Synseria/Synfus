import AppKit
import SwiftUI

/// La recette épinglée, posée sur le jeu le temps des courses : une seule, que la suivante remplace
/// — on achète pour un objet à la fois, et une pile de panneaux couvrirait le jeu. Elle survit à la
/// palette qui l'a ouverte. Jamais clé (`PanneauDeJeu`) : à l'hôtel de vente, la frappe reste au champ
/// de recherche du jeu. Comme les autres panneaux, elle ne se montre que devant Dofus
/// (`PanneauxJeu`), et AppKit garde sa position.
@MainActor
final class RecettePanel: NSObject, ObservableObject {
    static let shared = RecettePanel()

    @Published private(set) var recette: RecetteEpinglee?
    /// Ouverte depuis une autre app que Dofus : elle reste là jusqu'au prochain changement d'app.
    private var impose = false
    private var panel: NSPanel?

    private override init() { super.init() }

    func epingler(_ recette: RecetteEpinglee) {
        self.recette = recette
        impose = true
        appliquer(force: true)
    }

    func fermer() {
        recette = nil
        appliquer(force: false)
    }

    func revoirVisibilite(force: Bool) {
        if force { impose = false }
        appliquer(force: force)
    }

    /// Le panneau ouvert reprend sa place d'origine.
    func recentrer() {
        if recette != nil, let panel { PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut) }
    }

    private func appliquer(force: Bool) {
        PanneauxJeu.appliquer(&panel, ouvert: recette != nil, impose: impose, force: force,
                              parDefaut: Self.placeParDefaut, construire: construire)
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: RecetteVue().racineSynfus())
        hosting.sizingOptions = [.preferredContentSize]
        let panel = PanneauDeJeu(
            contentRect: NSRect(x: 0, y: 0, width: RecetteVue.largeur, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if !panel.setFrameAutosaveName("RecettePanel") || panel.frame.origin == .zero {
            PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut)
        }
        return panel
    }

    /// En haut, à gauche du centre de l'écran, en miroir de l'aide aux boss : l'hôtel de vente du jeu
    /// s'ouvre au milieu.
    private static let placeParDefaut: PanneauxJeu.PlaceParDefaut = { zone, taille in
        NSPoint(x: zone.midX - 220 - taille.width, y: zone.maxY - 80)
    }
}

/// Le contenu du panneau : la recette épinglée du moment.
struct RecetteVue: View {
    /// Celle des quêtes : un nom d'objet du jeu tient sur une ligne.
    static let largeur = Jetons.largeurPanneauQuetes

    @ObservedObject private var panneau = RecettePanel.shared

    var body: some View { FicheRecette(recette: panneau.recette) }
}

/// Une recette : ce qu'elle fabrique au titre, le métier, puis un ingrédient par ligne avec sa
/// quantité ; un clic copie le nom, coché le temps du signal.
struct FicheRecette: View {
    let recette: RecetteEpinglee?
    @StateObject private var copie = SignalCopie()

    var body: some View {
        CadrePanneau(plie: recette == nil) {
            EnTetePanneau(icone: "hammer", teinte: Color.jeton(\.accentTexte)) {
                Text(recette?.objet ?? L("recette.titre"))
                    .font(Jetons.typoTitreCarte.font)
                    .lineLimit(1)
                    .padding(.leading, Jetons.espace1)
            } boutons: {
                BoutonEnTete(icone: "xmark", aide: L("quete.fermer.simple")) { RecettePanel.shared.fermer() }
            }
        } corps: {
            if let recette {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("ouTrouver.recette", recette.metier, recette.niveau))
                        .font(Jetons.typoMeta.font)
                        .foregroundStyle(Color.jeton(\.encre2))
                        .padding(.horizontal, Jetons.espace2)
                        .padding(.bottom, Jetons.espace1)
                    ForEach(Array(recette.ingredients.enumerated()), id: \.offset) { rang, ingredient in
                        ligne(ingredient, id: "\(rang)")
                    }
                }
                .padding(.vertical, Jetons.espace2)
            }
        }
        .frame(width: RecetteVue.largeur, alignment: .leading)
    }

    private func ligne(_ ingredient: RecetteEpinglee.Ingredient, id: String) -> some View {
        Button {
            PressePapiers.copier(ingredient.nom)
            copie.signaler(id)
        } label: {
            HStack(spacing: Jetons.espace2) {
                IconeCopie(icone: "doc.on.doc", copie: copie.affiche(id))
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.encre3))
                    .frame(width: Jetons.espace4)
                Text(ingredient.nom)
                    .foregroundStyle(Color.jeton(\.encre))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L("recette.quantite", ingredient.quantite))
                    .font(Jetons.typoCode.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .fixedSize()
            }
            .font(Jetons.typoCorps.font)
            .padding(.horizontal, Jetons.espace2)
            .padding(.vertical, Jetons.espace1)
            .frame(minHeight: Jetons.hauteurCase)
            .contentShape(Rectangle())
        }
        .buttonStyle(.etat(nue: true))
        .aide(L("quete.copierNom"))
        .accessibilityLabel(L("quete.ressource", ingredient.nom, ingredient.quantite))
    }
}
