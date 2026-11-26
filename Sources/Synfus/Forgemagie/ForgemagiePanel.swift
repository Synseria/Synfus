import AppKit
import SwiftUI
import SynseriaDesign

/// L'assistant de forgemagie, posé à côté de l'atelier du jeu : jamais clé,
/// montré devant Dofus seulement (`PanneauxJeu`). Ouvert, il lit l'atelier
/// (`ForgemagieModele`) ; fermé, il ne lit rien.
@MainActor
final class ForgemagiePanel: NSObject, ObservableObject {
    static let shared = ForgemagiePanel()

    @Published private(set) var ouvert = false
    private var impose = false
    private var panel: NSPanel?

    private override init() { super.init() }

    func ouvrir() {
        ouvert = true
        impose = true
        ForgemagieModele.shared.demarrer()
        appliquer(force: true)
    }

    func fermer() {
        ouvert = false
        ForgemagieModele.shared.arreter()
        appliquer(force: false)
    }

    func basculerPliage() {
        PanneauxJeu.basculerPliage(.forgemagie, hauteur: panel?.frame.height ?? 0)
    }

    func revoirVisibilite(force: Bool) {
        if force { impose = false }
        appliquer(force: force)
    }

    func recentrer() {
        if ouvert, let panel { PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut) }
    }

    private func appliquer(force: Bool) {
        PanneauxJeu.appliquer(&panel, ouvert: ouvert, impose: impose, force: force,
                              parDefaut: Self.placeParDefaut, construire: construire)
    }

    private func construire() -> NSPanel {
        PanneauxJeu.construire(nom: "ForgemagiePanel", largeur: ForgemagieVue.largeur, largeurs: ForgemagieVue.largeurs,
                               vue: ForgemagieVue(), parDefaut: Self.placeParDefaut)
    }

    /// À droite, à mi-hauteur : l'atelier du jeu s'ouvre au centre, l'inventaire à sa droite.
    private static let placeParDefaut: PanneauxJeu.PlaceParDefaut = { zone, taille in
        NSPoint(x: zone.maxX - 40 - taille.width, y: zone.midY + taille.height / 2)
    }
}

/// Ce que l'atelier montre, relu : le reliquat, l'issue de la dernière rune et
/// le compte de la séance, puis chaque ligne et ce que pèse son dépassement
/// face au plafond over + exo.
struct ForgemagieVue: View {
    static let largeur: CGFloat = 320
    static let largeurs: ClosedRange<CGFloat> = 280...480

