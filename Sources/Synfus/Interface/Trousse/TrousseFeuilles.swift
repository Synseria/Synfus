// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu 346ae04f3ee999db
import SwiftUI

// La feuille et la confirmation d'un geste que ⌘Z ne rattrape pas.

// MARK: - Feuille et confirmation

/// Le corps d'une feuille (`.sheet`) : la fenêtre, de `largeur-feuille`, à `espace-5` de ses bords.
/// Les boutons au bout, en bas à droite : le geste tout à droite, « Annuler » à sa gauche.
struct Feuille<Contenu: View>: View {
    @ViewBuilder let contenu: Contenu
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace2) { contenu }
            .fixedSize(horizontal: false, vertical: true)
            .padding(Jetons.espace5)
            .frame(width: Jetons.largeurFeuille)
            .background(c.fondFenetre.couleur)
    }
}

/// Un geste que ⌘Z ne rattrape pas, à confirmer : « Verbe + objet ? », une ligne de détail au
/// besoin (le nombre, ce qui sera perdu), le verbe seul sur le bouton.
struct Confirmation: Identifiable {
    let id = UUID()
    let titre: String
    var detail: String?
    let verbe: String
    /// Faux pour un geste qui engage sans détruire (fusionner) : le bouton est alors le principal.
    var destructif = true
    let action: @MainActor () -> Void
}

extension View {
    /// La seule façon de confirmer un geste dans une vue : une feuille, jamais `confirmationDialog`.
    /// `annuler` : le libellé, dans la langue de l'app.
    func confirmation(_ demande: Binding<Confirmation?>, annuler: String) -> some View {
        sheet(item: demande) { confirmation in
            FeuilleDeConfirmation(demande: confirmation, annuler: annuler) { demande.wrappedValue = nil }
        }
    }
}

/// ⏎ ne détruit jamais : le destructif n'est pas l'action par défaut, il faut le cliquer ou y tabuler.
private struct FeuilleDeConfirmation: View {
    let demande: Confirmation
    let annuler: String
    let fermer: () -> Void
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        Feuille {
            Text(demande.titre).font(Jetons.typoTitreCarte.font).foregroundStyle(c.encre.couleur)
            if let detail = demande.detail {
                Text(detail).font(Jetons.typoCorps.font).foregroundStyle(c.encre2.couleur)
            }
            HStack(spacing: Jetons.espace2) {
                Spacer(minLength: 0)
                Button(annuler, action: fermer)
                    .buttonStyle(BoutonTertiaire())
                    .keyboardShortcut(.cancelAction)
                if demande.destructif {
                    Button(demande.verbe, action: agir).buttonStyle(BoutonDestructif())
                } else {
                    Button(demande.verbe, action: agir).buttonStyle(BoutonPrincipal()).keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top, Jetons.espace4)
        }
    }

    private func agir() {
        demande.action()
        fermer()
    }
}

#if os(macOS)
extension Confirmation {
    /// Pour un geste lancé hors de toute vue (un menu d'AppKit) : la même demande, en alerte
    /// modale. Le verbe à droite sans ⏎, « Annuler » à gauche sur ⎋. Vrai si l'on confirme.
    @MainActor static func demander(titre: String, detail: String? = nil, verbe: String, annuler: String) -> Bool {
        let alerte = NSAlert()
        alerte.messageText = titre
        alerte.informativeText = detail ?? ""
        let bouton = alerte.addButton(withTitle: verbe)
        bouton.hasDestructiveAction = true
        bouton.keyEquivalent = ""
        alerte.addButton(withTitle: annuler).keyEquivalent = "\u{1b}"
        return alerte.runModal() == .alertFirstButtonReturn
    }
}
#endif
