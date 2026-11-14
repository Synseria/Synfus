import Testing
import Foundation
import Carbon.HIToolbox
@testable import Synfus

@MainActor
struct PreferencesTests {

    /// Stockage en mémoire : les tests ne touchent ni au disque ni aux réglages
    /// de la machine, et ne laissent aucun domaine derrière eux.
    private final class StockageMemoire: PreferencesStore {
        private var contenu: [String: Data] = [:]
        private(set) var ecritures = 0

        init(_ initial: [String: Data] = [:]) { contenu = initial }

        func donnees(pour cle: String) -> Data? { contenu[cle] }
        func enregistrer(_ donnees: Data, pour cle: String) {
            contenu[cle] = donnees
            ecritures += 1
        }
    }

    /// Réglages neufs, adossés à un stockage vide.
    private func neuves() -> (Preferences, StockageMemoire) {
        let store = StockageMemoire()
        return (Preferences.forTesting(store: store), store)
    }

    @Test("Sans rien d'enregistré, chaque emplacement a son chiffre, ⌘1 à ⌘0")
    func premierLancement() {
        let (prefs, _) = neuves()
        #expect(prefs.hotKeys.count == HotKey.digitRow.count)
        #expect(prefs.hotKeys[0] == HotKey(keyCode: 18, modifiers: UInt32(cmdKey)))
        #expect(prefs.hotKeys[9] == HotKey(keyCode: 29, modifiers: UInt32(cmdKey)))
        #expect(prefs.characterOrder.isEmpty)
    }