    @ObservedObject private var modele = ForgemagieModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @Environment(\.largeurPanneau) private var largeurPanneau
    // periphery:ignore - observé : le pliage du panneau (`PanneauxJeu.plie`)
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        CadrePanneau(plie: PanneauxJeu.plie(.forgemagie)) {
            EnTetePanneau(icone: "wand.and.stars", teinte: Color.jeton(\.accentTexte)) {
                Text(L("forgemagie.titre"))
                    .font(Jetons.typoTitreCarte.font)
                    .padding(.leading, Jetons.espace1)
            } boutons: {
                BoutonPliage(plie: PanneauxJeu.plie(.forgemagie)) { ForgemagiePanel.shared.basculerPliage() }
                BoutonEnTete(icone: "xmark", aide: L("quete.fermer.simple")) { ForgemagiePanel.shared.fermer() }
            }
        } corps: {
            VStack(alignment: .leading, spacing: Jetons.espace2) { contenu }
                .padding(Jetons.espace2)
        }
        .frame(width: largeurPanneau ?? Self.largeur, alignment: .leading)
        .bordsRedimensionnables(.cotes)
    }

    @ViewBuilder
    private var contenu: some View {
        if !previews.authorized {
            LigneAutorisation()
        } else if let catalogue = modele.catalogue, let atelier = modele.suivi.atelier, !modele.absent {
            seance(atelier)
            Divider()
            ForEach(atelier.objet.lignes, id: \.effet) { ligne in
                LigneFM(ligne: ligne, objet: atelier.objet, catalogue: catalogue)
            }
            ForEach(atelier.inconnues, id: \.self) { texte in
                Text(texte).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre3))
                    .help(L("forgemagie.inconnue"))
            }
        } else {
            Text(modele.catalogue == nil ? L("forgemagie.chargement") : L("forgemagie.attente"))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Le reliquat lu, l'issue de la dernière rune, le compte de la séance.
    private func seance(_ atelier: AtelierFM) -> some View {
        HStack(spacing: Jetons.espace2) {
            if let reliquat = atelier.reliquat {
                Text(L("forgemagie.reliquat", reliquat.formatted(.number.precision(.fractionLength(0...2)))))
                    .font(Jetons.typoCorps.font)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if let derniere = modele.suivi.derniere {
                Badge(texte: Self.libelle(derniere.issue), ton: Self.ton(derniere.issue))
                    .help(Self.pertes(derniere, catalogue: modele.catalogue))
            }
            let comptes = modele.suivi.comptes
            if !comptes.isEmpty {
                Text(L("forgemagie.comptes", comptes[.succesCritique] ?? 0, comptes[.succesNeutre] ?? 0, comptes[.echec] ?? 0))
                    .font(Jetons.typoMeta.font)
                    .monospacedDigit()
                    .foregroundStyle(Color.jeton(\.encre2))
                    .help(L("forgemagie.comptes.aide"))
            }
        }
    }

    static func libelle(_ issue: FusionFM.Issue) -> String {
        switch issue {
        case .succesCritique: L("forgemagie.issue.critique")
        case .succesNeutre: L("forgemagie.issue.neutre")
        case .echec: L("forgemagie.issue.echec")
        }
    }

    private static func ton(_ issue: FusionFM.Issue) -> Ton {
        switch issue {
        case .succesCritique: .succes
        case .succesNeutre: .avertissement
        case .echec: .danger
        }
    }

    /// « −4 Pods, −1 Vitalité » : ce que la dernière rune a coûté, en infobulle.
    private static func pertes(_ fusion: FusionFM, catalogue: CatalogueFM?) -> String {
        guard !fusion.pertes.isEmpty else { return L("forgemagie.sansPerte") }
        return fusion.pertes.sorted { $0.key < $1.key }
            .map { "−\($0.value) \(catalogue?.effets[$0.key]?.nom ?? "#\($0.key)")" }
            .joined(separator: ", ")
    }
}

/// Une ligne de l'objet : son nom, sa valeur sur son jet max, et le poids de
/// son dépassement sur le plafond, teinté quand il en approche.
private struct LigneFM: View {
    let ligne: ObjetFM.Ligne
    let objet: ObjetFM
    let catalogue: CatalogueFM

    var body: some View {
        HStack(spacing: Jetons.espace2) {
            Text(catalogue.effets[ligne.effet]?.nom ?? "#\(ligne.effet)")
                .foregroundStyle(Color.jeton(\.encre))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ligne.exo ? L("forgemagie.exo", ligne.valeur)
                 : ligne.max.map { L("forgemagie.surMax", ligne.valeur, $0) } ?? "\(ligne.valeur)")
                .monospacedDigit()
                .foregroundStyle(Color.jeton(\.encre2))
            if let poids = objet.poidsOverExo(ligne, catalogue), poids > 0 {
                Text(L("forgemagie.plafond", poids.formatted(.number.precision(.fractionLength(0...1))),
                       Int(ObjetFM.plafondOverExo)))
                    .monospacedDigit()
                    .foregroundStyle(Color.jeton(poids > ObjetFM.plafondOverExo ? \.danger
                        : poids > ObjetFM.plafondOverExo * 0.8 ? \.avertissement : \.encre3))
                    .help(L("forgemagie.plafond.aide"))
            }
        }
        .font(Jetons.typoCorps.font)
    }
}
