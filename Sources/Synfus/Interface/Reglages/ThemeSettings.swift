import SwiftUI
import SynseriaDesign

/// Onglet Thème : l'écran commun du SDS (`ReglagesDuTheme`), lié au thème des préférences ; tout
/// s'applique en direct, dans les réglages comme dans la barre et les panneaux (`ThemeCourant`).
/// L'app n'y met que ses mots.
struct ThemeSettings: View {
    // `ObservableObject` : sans lui, un réglage qui ne change aucune couleur (Système) ne redessinerait pas l'écran.
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        ReglagesDuTheme(theme: $prefs.themeDeLApp, libelles: Self.libelles)
    }

    /// Les mots de l'écran et de son aperçu, traduits.
    private static var libelles: LibellesDuTheme {
        var l = LibellesDuTheme()
        l.systeme = L("theme.systeme")
        l.clarte = L("theme.clarte")
        l.couleur = L("theme.couleur")
        l.accorde = L("theme.accorde")
        l.fond = L("theme.fond")
        l.clair = L("theme.clair")
        l.sombre = L("theme.sombre")
        l.apercu = L("theme.apercu")
        l.rechercher = L("theme.apercu.rechercher")
        l.accueil = L("theme.apercu.accueil")
        l.recents = L("theme.apercu.recents")
        l.collections = L("theme.apercu.collections")
        l.travail = L("theme.apercu.travail")
        l.projets = L("theme.apercu.projets")
        l.archives = L("theme.apercu.archives")
        l.personnel = L("theme.apercu.personnel")
        l.creer = L("theme.apercu.creer")
        l.progression = L("theme.apercu.progression")
        l.succes = L("theme.apercu.succes")
        l.alerte = L("theme.apercu.alerte")
        l.erreur = L("theme.apercu.erreur")
        l.vignette = L("theme.apercu.vignette")
        l.sousTitre = L("theme.apercu.sousTitre")
        l.elementChoisi = L("theme.apercu.elementChoisi")
        l.aujourdhui = L("theme.apercu.aujourdhui")
        l.element = L("theme.apercu.element")
        l.etiquette = L("theme.apercu.etiquette")
        l.elementFini = L("theme.apercu.elementFini")
        l.hier = L("theme.apercu.hier")
        l.lien = L("theme.apercu.lien")
        l.actionChercher = L("theme.apercu.actionChercher")
        l.actionChoisie = L("theme.apercu.actionChoisie")
        l.actionAutre = L("theme.apercu.actionAutre")
        l.remplacer = L("theme.apercu.remplacer")
        l.copier = L("theme.apercu.copier")
        l.annuler = L("theme.apercu.annuler")
        l.nomDuCran = { cran in
            switch cran {
            case .jour: L("theme.clarte.jour")
            case .crepuscule: L("theme.clarte.crepuscule")
            case .penombre: L("theme.clarte.penombre")
            case .nuit: L("theme.clarte.nuit")
            }
        }
        l.nomDuFond = { fond in
            switch fond {
            case .sable: L("theme.fond.sable")
            case .ardoise: L("theme.fond.ardoise")
            }
        }
        return l
    }
}