    /// Toute la navigation tient sur la touche sous Échap, différenciée par les
    /// modificateurs, et laisse la rangée de chiffres à l'accès direct.
    @Test("Le jeu de raccourcis par défaut tient sur la touche sous Échap")
    func raccourcisParDefaut() {
        let (prefs, _) = neuves()
        let echap = HotKey.escapeRowKey
        #expect(prefs.cycleNext == HotKey(keyCode: echap, modifiers: UInt32(cmdKey)))
        #expect(prefs.cyclePrevious
                == HotKey(keyCode: echap, modifiers: UInt32(cmdKey) | UInt32(shiftKey)))
        #expect(prefs.previewHotKey
                == HotKey(keyCode: echap, modifiers: UInt32(cmdKey) | UInt32(optionKey)))
        #expect(prefs.toggleAutoFocus
                == HotKey(keyCode: echap, modifiers: UInt32(cmdKey) | UInt32(controlKey)))
        // Aucun défaut ne pioche dans la rangée de chiffres : ⌘0 reste au
        // dixième emplacement.
        for defaut in [prefs.cycleNext, prefs.cyclePrevious, prefs.previewHotKey,
                       prefs.toggleAutoFocus].compactMap({ $0 }) {
            #expect(!HotKey.digitRow.contains(defaut.keyCode))
        }
        // Masquer la barre reste sans défaut : on ne confisque pas une
        // combinaison que personne n'a demandée.
        #expect(prefs.toggleBar == nil)
        // L'invitation, elle, a son ⌘: — hors de la rangée de chiffres.
        #expect(prefs.inviteHotKey == HotKey.defaultInvite)
        #expect(!HotKey.digitRow.contains(HotKey.defaultInvite.keyCode))
    }

    // MARK: - Reprise des anciens défauts

    /// ⌘@ servait à la bascule du passage automatique et le cycle vivait sur ⌃⇥.
    /// Une installation restée sur ces valeurs doit basculer sur le nouveau jeu.
    @Test("Une installation aux anciens défauts passe au nouveau jeu")
    func repriseDesDefauts() {
        let ancien = """
        {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,
         "slotCount":5,
         "cycleNext":{"keyCode":48,"modifiers":4096},
         "cyclePrevious":{"keyCode":48,"modifiers":4608},
         "toggleAutoFocus":{"keyCode":50,"modifiers":256}}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.cycleNext == HotKey.defaultCycleNext)
        #expect(prefs.cyclePrevious == HotKey.defaultCyclePrevious)
        #expect(prefs.toggleAutoFocus == HotKey.defaultToggleAutoFocus)
        #expect(prefs.previewHotKey == HotKey.defaultPreview)

        // La génération est inscrite dans la sauvegarde : la reprise ne se
        // rejoue pas au lancement suivant, où l'utilisateur est libre de
        // reprendre ⌃⇥ s'il le veut.
        let relues = Preferences.forTesting(store: store)
        relues.cycleNext = HotKey(keyCode: 48, modifiers: UInt32(controlKey))
        #expect(Preferences.forTesting(store: store).cycleNext
                == HotKey(keyCode: 48, modifiers: UInt32(controlKey)))
    }

    /// Un raccourci choisi à la main est un choix : la reprise ne doit pas
    /// passer par-dessus.
    @Test("Un raccourci personnalisé survit à la reprise des défauts")
    func repriseRespecteLesChoix() {
        let ancien = """
        {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,
         "slotCount":5,
         "cycleNext":{"keyCode":122,"modifiers":0},
         "previewHotKey":{"keyCode":120,"modifiers":0}}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.cycleNext == HotKey(keyCode: 122, modifiers: 0))
        #expect(prefs.previewHotKey == HotKey(keyCode: 120, modifiers: 0))
    }

    /// Une fois la reprise passée, effacer un raccourci le laisse effacé : sans
    /// la génération inscrite, chaque lancement le ressusciterait.
    @Test("Un raccourci effacé après la reprise ne revient pas")
    func raccourciEffaceApresReprise() {
        let (prefs, store) = neuves()
        prefs.toggleAutoFocus = nil
        prefs.previewHotKey = nil

        let relues = Preferences.forTesting(store: store)
        #expect(relues.toggleAutoFocus == nil)
        #expect(relues.previewHotKey == nil)
    }

    // MARK: - Emplacements

    /// Le nombre d'emplacements n'est plus un réglage : une ancienne sauvegarde
    /// qui en avait moins les complète, sans ressusciter un raccourci effacé.
    @Test("Une sauvegarde à deux emplacements est complétée jusqu'à ⌘0")
    func emplacementsCompletes() {
        let ancien = """
        {"characterOrder":[],"hotKeys":[{"keyCode":18,"modifiers":256},null],
         "barVisible":true,"showNumbers":true,"slotCount":2}
        """
        let prefs = Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(ancien.utf8)]))
        #expect(prefs.hotKeys.count == HotKey.digitRow.count)
        #expect(prefs.hotKeys[0] == HotKey(keyCode: 18, modifiers: 256))
        #expect(prefs.hotKeys[1] == nil)
        #expect(prefs.hotKeys[2] == HotKey.defaultHotKey(slot: 2))
    }

    // MARK: - Ordre des persos

    @Test("Un perso rencontré pour la première fois est ajouté en fin de liste")
    func enregistrementDesNouveaux() {
        let (prefs, _) = neuves()
        prefs.registerIfNeeded(names: ["Aeryn", "Nova"])
        prefs.registerIfNeeded(names: ["Nova", "Kaeli"])
        #expect(prefs.characterOrder == ["Aeryn", "Nova", "Kaeli"])
    }

    @Test("Réenregistrer les mêmes persos ne change rien")
    func enregistrementIdempotent() {
        let (prefs, _) = neuves()
        prefs.registerIfNeeded(names: ["Aeryn", "Nova"])
        let avant = prefs.characterOrder
        prefs.registerIfNeeded(names: ["Aeryn", "Nova"])
        #expect(prefs.characterOrder == avant)
    }

    @Test("La purge retire les entrées que le filtre rejette")
    func purge() {
        let (prefs, _) = neuves()
        prefs.characterOrder = ["Aeryn", "Dofus 3.3.4.9", "Nova", "Nova (2)"]
        prefs.purgeOrder(keeping: WindowTitle.isPersistableName)
        #expect(prefs.characterOrder == ["Aeryn", "Nova"])
    }

    /// Sans court-circuit, chaque démarrage réenregistrerait les préférences.
    @Test("Une purge sans rien à retirer n'écrit pas")
    func purgeInerte() {
        let (prefs, store) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova"]
        let avant = store.donnees(pour: Preferences.key)
        prefs.purgeOrder { _ in true }
        #expect(store.donnees(pour: Preferences.key) == avant)
    }

    @Test("Deux persos se permutent dans l'ordre")
    func permutation() {
        let (prefs, _) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova", "Kaeli"]
        prefs.swapOrder("Aeryn", "Kaeli")
        #expect(prefs.characterOrder == ["Kaeli", "Nova", "Aeryn"])

        // Un nom absent laisse l'ordre intact.
        prefs.swapOrder("Kaeli", "Inconnu")
        #expect(prefs.characterOrder == ["Kaeli", "Nova", "Aeryn"])
    }

    @Test("Un perso peut être oublié")
    func oubli() {
        let (prefs, _) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova"]
        prefs.forget(name: "Aeryn")
        #expect(prefs.characterOrder == ["Nova"])
    }

    @Test("Plusieurs persos s'oublient en une seule écriture")
    func oubliEnLot() {
        let (prefs, store) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova", "Kaeli"]
        prefs.equipes = [Equipe(membres: ["Aeryn", "Kaeli"])]
        prefs.forget(names: ["Aeryn", "Kaeli"])
        #expect(prefs.characterOrder == ["Nova"])
        // Les équipes suivent, comme pour un oubli unitaire.
        #expect(prefs.equipes.isEmpty)

        // Rien à retirer : rien n'est écrit — l'égalité des données le dit.
        let avant = store.donnees(pour: Preferences.key)
        prefs.forget(names: ["Inconnu"])
        #expect(store.donnees(pour: Preferences.key) == avant)
    }

    // MARK: - Persistance

    @Test("Les réglages survivent à un redémarrage")
    func allerRetour() {
        let (prefs, store) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova"]
        prefs.barVisible = false
        prefs.showClasses = false
        prefs.attentionAction = .focus
        prefs.barOnlyWithDofus = true
        prefs.autoCenterBar = false
        prefs.barOrigin = CGPoint(x: 120, y: 640)
        prefs.cyclePrevious = HotKey(keyCode: 48, modifiers: UInt32(shiftKey))
        prefs.menuBarIcon = .symbole
        prefs.iconeApp = IconeApp(motif: .couvee, fond: .transparent)

        // Même stockage, nouvelle instance : c'est ce que fait un relancement.
        let relu = Preferences.forTesting(store: store)
        #expect(relu.characterOrder == ["Aeryn", "Nova"])
        #expect(relu.barVisible == false)
        #expect(relu.showClasses == false)
        #expect(relu.attentionAction == .focus)
        #expect(relu.barOnlyWithDofus == true)
        #expect(relu.autoCenterBar == false)
        #expect(relu.barOrigin == CGPoint(x: 120, y: 640))
        #expect(relu.cyclePrevious == HotKey(keyCode: 48, modifiers: UInt32(shiftKey)))
        #expect(relu.menuBarIcon == .symbole)
        #expect(relu.iconeApp == IconeApp(motif: .couvee, fond: .transparent))
    }

    /// Les réglages ajoutés après coup sont facultatifs dans la sauvegarde : une
    /// sauvegarde ancienne doit se relire sans perdre le reste.
    @Test("Une sauvegarde amputée des clés récentes se relit")
    func compatibiliteAscendante() {
        let ancien = """
        {"characterOrder":["Aeryn"],"hotKeys":[],"barVisible":true,
         "showNumbers":true,"slotCount":2}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["Aeryn"])
        #expect(prefs.hotKeys.count == HotKey.digitRow.count)
        // Valeurs de repli des réglages apparus depuis.
        #expect(prefs.showClasses == true)
        #expect(prefs.attentionAction == .highlight)
        #expect(prefs.autoCenterBar == true)
        #expect(prefs.barOnlyWithDofus == false)
        #expect(prefs.menuBarIcon == .logo)
        #expect(prefs.iconeApp == .parDefaut)
        #expect(prefs.couleurDeLApp == Jetons.couleurParDefaut && prefs.fondsDeLApp == nil)
        // Masquer la barre reste sans défaut : on ne confisque aucune
        // combinaison réservée par le système sans qu'elle ait été demandée.
        #expect(prefs.toggleBar == nil)
        // L'aperçu d'ensemble, lui, reçoit son défaut à la reprise.
        #expect(prefs.previewHotKey == HotKey.defaultPreview)
        // L'aperçu réclame l'autorisation d'enregistrement de l'écran : il ne
        // s'active jamais tout seul à la faveur d'une mise à jour.
        #expect(prefs.showPreviewOnHover == false)
        // Le rangement des fenêtres : pas de raccourci confisqué, et rien à
        // rejouer tant qu'aucune disposition n'a été choisie.
        #expect(prefs.arrangeHotKey == nil)
        #expect(prefs.lastArrangement == nil)
        // Les équipes et les invitations : vides, sans raccourci d'équipe,
        // format standard — et ⌘: posé à la reprise, comme l'aperçu.
        #expect(prefs.equipes.isEmpty)
        #expect(prefs.equipeSuivanteHotKey == nil)
        #expect(prefs.inviteHotKey == HotKey.defaultInvite)
        #expect(prefs.inviteFormat == "/invite %nom")
    }

    @Test("Une invitation effacée exprès reste effacée à la reprise")
    func invitationEffacee() {
        let (prefs, store) = neuves()
        prefs.inviteHotKey = nil
        let relues = Preferences.forTesting(store: store)
        #expect(relues.inviteHotKey == nil)
    }

    @Test("Rétablir les défauts remet chaque raccourci, efface ceux sans défaut")
    func retablirLesDefauts() {
        let (prefs, _) = neuves()
        prefs.hotKeys[0] = nil
        prefs.cycleNext = HotKey(keyCode: 48, modifiers: UInt32(cmdKey))
        prefs.toggleBar = HotKey(keyCode: 40, modifiers: UInt32(cmdKey))
        prefs.inviteHotKey = nil

        prefs.resetShortcuts()
        #expect(prefs.hotKeys.count == HotKey.digitRow.count)
        #expect(prefs.hotKeys[0] == HotKey.defaultHotKey(slot: 0))
        #expect(prefs.cycleNext == HotKey.defaultCycleNext)
        #expect(prefs.toggleBar == nil)
        #expect(prefs.inviteHotKey == HotKey.defaultInvite)
        #expect(prefs.quetesHotKey == HotKey.defaultQuetes && prefs.chasseHotKey == HotKey.defaultChasse
                && prefs.bossHotKey == HotKey.defaultBoss)
    }

    @Test("Les équipes et l'invitation se relisent après un redémarrage")
    func equipesPersistent() {
        let (prefs, store) = neuves()
        prefs.equipes = [Equipe(membres: ["Aeryn", "Nova"]), Equipe(membres: ["Kaeli"])]
        prefs.inviteFormat = "/w %nom go"
        prefs.inviteHotKey = HotKey(keyCode: 34, modifiers: UInt32(cmdKey))

        let relues = Preferences.forTesting(store: store)
        #expect(relues.equipes == [Equipe(membres: ["Aeryn", "Nova"]), Equipe(membres: ["Kaeli"])])
        #expect(relues.inviteFormat == "/w %nom go")
        #expect(relues.inviteHotKey == HotKey(keyCode: 34, modifiers: UInt32(cmdKey)))
    }

    @Test("Oublier ou purger un perso le retire de ses équipes")
    func equipesSuiventLOrdre() {
        let (prefs, _) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova", "Kaeli"]
        prefs.equipes = [Equipe(membres: ["Aeryn", "Nova"]), Equipe(membres: ["Kaeli"])]
        prefs.forget(name: "Kaeli")
        #expect(prefs.equipes == [Equipe(membres: ["Aeryn", "Nova"])])
        prefs.purgeOrder { $0 != "Aeryn" }
        #expect(prefs.equipes == [Equipe(membres: ["Nova"])])
    }

    @Test("Réaffecter un perso à la même équipe n'écrit pas")
    func affectationInerte() {
        let (prefs, store) = neuves()
        prefs.equipes = [Equipe(membres: ["Aeryn"])]
        let avant = store.donnees(pour: Preferences.key)
        prefs.affecter("Aeryn", aEquipe: 0)
        #expect(store.donnees(pour: Preferences.key) == avant)
        prefs.affecter("Nova", aEquipe: 1)
        #expect(prefs.equipes == [Equipe(membres: ["Aeryn"]), Equipe(membres: ["Nova"])])
    }

    @Test("Le rangement des fenêtres se relit après un redémarrage")
    func rangementPersiste() {
        let (prefs, store) = neuves()
        prefs.lastArrangement = .principale
        prefs.arrangeHotKey = HotKey(keyCode: 40, modifiers: UInt32(cmdKey))

        let relues = Preferences.forTesting(store: store)
        #expect(relues.lastArrangement == .principale)
        #expect(relues.arrangeHotKey == HotKey(keyCode: 40, modifiers: UInt32(cmdKey)))
    }

    @Test("Les zaaps favoris se relisent dans leur ordre, les clés inconnues sautées")
    func zaapsFavorisPersistent() {
        let (prefs, store) = neuves()
        prefs.zaapsFavoris = ["1:5,-18", "1:99,99", "1:-2,0"]

        let relues = Preferences.forTesting(store: store)
        #expect(relues.zaapsFavoris == ["1:5,-18", "1:99,99", "1:-2,0"])
        // La carte du store se lit en tâche de fond au lancement : celle du dépôt.
        #expect(CatalogueZaaps.favoris(relues.zaapsFavoris, parmi: Carte.integree.zaaps).map(\.cle) == ["1:5,-18", "1:-2,0"])
    }

    @Test("Les réglages d'aperçu se relisent après un redémarrage")
    func apercusPersistes() {
        let (prefs, store) = neuves()
        prefs.showPreviewOnHover = true
        prefs.previewHotKey = HotKey(keyCode: 49, modifiers: UInt32(optionKey))
        prefs.toggleBar = HotKey(keyCode: 11, modifiers: UInt32(cmdKey) | UInt32(shiftKey))

        let relues = Preferences.forTesting(store: store)
        #expect(relues.showPreviewOnHover == true)
        #expect(relues.previewHotKey == HotKey(keyCode: 49, modifiers: UInt32(optionKey)))
        #expect(relues.toggleBar == HotKey(keyCode: 11, modifiers: UInt32(cmdKey) | UInt32(shiftKey)))
    }

    @Test("La lecture de l'écran est éteinte par défaut, et ses zones se relisent")
    func lectureEcranPersistee() {
        let (prefs, store) = neuves()
        #expect(prefs.lirePosition == false)
        #expect(prefs.lireCombat == false)
        #expect(prefs.zonePosition == nil)
        prefs.lireCombat = true
        prefs.zoneCombat = ZoneEcran(x: 0.1, y: 0.8, largeur: 0.2, hauteur: 0.1)

        let relues = Preferences.forTesting(store: store)
        #expect(relues.lireCombat == true)
        #expect(relues.zoneCombat == ZoneEcran(x: 0.1, y: 0.8, largeur: 0.2, hauteur: 0.1))
        #expect(relues.zonePosition == nil)
    }

    /// L'enchaînement au clic installe un moniteur global de souris : il ne
    /// doit jamais s'activer tout seul à la faveur d'une mise à jour, pas plus
    /// que les aperçus. Et la touche à tenir est `fn`, la seule que le jeu
    /// ignore sur un clic.
    @Test("L'enchaînement au clic est éteint par défaut, sur fn, et se relit")
    func enchainementAuClic() {
        let (prefs, store) = neuves()
        #expect(prefs.advanceOnClick == false)
        #expect(prefs.advanceModifier == .fn)

        prefs.advanceOnClick = true
        prefs.advanceModifier = .option

        let relues = Preferences.forTesting(store: store)
        #expect(relues.advanceOnClick == true)
        #expect(relues.advanceModifier == .option)
    }

    /// Le mode « enchaîner » d'avant était une bascule armée par un raccourci,
    /// `advanceArmHotKey`. Une sauvegarde qui porte encore cette clé se relit
    /// sans broncher, la fonction sur son nouveau défaut.
    @Test("Une sauvegarde de l'ancien mode « enchaîner » se relit")
    func ancienModeEnchainer() {
        let ancien = """
        {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,
         "slotCount":5,"defaultsVersion":6,"advanceOnClick":true,
         "advanceArmHotKey":{"keyCode":50,"modifiers":256}}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.advanceOnClick == true)
        #expect(prefs.advanceModifier == .fn)
    }

    /// Les clés de la liaison Stream Deck, retirée, restent dans les
    /// sauvegardes existantes : elles doivent être ignorées, pas faire
    /// retomber l'ensemble sur les défauts.
    @Test("Une sauvegarde portant les clés du Stream Deck se relit")
    func anciennesClesStreamDeck() {
        let ancien = """
        {"characterOrder":["Alpha","Beta"],"hotKeys":[],"barVisible":true,"showNumbers":true,
         "slotCount":7,"defaultsVersion":6,
         "streamDeckEnabled":true,"appuiLongMs":150,"appuiTresLongMs":300,
         "appuiProgressif":false,"deckTitres":true,
         "spellKeyMap":{"barres":[[{"keyCode":18,"modifiers":0}]]},
         "gameCommands":[{"nom":"Inventaire","symbole":"bag","touche":null}],
         "deck":{"kind":"parBarre","pages":[0,1]}}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.characterOrder == ["Alpha", "Beta"])
    }

    @Test("Une sauvegarde illisible ramène aux valeurs par défaut")
    func sauvegardeIllisible() {
        let store = StockageMemoire([Preferences.key: Data("pas du JSON".utf8)])
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.hotKeys.count == HotKey.digitRow.count)
    }

    // MARK: - Empreinte de la sauvegarde

    /// Le JSON ramené à une forme canonique — clés triées, espaces retirés —
    /// pour comparer ce qui est écrit sans dépendre de l'ordre d'émission.
    private func canonique(_ donnees: Data?) -> String? {
        guard let donnees,
              let objet = try? JSONSerialization.jsonObject(with: donnees),
              let rendu = try? JSONSerialization.data(withJSONObject: objet, options: [.sortedKeys])
        else { return nil }
        return String(bytes: rendu, encoding: .utf8)
    }

    /// Chaque réglage à une valeur autre que son défaut, écrit tel qu'une
    /// sauvegarde le porte. Les raccourcis sont des keycodes explicites : les
    /// défauts dépendent du type de clavier de la machine.
    private static let empreinte = """
    {"advanceModifier":"option","advanceOnClick":true,
     "arrangeHotKey":{"keyCode":40,"modifiers":256},"attentionAction":"focus",
     "autoCenterBar":false,"barOnlyWithDofus":true,"panneauxSeulementDofus":false,"barOriginX":120.5,"barOriginY":640,
     "barVisible":false,"bossChoisi":"kimbo","nomsBossChoisi":{"fr":"Bouftou Royal"},
     "boutonsMasques":["quetes","boss","chasse","palette"],"characterOrder":["Aeryn","Nova"],
     "chasseHotKey":{"keyCode":5,"modifiers":2048},
     "cycleNext":{"keyCode":122,"modifiers":0},"cyclePrevious":{"keyCode":120,"modifiers":0},
     "defaultsVersion":9,"equipeSuivanteHotKey":{"keyCode":17,"modifiers":256},
     "etiquettes":{"1:-78,-41":"Fri 1"},"lieuxFavoris":["lieu:2738"],"pnjsFavoris":["pnj:6309"],
     "paletteHotKey":{"keyCode":47,"modifiers":256},"paletteRecents":["/zaap 5,7"],"paletteTri":"type",
     "paletteFrequentation":{"lieu:2738":{"dernier":12,"fois":3}},"quetesEpinglees":[18,42],"quetesEtape":{"18":2},
     "quetesValides":{"18":[102,104]},"quetesMasquerObjets":true,
     "quetesCompact":false,"quetesConsigne":false,"quetesVignettes":true,
     "quetesEnCours":{"18":104},"quetesCocherSuivi":false,"quetesDecoches":{"18":[103]},"quetesCochesLues":{"18":[104]},"quetesRessourcesCochees":{"18":[1747]},
     "equipes":[{"membres":["Aeryn"]},{"membres":["Nova"]}],
     "hotKeys":[{"keyCode":18,"modifiers":256},null,{"keyCode":20,"modifiers":2048},null,null,null,null,null,null,null],
     "inviteFormat":"/w %nom go","inviteGroupee":true,
     "inviteHotKey":{"keyCode":34,"modifiers":256},
     "killFrozenClients":false,"lastArrangement":"principale","lireCombat":true,"lireCombatDerriere":true,
     "lirePosition":true,"menuBarIcon":"symbole","iconeApp":{"motif":"couvee","fond":"aube"},"apparence":"sombre","couleurDeLApp":"teinte:210","fondsDeLApp":"nuit",
     "previewHotKey":{"keyCode":49,"modifiers":2048},
     "sessionHotKey":{"keyCode":1,"modifiers":256},"reduirePersosInactifs":false,"showClasses":false,
     "showNumbers":false,"showPreviewOnHover":true,"signalerBascule":false,
     "toggleAutoFocus":{"keyCode":99,"modifiers":0},
     "zaapAuto":true,"zaapGainMinimal":8,"zaapDuJeu":false,"zaapIntercalees":"/a ; /b","verifierMisesAJour":false,"derniereVersionLancee":"0.11.0","derniereVerificationMaj":800000000,"partagerStatistiques":false,
     "zaapHotKey":{"keyCode":17,"modifiers":2048},
     "zaapsAjoutes":[{"monde":1,"noms":{"fr":"Mon zaap"},"x":50,"y":-50,"zone":{}}],
     "zaapsChoix":{"1:-2,0":false},
     "zaapsFavoris":["1:5,-18","1:-2,0"],"zaapsVueCarte":false,
     "toggleBar":{"keyCode":11,"modifiers":768},
     "zoneCombat":{"hauteur":0.125,"largeur":0.25,"x":0.125,"y":0.75},
     "zonePosition":{"hauteur":0.0625,"largeur":0.25,"x":0.5,"y":0.25},
     "zoneChasse":{"hauteur":0.5,"largeur":0.25,"x":0,"y":0.125},
     "zoneQuetes":{"hauteur":0.625,"largeur":0.25,"x":0,"y":0.125}}
    """

    /// Les dix emplacements de l'empreinte : la sauvegarde relue les complète
    /// toujours jusqu'à dix.
    private static let raccourcisEmpreinte: [HotKey?] =
        [HotKey(keyCode: 18, modifiers: 256), nil, HotKey(keyCode: 20, modifiers: 2048)]
        + Array(repeating: nil, count: HotKey.digitRow.count - 3)

    /// Vérifie que `prefs` porte exactement les valeurs de `empreinte`.
    private func porteLEmpreinte(_ prefs: Preferences) {
        #expect(prefs.characterOrder == ["Aeryn", "Nova"])
        #expect(prefs.hotKeys == Self.raccourcisEmpreinte)
        #expect(prefs.cycleNext == HotKey(keyCode: 122, modifiers: 0))
        #expect(prefs.cyclePrevious == HotKey(keyCode: 120, modifiers: 0))
        #expect(prefs.barVisible == false)
        #expect(prefs.barOrigin == CGPoint(x: 120.5, y: 640))
        #expect(prefs.showNumbers == false)
        #expect(prefs.showClasses == false)
        #expect(prefs.attentionAction == .focus)
        #expect(prefs.toggleAutoFocus == HotKey(keyCode: 99, modifiers: 0))
        #expect(prefs.toggleBar == HotKey(keyCode: 11, modifiers: 768))
        #expect(prefs.barOnlyWithDofus == true)
        #expect(prefs.panneauxSeulementDofus == false)
        #expect(prefs.autoCenterBar == false)
        #expect(prefs.menuBarIcon == .symbole)
        #expect(prefs.iconeApp == IconeApp(motif: .couvee, fond: .aube))
        #expect(prefs.apparence == .sombre)
        #expect(prefs.couleurDeLApp == .teinte(210) && prefs.fondsDeLApp == .nuit)
        #expect(prefs.showPreviewOnHover == true)
        #expect(prefs.previewHotKey == HotKey(keyCode: 49, modifiers: 2048))
        #expect(prefs.advanceOnClick == true)
        #expect(prefs.advanceModifier == .option)
        #expect(prefs.signalerBascule == false)
        #expect(prefs.lirePosition == true)
        #expect(prefs.lireCombat == true)
        #expect(prefs.zonePosition == ZoneEcran(x: 0.5, y: 0.25, largeur: 0.25, hauteur: 0.0625))
        #expect(prefs.zoneCombat == ZoneEcran(x: 0.125, y: 0.75, largeur: 0.25, hauteur: 0.125))
        #expect(prefs.zoneChasse == ZoneEcran(x: 0, y: 0.125, largeur: 0.25, hauteur: 0.5))
        #expect(prefs.zoneQuetes == ZoneEcran(x: 0, y: 0.125, largeur: 0.25, hauteur: 0.625))
        #expect(prefs.killFrozenClients == false)
        #expect(prefs.lastArrangement == .principale)
        #expect(prefs.arrangeHotKey == HotKey(keyCode: 40, modifiers: 256))
        #expect(prefs.sessionHotKey == HotKey(keyCode: 1, modifiers: 256))
        #expect(prefs.equipes == [Equipe(membres: ["Aeryn"]), Equipe(membres: ["Nova"])])
        #expect(prefs.equipeSuivanteHotKey == HotKey(keyCode: 17, modifiers: 256))
        #expect(prefs.inviteHotKey == HotKey(keyCode: 34, modifiers: 256))
        #expect(prefs.inviteFormat == "/w %nom go")
        #expect(prefs.inviteGroupee == true)
        #expect(prefs.zaapHotKey == HotKey(keyCode: 17, modifiers: 2048))
        #expect(prefs.zaapAuto == true)
        #expect(prefs.zaapGainMinimal == 8)
        #expect(prefs.zaapDuJeu == false)
        #expect(prefs.zaapIntercalees == "/a ; /b")
        #expect(prefs.verifierMisesAJour == false)
        #expect(prefs.partagerStatistiques == false)
        #expect(prefs.derniereVersionLancee == "0.11.0")
        #expect(prefs.zaapsAjoutes == [Zaap(50, -50, noms: ["fr": "Mon zaap"])])
        #expect(prefs.zaapsChoix == ["1:-2,0": false])
        #expect(prefs.zaapsFavoris == ["1:5,-18", "1:-2,0"])
        #expect(prefs.etiquettes == ["1:-78,-41": "Fri 1"])
        #expect(prefs.lieuxFavoris == ["lieu:2738"])
        #expect(prefs.pnjsFavoris == ["pnj:6309"])
        #expect(prefs.paletteHotKey == HotKey(keyCode: 47, modifiers: 256))
        #expect(prefs.paletteRecents == ["/zaap 5,7"])
        #expect(prefs.paletteTri == .type)
        #expect(prefs.paletteFrequentation == FrequentationPalette(["lieu:2738": .init(fois: 3, dernier: 12)]))
        #expect(prefs.quetesEpinglees == [18, 42])
        #expect(prefs.quetesEtape == ["18": 2])
        #expect(prefs.quetesValides == ["18": [102, 104]])
        #expect(prefs.quetesMasquerObjets == true)
        #expect(prefs.quetesCompact == false)
        #expect(prefs.quetesConsigne == false)
        #expect(prefs.quetesVignettes == true)
        #expect(prefs.quetesEnCours == ["18": 104])
        #expect(prefs.quetesCocherSuivi == false)
        #expect(prefs.quetesDecoches == ["18": [103]])
        #expect(prefs.quetesCochesLues == ["18": [104]])
        #expect(prefs.quetesRessourcesCochees == ["18": [1747]])
        #expect(prefs.chasseHotKey == HotKey(keyCode: 5, modifiers: 2048))
        #expect(prefs.bossChoisi == .special(.kimbo))
        #expect(prefs.nomsBossChoisi == ["fr": "Bouftou Royal"])
        #expect(prefs.boutonsMasques == [.quetes, .boss, .chasse, .palette])
        #expect(prefs.lireCombatDerriere == true)
        #expect(prefs.vuesCartes == false)
    }

    @Test("Chaque réglage s'écrit sous sa clé, avec son encodage")
    func empreinteEcrite() {
        let (prefs, store) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova"]
        prefs.hotKeys = Self.raccourcisEmpreinte
        prefs.cycleNext = HotKey(keyCode: 122, modifiers: 0)
        prefs.cyclePrevious = HotKey(keyCode: 120, modifiers: 0)
        prefs.barVisible = false
        prefs.barOrigin = CGPoint(x: 120.5, y: 640)
        prefs.showNumbers = false
        prefs.showClasses = false
        prefs.attentionAction = .focus
        prefs.toggleAutoFocus = HotKey(keyCode: 99, modifiers: 0)
        prefs.toggleBar = HotKey(keyCode: 11, modifiers: 768)
        prefs.barOnlyWithDofus = true
        prefs.panneauxSeulementDofus = false
        prefs.autoCenterBar = false
        prefs.menuBarIcon = .symbole
        prefs.iconeApp = IconeApp(motif: .couvee, fond: .aube)
        prefs.apparence = .sombre
        prefs.couleurDeLApp = .teinte(210)
        prefs.fondsDeLApp = .nuit
        prefs.showPreviewOnHover = true
        prefs.previewHotKey = HotKey(keyCode: 49, modifiers: 2048)
        prefs.advanceOnClick = true
        prefs.advanceModifier = .option
        prefs.signalerBascule = false
        prefs.lirePosition = true
        prefs.lireCombat = true
        prefs.zonePosition = ZoneEcran(x: 0.5, y: 0.25, largeur: 0.25, hauteur: 0.0625)
        prefs.zoneCombat = ZoneEcran(x: 0.125, y: 0.75, largeur: 0.25, hauteur: 0.125)
        prefs.zoneChasse = ZoneEcran(x: 0, y: 0.125, largeur: 0.25, hauteur: 0.5)
        prefs.zoneQuetes = ZoneEcran(x: 0, y: 0.125, largeur: 0.25, hauteur: 0.625)
        prefs.killFrozenClients = false
        prefs.lastArrangement = .principale
        prefs.arrangeHotKey = HotKey(keyCode: 40, modifiers: 256)
        prefs.sessionHotKey = HotKey(keyCode: 1, modifiers: 256)
        prefs.equipes = [Equipe(membres: ["Aeryn"]), Equipe(membres: ["Nova"])]
        prefs.equipeSuivanteHotKey = HotKey(keyCode: 17, modifiers: 256)
        prefs.inviteHotKey = HotKey(keyCode: 34, modifiers: 256)
        prefs.inviteFormat = "/w %nom go"
        prefs.inviteGroupee = true
        prefs.zaapHotKey = HotKey(keyCode: 17, modifiers: 2048)
        prefs.zaapAuto = true
        prefs.zaapGainMinimal = 8
        prefs.zaapDuJeu = false
        prefs.zaapIntercalees = "/a ; /b"
        prefs.verifierMisesAJour = false
        prefs.partagerStatistiques = false
        prefs.derniereVersionLancee = "0.11.0"
        prefs.derniereVerificationMaj = Date(timeIntervalSinceReferenceDate: 800_000_000)
        prefs.zaapsAjoutes = [Zaap(50, -50, noms: ["fr": "Mon zaap"])]
        prefs.zaapsChoix = ["1:-2,0": false]
        prefs.zaapsFavoris = ["1:5,-18", "1:-2,0"]
        prefs.etiquettes = ["1:-78,-41": "Fri 1"]
        prefs.lieuxFavoris = ["lieu:2738"]
        prefs.pnjsFavoris = ["pnj:6309"]
        prefs.paletteHotKey = HotKey(keyCode: 47, modifiers: 256)
        prefs.paletteRecents = ["/zaap 5,7"]
        prefs.paletteTri = .type
        prefs.paletteFrequentation = FrequentationPalette(["lieu:2738": .init(fois: 3, dernier: 12)])
        prefs.quetesEpinglees = [18, 42]
        prefs.quetesEtape = ["18": 2]
        prefs.quetesValides = ["18": [102, 104]]
        prefs.quetesMasquerObjets = true
        prefs.quetesCompact = false
        prefs.quetesConsigne = false
        prefs.quetesVignettes = true
        prefs.quetesEnCours = ["18": 104]
        prefs.quetesCocherSuivi = false
        prefs.quetesDecoches = ["18": [103]]
        prefs.quetesCochesLues = ["18": [104]]
        prefs.quetesRessourcesCochees = ["18": [1747]]
        prefs.chasseHotKey = HotKey(keyCode: 5, modifiers: 2048)
        prefs.quetesHotKey = nil
        prefs.bossHotKey = nil
        prefs.bossChoisi = .special(.kimbo)
        prefs.nomsBossChoisi = ["fr": "Bouftou Royal"]
        prefs.boutonsMasques = [.palette, .chasse, .boss, .quetes]
        prefs.lireCombatDerriere = true
        prefs.vuesCartes = false

        #expect(canonique(store.donnees(pour: Preferences.key))
                == canonique(Data(Self.empreinte.utf8)))
    }

    /// Un réglage optionnel à `nil` est **absent** de la sauvegarde, pas écrit
    /// `null` — et `barOrigin` n'y laisse aucune de ses deux coordonnées.
    @Test("Un réglage sans valeur n'est pas écrit")
    func empreinteSansValeurs() {
        let (prefs, store) = neuves()
        prefs.hotKeys = [nil]
        for chemin: ReferenceWritableKeyPath<Preferences, HotKey?> in [
            \.cycleNext, \.cyclePrevious, \.toggleAutoFocus, \.toggleBar, \.previewHotKey,
            \.arrangeHotKey, \.sessionHotKey, \.equipeSuivanteHotKey, \.inviteHotKey, \.zaapHotKey, \.paletteHotKey,
            \.chasseHotKey, \.bossHotKey, \.quetesHotKey,
        ] {
            prefs[keyPath: chemin] = nil
        }
        prefs.barOrigin = nil

        let attendu = """
        {"advanceModifier":"fn","advanceOnClick":false,"attentionAction":"highlight",
         "autoCenterBar":true,"barOnlyWithDofus":false,"panneauxSeulementDofus":true,"barVisible":true,"bossChoisi":"harebourg",
         "boutonsMasques":[],"characterOrder":[],
         "defaultsVersion":9,"equipes":[],"etiquettes":{},"hotKeys":[null],"inviteFormat":"/invite %nom","inviteGroupee":false,
         "killFrozenClients":true,"lireCombat":false,"lireCombatDerriere":false,"lirePosition":false,"menuBarIcon":"logo","iconeApp":{"motif":"oeuf","fond":"transparent"},"apparence":"auto","couleurDeLApp":"jade",
         "reduirePersosInactifs":false,"showClasses":true,"showNumbers":true,"showPreviewOnHover":false,
         "signalerBascule":true,"zaapAuto":false,
         "zaapGainMinimal":5,"zaapDuJeu":true,"zaapIntercalees":"/a","verifierMisesAJour":true,"partagerStatistiques":true,"zaapsAjoutes":[],"zaapsChoix":{},"zaapsFavoris":[],"zaapsVueCarte":true,
         "lieuxFavoris":[],"pnjsFavoris":[],"paletteRecents":[],"paletteTri":"auto","paletteFrequentation":{},"quetesEpinglees":[],"quetesEtape":{},
         "quetesValides":{},"quetesMasquerObjets":false,
         "quetesCompact":true,"quetesConsigne":true,"quetesVignettes":false,
         "quetesEnCours":{},"quetesCocherSuivi":true,"quetesDecoches":{},"quetesCochesLues":{},"quetesRessourcesCochees":{}}
        """
        #expect(canonique(store.donnees(pour: Preferences.key)) == canonique(Data(attendu.utf8)))
    }

    /// Une sauvegarde complète, plus des clés que Synfus ne connaît pas (celles
    /// du Stream Deck, de l'ancien mode « enchaîner ») : chaque valeur est
    /// relue, et la réécriture rend la même sauvegarde, inconnues en moins.
    @Test("Une sauvegarde complète se relit et se réécrit à l'identique")
    func empreinteRelue() throws {
        var objet = try #require(
            try JSONSerialization.jsonObject(with: Data(Self.empreinte.utf8)) as? [String: Any])
        objet["streamDeckEnabled"] = true
        objet["appuiLongMs"] = 150
        objet["spellKeyMap"] = ["barres": [[["keyCode": 18, "modifiers": 0]]]]
        objet["advanceArmHotKey"] = ["keyCode": 50, "modifiers": 256]
        // La liste de zaaps téléchargée vit désormais dans la carte, sur le disque.
        objet["zaapsDofusDB"] = ["date": 800_000_000, "zaaps": [] as [Any]]
        let ancien = try JSONSerialization.data(withJSONObject: objet)
        let store = StockageMemoire([Preferences.key: ancien])

        let prefs = Preferences.forTesting(store: store)
        porteLEmpreinte(prefs)

        prefs.barVisible = prefs.barVisible
        #expect(canonique(store.donnees(pour: Preferences.key))
                == canonique(Data(Self.empreinte.utf8)))
    }

    /// Les quatre clés des toutes premières sauvegardes encore lues sont obligatoires : sans
    /// l'une d'elles, la sauvegarde est tenue pour illisible, entière.
    @Test("Une sauvegarde privée d'une clé d'origine ramène aux défauts")
    func cleOrigineManquante() throws {
        for cle in ["characterOrder", "hotKeys", "barVisible", "showNumbers"] {
            var objet = try #require(
                try JSONSerialization.jsonObject(with: Data(Self.empreinte.utf8)) as? [String: Any])
            objet[cle] = nil
            let store = StockageMemoire([Preferences.key: try JSONSerialization.data(withJSONObject: objet)])
            let prefs = Preferences.forTesting(store: store)
            #expect(prefs.hotKeys[1] == HotKey.defaultHotKey(slot: 1), "sans \(cle)")
            #expect(prefs.characterOrder.isEmpty, "sans \(cle)")
            #expect(prefs.showClasses == true, "sans \(cle)")
        }
    }

    /// Une valeur du mauvais type rend la sauvegarde illisible, entière ; un
    /// `null` vaut une clé absente.
    @Test("Une valeur mal typée ramène aux défauts, un null vaut une absence")
    func valeurMalTypee() throws {
        var objet = try #require(
            try JSONSerialization.jsonObject(with: Data(Self.empreinte.utf8)) as? [String: Any])
        objet["showClasses"] = "non"
        var store = StockageMemoire([Preferences.key: try JSONSerialization.data(withJSONObject: objet)])
        var prefs = Preferences.forTesting(store: store)
        #expect(prefs.hotKeys[1] == HotKey.defaultHotKey(slot: 1))
        #expect(prefs.showClasses == true)

        objet["showClasses"] = NSNull()
        objet["cycleNext"] = NSNull()
        objet["inviteFormat"] = NSNull()
        store = StockageMemoire([Preferences.key: try JSONSerialization.data(withJSONObject: objet)])
        prefs = Preferences.forTesting(store: store)
        #expect(prefs.hotKeys[1] == nil)
        #expect(prefs.showClasses == true)
        #expect(prefs.cycleNext == nil)
        #expect(prefs.inviteFormat == "/invite %nom")
    }

    /// `barOrigin` s'écrit en deux coordonnées : une seule ne suffit pas.
    @Test("Une origine de barre incomplète est ignorée")
    func origineIncomplete() throws {
        var objet = try #require(
            try JSONSerialization.jsonObject(with: Data(Self.empreinte.utf8)) as? [String: Any])
        objet["barOriginY"] = nil
        let store = StockageMemoire([Preferences.key: try JSONSerialization.data(withJSONObject: objet)])
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.barOrigin == nil)
        #expect(prefs.hotKeys[1] == nil)
    }
}

/// Les favoris de la palette, chacun dans sa liste.
extension PreferencesTests {
    @Test("Un favori va dans la liste de son genre : zaap, lieu ou PNJ, et en ressort")
    func favorisParGenre() {
        let (prefs, _) = neuves()
        for cle in ["1:5,7", "lieu:2738", "pnj:6309"] { prefs.basculerFavori(cle) }
        #expect(prefs.zaapsFavoris == ["1:5,7"] && prefs.lieuxFavoris == ["lieu:2738"] && prefs.pnjsFavoris == ["pnj:6309"])
        #expect(prefs.favoris == ["1:5,7", "lieu:2738", "pnj:6309"] && prefs.estFavori("pnj:6309"))
        prefs.basculerFavori("pnj:6309")
        #expect(prefs.pnjsFavoris.isEmpty && !prefs.estFavori("pnj:6309"))
    }
}

/// Les générations de défauts récentes, hors du corps de la suite.
extension PreferencesTests {
    /// La palette prend ⌘: en génération 7 ; l'invitation qui l'occupait passe
    /// à ⇧⌘:, une invitation personnalisée ne bouge pas.
    @Test("Génération 7 : ⌘: à la palette, l'invitation à ⇧⌘:")
    func generationPalette() {
        func relue(invite: String) -> Preferences {
            let ancien = """
            {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,
             "slotCount":5,"defaultsVersion":6,"inviteHotKey":\(invite)}
            """
            return Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(ancien.utf8)]))
        }
        let parDefaut = relue(invite: #"{"keyCode":47,"modifiers":256}"#)
        #expect(parDefaut.paletteHotKey == HotKey.defaultPalette)
        #expect(parDefaut.inviteHotKey == HotKey.defaultInvite)
        let choisie = relue(invite: #"{"keyCode":34,"modifiers":256}"#)
        #expect(choisie.inviteHotKey == HotKey(keyCode: 34, modifiers: 256))
        #expect(choisie.paletteHotKey == HotKey.defaultPalette)
    }
}

/// Le tri et les habitudes de la palette.
extension PreferencesTests {
    /// Une sauvegarde écrivait toujours son tri : l'ancien défaut passe à « Auto »,
    /// un autre choix reste, un tri inconnu laisse le défaut sans rendre la sauvegarde illisible.
    @Test("Génération 8 : le tri « Proximité » d'avant passe à « Auto », un autre choix reste")
    func generationTriAuto() {
        func relue(tri: String, generation: Int = 7) -> Preferences {
            let ancien = """
            {"characterOrder":["Aeryn"],"hotKeys":[],"barVisible":true,"showNumbers":true,
             "defaultsVersion":\(generation),"paletteTri":"\(tri)"}
            """
            return Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(ancien.utf8)]))
        }
        #expect(relue(tri: "proximite").paletteTri == .auto)
        #expect(relue(tri: "alphabetique").paletteTri == .alphabetique)
        #expect(relue(tri: "proximite", generation: 8).paletteTri == .proximite)
        let inconnu = relue(tri: "venuDuFutur")
        #expect(inconnu.paletteTri == .auto && inconnu.characterOrder == ["Aeryn"])
    }

    @Test("Les habitudes de la palette se relisent après sauvegarde")
    func frequentationRelue() {
        let (prefs, store) = neuves()
        prefs.paletteFrequentation.noter("lieu:2738")
        prefs.paletteFrequentation.noter("pnj:6309")
        prefs.paletteFrequentation.noter("lieu:2738")
        let relues = Preferences.forTesting(store: store)
        #expect(relues.paletteFrequentation.comptes == [
            "lieu:2738": .init(fois: 2, dernier: 3), "pnj:6309": .init(fois: 1, dernier: 2),
        ])
    }
}

/// Les coches, décoches, l'objectif en cours et l'étape des quêtes (`CochesQuete`).
extension PreferencesTests {
    private func lue(_ id: Int = 18, etape: Int? = nil, sure: Bool = false, aFaire: [Int] = [],
                     faits: [Int] = []) -> SuiviQuetes.Reconnue {
        .init(id: id, etape: etape, etapeSure: sure, aFaire: aFaire, faits: faits)
    }

    @Test("La lecture du suivi coche sans décocher ; cocher l'objectif en cours l'efface")
    func cochesQuete() {
        let (prefs, _) = neuves()
        prefs.cocher(3, de: 18, true)
        prefs.mettreEnCours(5, de: 18)
        #expect(prefs.quetesEnCours == ["18": 5])
        // Un objectif fait ne se met pas en cours.
        prefs.mettreEnCours(3, de: 18)
        #expect(prefs.quetesEnCours == ["18": 5])
        #expect(prefs.appliquer([lue(faits: [1, 3, 5, 1])]) == 2)
        #expect(prefs.quetesValides == ["18": [3, 1, 5]])
        #expect(prefs.quetesEnCours.isEmpty)
        #expect(prefs.appliquer([lue(faits: [1])]) == 0)
        prefs.mettreEnCours(7, de: 18)
        prefs.mettreEnCours(8, de: 18)
        #expect(prefs.quetesEnCours == ["18": 8])
        prefs.cocher(3, de: 18, false)
        prefs.cocher(1, de: 18, false)
        prefs.cocher(5, de: 18, false)
        #expect(prefs.quetesValides.isEmpty)
        prefs.quetesCocherSuivi = false
        #expect(prefs.appliquer([lue(faits: [9])]) == 0)
        #expect(prefs.quetesValides.isEmpty)
    }

    @Test("Une ressource se coche et se décoche par quête ; la dernière décochée ne laisse pas de clé")
    func ressourcesCochees() {
        let (prefs, _) = neuves()
        prefs.cocherRessource(1747, de: 18, true)
        prefs.cocherRessource(1747, de: 18, true)
        prefs.cocherRessource(2, de: 18, true)
        prefs.cocherRessource(1747, de: 42, true)
        #expect(prefs.quetesRessourcesCochees == ["18": [1747, 2], "42": [1747]])
        prefs.cocherRessource(2, de: 18, false)
        prefs.cocherRessource(1747, de: 42, false)
        #expect(prefs.quetesRessourcesCochees == ["18": [1747]])
    }

    @Test("Décoché à la main, un objectif ne se recoche plus à la lecture, jusqu'à ce que le suivi le remontre ouvert")
    func decoches() {
        let (prefs, _) = neuves()
        prefs.appliquer([lue(faits: [1, 2])])
        prefs.cocher(2, de: 18, false)
        #expect(prefs.quetesDecoches == ["18": [2]])
        #expect(prefs.appliquer([lue(faits: [1, 2])]) == 0)
        #expect(prefs.quetesValides == ["18": [1]])
        // Le suivi le montre ouvert : la décoche est oubliée, il se cochera
        // quand le suivi le dira fait.
        prefs.appliquer([lue(aFaire: [2, 3])])
        #expect(prefs.quetesDecoches.isEmpty)
        #expect(prefs.appliquer([lue(faits: [1, 2])]) == 1)
        // Recoché à la main : plus de décoche.
        prefs.cocher(2, de: 18, false)
        prefs.cocher(2, de: 18, true)
        #expect(prefs.quetesDecoches.isEmpty)
        #expect(prefs.quetesValides == ["18": [1, 2]])
    }

    @Test("Le suivi qui remontre ouvert un objectif coché par une lecture le décoche : ligne perdue par l'OCR, puis relue")
    func ligneRelue() {
        let (prefs, _) = neuves()
        // La ligne de l'objectif 2 perdue : il passe pour fait.
        #expect(prefs.appliquer([lue(aFaire: [3], faits: [1, 2])]) == 2)
        #expect(prefs.quetesValides == ["18": [1, 2]] && prefs.quetesCochesLues == ["18": [1, 2]])
        // Relue : il est ouvert, il se décoche ; 1 reste fait.
        #expect(prefs.appliquer([lue(aFaire: [2, 3], faits: [1])]) == 0)
        #expect(prefs.quetesValides == ["18": [1]] && prefs.quetesCochesLues == ["18": [1]])
        #expect(prefs.quetesDecoches.isEmpty)
        // Fait pour de bon, il se recoche à la lecture suivante.
        #expect(prefs.appliquer([lue(aFaire: [3], faits: [1, 2])]) == 1)
        #expect(prefs.quetesValides == ["18": [1, 2]])
    }

    @Test("Une coche posée à la main, ou d'une sauvegarde d'avant, ne se décoche jamais à la lecture")
    func cocheALaMainGardee() throws {
        let (prefs, _) = neuves()
        prefs.cocher(2, de: 18, true)
        prefs.appliquer([lue(aFaire: [2])])
        #expect(prefs.quetesValides == ["18": [2]])
        // Cochée par une lecture, puis décochée et recochée à la main : à la main.
        prefs.appliquer([lue(faits: [1])])
        prefs.cocher(1, de: 18, false)
        prefs.cocher(1, de: 18, true)
        prefs.appliquer([lue(aFaire: [1])])
        #expect(prefs.quetesValides == ["18": [2, 1]] && prefs.quetesCochesLues.isEmpty)
        // Une sauvegarde sans l'origine des coches : toutes tenues pour posées à la main.
        let ancien = #"{"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,"quetesValides":{"18":[5]}}"#
        let relue = Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(ancien.utf8)]))
        relue.appliquer([lue(aFaire: [5])])
        #expect(relue.quetesValides == ["18": [5]])
    }

    @Test("Un geste, une écriture : la coche qui touche plusieurs réglages, la lecture de plusieurs quêtes")
    func uneEcritureParGeste() {
        let (prefs, store) = neuves()
        prefs.appliquer([lue(faits: [1, 2])])
        prefs.cocher(2, de: 18, false)
        prefs.mettreEnCours(2, de: 18)
        // Recocher efface la décoche, coche et n'est plus en cours.
        var avant = store.ecritures
        prefs.cocher(2, de: 18, true)
        #expect(store.ecritures == avant + 1)
        #expect(prefs.quetesDecoches.isEmpty && prefs.quetesValides == ["18": [1, 2]] && prefs.quetesEnCours.isEmpty)
        avant = store.ecritures
        let coches = prefs.appliquer([lue(18, etape: 1, sure: true, faits: [3]), lue(19, faits: [4, 5]), lue(20, aFaire: [6])])
        #expect(coches == 3 && store.ecritures == avant + 1)
        #expect(prefs.quetesEtape == ["18": 1] && prefs.quetesValides["19"] == [4, 5])
        // Rien de changé, rien d'écrit.
        avant = store.ecritures
        prefs.appliquer([lue(19, faits: [4])])
        prefs.cocher(9, de: 30, false)
        #expect(store.ecritures == avant)
        // Hors d'un lot, chaque réglage s'écrit encore de lui-même.
        prefs.quetesCompact.toggle()
        #expect(store.ecritures == avant + 1)
    }

    @Test("Une étape établie après celle du panneau l'y fait avancer, jamais reculer ; une étape probable, non")
    func avanceeEtape() {
        let (prefs, _) = neuves()
        prefs.appliquer([lue(etape: 2, sure: false)])
        #expect(prefs.quetesEtape.isEmpty)
        prefs.appliquer([lue(etape: 2, sure: true)])
        #expect(prefs.quetesEtape == ["18": 2])
        prefs.appliquer([lue(etape: 1, sure: true)])
        #expect(prefs.quetesEtape == ["18": 2])
        prefs.appliquer([lue(etape: 0, sure: true)])
        #expect(prefs.quetesEtape == ["18": 2])
    }
}

/// Les boutons de la barre : un seul réglage, qui reprend les booléens d'avant.
extension PreferencesTests {
    @Test("Les boutons montrés gardent l'ordre de la barre")
    func boutonsAffiches() {
        #expect(BoutonBarre.affiches(sauf: []) == BoutonBarre.allCases)
        #expect(BoutonBarre.affiches(sauf: [.palette, .quetes])
                == [.boss, .chasse, .rangement, .passageAuto])
    }

    @Test("Chaque bouton a son dessin, et « map » reste à la page Carte")
    func symbolesDesBoutons() {
        let symboles = BoutonBarre.allCases.map(\.symbole)
        #expect(Set(symboles).count == symboles.count)
        #expect(!symboles.contains("map"))
    }

    @Test("L'infobulle d'un bouton : son nom, puis sa touche au bout quand elle existe")
    func infobulleDuBouton() {
        #expect(BoutonBarre.quetes.infobulle(touche: "⌥Q") == "\(BoutonBarre.quetes.libelle)  ⌥Q")
        #expect(BoutonBarre.boss.infobulle(touche: nil) == BoutonBarre.boss.libelle)
        #expect(BoutonBarre.passageAuto.infobulle(touche: "⌘²", nom: "Passage : activé") == "Passage : activé  ⌘²")
    }

    @Test("Le passage automatique se bascule entre « passer au perso » et « le signaler »")
    func basculePassageAuto() {
        let (prefs, _) = neuves()
        prefs.attentionAction = .highlight
        prefs.basculerPassageAuto()
        #expect(prefs.passageAuto && prefs.attentionAction == .focus)
        prefs.basculerPassageAuto()
        #expect(!prefs.passageAuto && prefs.attentionAction == .highlight)
        prefs.attentionAction = .ignore
        prefs.basculerPassageAuto()
        #expect(prefs.attentionAction == .focus)
    }

    @Test("Réduire les inactifs : désactivé par défaut, et la sauvegarde l'écrit")
    func reduirePersosInactifs() {
        let (prefs, store) = neuves()
        #expect(prefs.reduirePersosInactifs == false)
        prefs.reduirePersosInactifs = true
        let relu = Preferences.forTesting(store: store)
        #expect(relu.reduirePersosInactifs == true)
    }

    @Test("Une pastille réduite garde emblème et touche ; celle de devant et celle sans rien à montrer gardent leur nom")
    func pastilleReduite() {
        func vue(devant: Bool, reduire: Bool = true, embleme: Bool = true, touche: Bool = true) -> AffichagePastille {
            AffichagePastille(devant: devant, reduireInactifs: reduire, embleme: embleme, touche: touche, aUneClasse: true)
        }
        #expect(vue(devant: false).nom == false)
        #expect(vue(devant: false).classe == false)
        #expect(vue(devant: false).embleme && vue(devant: false).touche)
        #expect(vue(devant: true).nom && vue(devant: true).classe)
        #expect(vue(devant: false, reduire: false).nom)
        #expect(vue(devant: false, embleme: false, touche: false).nom)
        #expect(vue(devant: false, embleme: false).nom == false)
    }

    @Test("Masquer puis remontrer un bouton")
    func montrerBouton() {
        let (prefs, _) = neuves()
        prefs.montrer(.rangement, false)
        prefs.montrer(.boss, false)
        prefs.montrer(.boss, false)
        #expect(prefs.boutonsMasques == [.rangement, .boss])
        prefs.montrer(.rangement, true)
        #expect(prefs.boutonsMasques == [.boss])
    }

    /// Une sauvegarde d'avant `boutonsMasques` porte un booléen par bouton :
    /// ceux à `false` restent masqués, et la réécriture ne garde que la
    /// nouvelle clé.
    @Test("Les anciens booléens des boutons sont repris")
    func anciensBooleensDesBoutons() throws {
        let ancien = """
        {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,"defaultsVersion":7,
         "quetesBouton":false,"bossBouton":true,"chasseBouton":true,"zaapBouton":false}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.boutonsMasques == [.quetes, .palette])

        prefs.montrer(.boss, false)
        let donnees = try #require(store.donnees(pour: Preferences.key))
        let ecrit = try #require(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
        #expect(ecrit["boutonsMasques"] as? [String] == ["quetes", "boss", "palette"])
        for cle in ["quetesBouton", "bossBouton", "chasseBouton", "zaapBouton"] {
            #expect(ecrit[cle] == nil, "\(cle)")
        }
    }

    @Test("La nouvelle clé prime sur les anciens booléens ; un bouton inconnu est ignoré")
    func boutonsMasquesPrime() {
        let sauvegarde = """
        {"characterOrder":["Aeryn"],"hotKeys":[],"barVisible":true,"showNumbers":true,"defaultsVersion":7,
         "quetesBouton":false,"boutonsMasques":["chasse","venuDuFutur"]}
        """
        let prefs = Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(sauvegarde.utf8)]))
        #expect(prefs.boutonsMasques == [.chasse])
        #expect(prefs.characterOrder == ["Aeryn"])
    }
}

