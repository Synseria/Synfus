import AppKit
import SwiftUI
import Testing
@testable import Synfus

/// Les captures de la documentation et des notes de version : les vues de
/// Synfus rendues hors écran, sur des données d'exemple — jamais un visuel du
/// jeu. Ignoré sans `SYNFUS_CAPTURES=<dossier>` ; pour `docs/screenshots` :
/// `SYNFUS_CAPTURES=$PWD/docs/screenshots sh test.sh CapturesTests`.
@MainActor
struct CapturesTests {
    nonisolated private static let dossier = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES"]

    private func contexte() -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna (Village d'Amakna)")
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.lieux = Carte.integree.lieux
        contexte.reseau = ReseauSousZones(Carte.integree)
        contexte.etiquettes = ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2", "1:39,-82": "Fri 3",
                               "1:-2,0": "Village", "1:-16,1": "Koalak", "1:5,7": "Bouftou",
                               "1:-31,-56": "Bonta", "1:-26,37": "Brâk"]
        contexte.favoris = ["1:-31,-56", "1:-26,37", "1:-78,-41"]
        contexte.recents = ["/zaap -31,-56 ; /travel -31,-57", "/invite Brok; /invite Cid", "%pos%"]
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        contexte.quetes = QuetesDofusDB.gardees()
        return contexte
    }

    /// Une équipe d'exemple, pour la barre et l'onglet Raccourcis.
    private func equipe() {
        let persos = [("Syn-App", "Feca"), ("Syn-Ops", "Huppermage"), ("Brok", "Iop"), ("Cid", "Eniripsa")]
        WindowManager.shared.poserPourCaptures(persos.enumerated().map { rang, perso in
            let pid = pid_t(90_000 + rang)
            return DofusClient(pid: pid, slotKey: "\(pid)#0", axWindow: .application(pid),
                               rawTitle: "\(perso.0) - \(perso.1) - 3.6.8.8 - Release", name: perso.0,
                               characterClass: perso.1, dormant: false)
        })
        // Le premier au premier plan : sa pastille est celle qu'on voit allumée.
        WindowManager.shared.frontmostPID = 90_000
        WindowManager.shared.frontmostIsDofus = true
    }

    @Test("Capture de la barre", .enabled(if: dossier != nil))
    func barre() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        equipe()
        let vue = BarView()
            .padding(24)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, .dark)
        try ecrire(vue, vers: dossier.appending(path: "barre.png"))
    }

    @Test("Captures de la palette", .enabled(if: dossier != nil))
    func palette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, requete) in [("palette-zaaps", ""), ("palette-travel", "/travel banque bonta"),
                               ("palette-commandes", "/"), ("palette-quetes", "/quete âme")] {
            let modele = PaletteModele(contexte: contexte(), requete: requete)
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                .environment(\.colorScheme, .dark)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    @Test("Capture d'une quête ouverte", .enabled(if: dossier != nil))
    func quete() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        // Une vraie quête si celles de DofusDB sont sur la machine, sinon
        // celle des tests : des textes et des coordonnées, aucun visuel.
        let gardees = QuetesDofusDB.gardees()
        let reelle = gardees.flatMap { quetes in
            quetes.quetes.first { $0.noms["fr"] == "L'éternelle moisson" }.map { quetes.fiche($0, en: .fr) }
        }
        let fiche = Self.sansCartes(try reelle ?? #require(try QuetesTests.quetes().fiche(18, en: .fr)))
        let premier = fiche.etapes.first?.objectifs.first?.id
        let vue = QueteVue(ficheImposee: fiche, etapeImposee: reelle == nil ? 1 : 0,
                           validesImposes: reelle == nil ? [101] : Set(premier.map { [$0] } ?? []))
            .frame(width: 360, height: 560)
            .padding(24)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, .dark)
        try ecrire(vue, vers: dossier.appending(path: "quete.png"))
    }

    /// Sans la vue des cartes : elle viendrait de DofusDB, et une capture du
    /// dépôt ne porte aucun visuel du jeu (CGU Dofus, art. 13.2).
    private static func sansCartes(_ fiche: FicheQuete) -> FicheQuete {
        FicheQuete(
            id: fiche.id, nom: fiche.nom, nomFrancais: fiche.nomFrancais, niveau: fiche.niveau, groupe: fiche.groupe,
            donjon: fiche.donjon, exigences: fiche.exigences, ressources: fiche.ressources,
            etapes: fiche.etapes.map { etape in
                FicheQuete.Etape(nom: etape.nom, description: etape.description, objectifs: etape.objectifs.map {
                    FicheQuete.Objectif(id: $0.id, texte: $0.texte, position: $0.position, carte: nil)
                }, recompenses: etape.recompenses)
            },
            suivantes: fiche.suivantes)
    }

    @Test("Capture du panneau de chasse", .enabled(if: dossier != nil))
    func chasse() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        ChasseModele.shared.departX = -2
        ChasseModele.shared.departY = 0
        let vue = ChasseVue()
            .padding(24)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .environment(\.colorScheme, .dark)
        try ecrire(vue, vers: dossier.appending(path: "chasse.png"))
    }

    @Test("Captures des réglages", .enabled(if: dossier != nil))
    func reglages() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        equipe()
        for (nom, section) in [("reglages-zaaps", SettingsSection.zaaps),
                               ("reglages-raccourcis", .raccourcis), ("reglages-lecture", .lecture)] {
            let vue = SettingsView(section: section)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .dark)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Par une fenêtre hors écran : `ImageRenderer` ne dessine ni champ de
    /// texte ni défilement, qui sont des vues AppKit.
    private func ecrire(_ vue: some View, vers url: URL) throws {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let hote = NSHostingView(rootView: vue)
        hote.frame = NSRect(origin: .zero, size: hote.fittingSize)
        let fenetre = NSWindow(contentRect: hote.frame, styleMask: .borderless, backing: .buffered, defer: false)
        fenetre.contentView = hote
        fenetre.appearance = NSAppearance(named: .darkAqua)
        hote.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let rep = try #require(hote.bitmapImageRepForCachingDisplay(in: hote.bounds))
        hote.cacheDisplay(in: hote.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
