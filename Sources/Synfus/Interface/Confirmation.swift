// La confirmation d'un geste qui détruit : une feuille « Verbe + objet ? », la seule de l'app.

import AppKit
import SwiftUI

/// Un bouton de plus, à gauche : il ouvre une page et laisse la feuille en place.
struct LienConfirmation: Equatable {
    let titre: String
    let url: URL
}

/// Ce que dit la feuille : le titre nomme le verbe et l'objet (« Supprimer ce zaap ? »), une ligne de
/// détail dit au besoin le nombre ou ce qui sera perdu, le bouton reprend le verbe seul. `rang` : celui du
/// bouton du verbe, destructif sauf quand le geste n'en est pas un.
struct DemandeConfirmation: Equatable {
    let titre: String
    var detail: String?
    let verbe: String
    var rang: RangBouton = .destructif
    var lien: LienConfirmation?
}

/// « Annuler » puis le verbe à droite, le lien d'information s'il y en a un à l'autre bout. Entrée ne détruit jamais : aucun bouton n'est
/// celui du défaut, il faut cliquer ou tabuler ; ⎋ annule.
struct FeuilleConfirmation: View {
    let demande: DemandeConfirmation
    let repondre: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.quatre) {
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                Text(demande.titre)
                    .font(Jetons.Typo.titre.police)
                    .foregroundStyle(Color.jeton(\.encre))
                if let detail = demande.detail {
                    Text(detail)
                        .font(Jetons.Typo.corps.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Jetons.Espace.deux) {
                if let lien = demande.lien {
                    Button(lien.titre) { NSWorkspace.shared.open(lien.url) }
                        .buttonStyle(.bouton(.tertiaire))
                }
                Spacer(minLength: 0)
                Button(L("commun.annuler")) { repondre(false) }
                    .buttonStyle(.bouton(.tertiaire))
                    .keyboardShortcut(.cancelAction)
                Button(demande.verbe) { repondre(true) }
                    .lineLimit(1)
                    .buttonStyle(.bouton(demande.rang))
            }
        }
        .padding(Jetons.Espace.six)
        // Trois boutons à une ligne chacun demandent plus que deux.
        .frame(width: demande.lien == nil ? 360 : 460, alignment: .leading)
        .background(Color.jeton(\.fenetre))
    }
}

@MainActor
enum Confirmation {
    /// Vrai si l'utilisateur confirme. En feuille sur la fenêtre `parent` quand elle peut la porter,
    /// sinon dans une fenêtre modale (menu de la barre de menus, panneaux du jeu).
    static func demander(_ demande: DemandeConfirmation, sur parent: NSWindow? = nil) async -> Bool {
        await withCheckedContinuation { suite in
            var fenetre: NSWindow?
            let porteuse = parent ?? NSApp.keyWindow
            let vue = FeuilleConfirmation(demande: demande) { reponse in
                guard let fenetre else { return }
                if let porteuse, porteuse.sheets.contains(fenetre) {
                    porteuse.endSheet(fenetre, returnCode: reponse ? .OK : .cancel)
                } else {
                    NSApp.stopModal(withCode: reponse ? .OK : .cancel)
                    fenetre.orderOut(nil)
                    suite.resume(returning: reponse)
                }
            }
            let hote = NSHostingController(rootView: vue.racineSynfus())
            let nouvelle = NSWindow(contentViewController: hote)
            // Sans barre de titre une NSWindow ne devient jamais key : ni ⎋ ni Tab n'atteindraient la feuille.
            nouvelle.styleMask = [.titled, .fullSizeContentView]
            nouvelle.titlebarAppearsTransparent = true
            nouvelle.titleVisibility = .hidden
            fenetre = nouvelle
            if let porteuse, porteuse.canBecomeKey {
                porteuse.beginSheet(nouvelle) { suite.resume(returning: $0 == .OK) }
            } else {
                // L'app tourne en accessory : sans activation, la feuille s'ouvrirait derrière le jeu.
                NSApp.activate(ignoringOtherApps: true)
                nouvelle.center()
                NSApp.runModal(for: nouvelle)
            }
        }
    }
}