/// Les trois panneaux reçoivent ⌥⌘Q, ⌥⌘C et ⌥⌘B en génération 9.
extension PreferencesTests {
    private func relue(_ json: String) -> Preferences {
        Preferences.forTesting(store: StockageMemoire([Preferences.key: Data(json.utf8)]))
    }

    private static let base = #"{"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,"defaultsVersion":8"#

    @Test("Génération 9 : ⌥⌘Q, ⌥⌘C et ⌥⌘B à qui n'avait rien réglé")
    func generationPanneaux() {
        let prefs = relue(Self.base + "}")
        #expect(prefs.quetesHotKey == HotKey.defaultQuetes)
        #expect(prefs.chasseHotKey == HotKey.defaultChasse)
        #expect(prefs.bossHotKey == HotKey.defaultBoss)
        #expect(HotKey.defaultQuetes.modifiers == UInt32(cmdKey) | UInt32(optionKey))
    }

    @Test("Génération 9 : un choix reste, une combinaison déjà prise laisse le raccourci vide")
    func generationPanneauxRespecte() {
        let choisi = relue(Self.base + #","quetesHotKey":{"keyCode":34,"modifiers":256}}"#)
        #expect(choisi.quetesHotKey == HotKey(keyCode: 34, modifiers: 256))
        let prise = HotKey.defaultChasse
        let pris = relue(Self.base + #","arrangeHotKey":{"keyCode":\#(prise.keyCode),"modifiers":\#(prise.modifiers)}}"#)
        #expect(pris.chasseHotKey == nil)
        #expect(pris.bossHotKey == HotKey.defaultBoss)
        let effacee = relue(Self.base.replacingOccurrences(of: "8", with: "9") + "}")
        #expect(effacee.quetesHotKey == nil)
    }
}

extension PreferencesTests {
    @Test("Les réglages s'ouvrent au premier lancement, ou tant que l'accessibilité manque")
    func ouvertureAuLancement() {
        #expect(SettingsWindowController.ouvreAuLancement(premierLancement: true, accessibiliteAccordee: true))
        #expect(SettingsWindowController.ouvreAuLancement(premierLancement: false, accessibiliteAccordee: false))
        #expect(!SettingsWindowController.ouvreAuLancement(premierLancement: false, accessibiliteAccordee: true))
        #expect(Preferences.forTesting(store: StockageMemoire()).premierLancement)
    }
}
