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

        init(_ initial: [String: Data] = [:]) { contenu = initial }

        func donnees(pour cle: String) -> Data? { contenu[cle] }
        func enregistrer(_ donnees: Data, pour cle: String) { contenu[cle] = donnees }
    }

    /// Réglages neufs, adossés à un stockage vide.
    private func neuves() -> (Preferences, StockageMemoire) {
        let store = StockageMemoire()
        return (Preferences.forTesting(store: store), store)
    }

    @Test("Sans rien d'enregistré, les cinq premiers slots ont ⌘1 à ⌘5")
    func premierLancement() {
        let (prefs, _) = neuves()
        #expect(prefs.slotCount == 5)
        #expect(prefs.hotKeys.count == 5)
        #expect(prefs.hotKeys[0] == HotKey(keyCode: 18, modifiers: UInt32(cmdKey)))
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

    // MARK: - Nombre d'emplacements

    /// `@Published` remplace la propriété stockée par une propriété calculée :
    /// se réassigner depuis son propre `didSet` le redéclenche. Sans le drapeau
    /// `clamping`, ce test partirait en récursion infinie.
    @Test("Un nombre d'emplacements hors bornes est ramené sans boucler")
    func bornesDesEmplacements() {
        let (prefs, _) = neuves()

        prefs.slotCount = 99
        #expect(prefs.slotCount == HotKey.digitRow.count)

        prefs.slotCount = 0
        #expect(prefs.slotCount == 1)

        prefs.slotCount = -5
        #expect(prefs.slotCount == 1)
    }

    @Test("La liste des raccourcis suit le nombre d'emplacements")
    func redimensionnement() {
        let (prefs, _) = neuves()

        prefs.slotCount = 8
        #expect(prefs.hotKeys.count == 8)
        #expect(prefs.hotKeys[7] == HotKey.defaultHotKey(slot: 7))

        prefs.slotCount = 2
        #expect(prefs.hotKeys.count == 2)
    }

    /// Réduire puis réétendre ne doit pas ressusciter un raccourci effacé à la
    /// main : les nouveaux emplacements repartent du défaut.
    @Test("Un raccourci effacé ne revient pas tout seul")
    func raccourciEfface() {
        let (prefs, _) = neuves()
        prefs.hotKeys[1] = nil
        prefs.slotCount = 6
        #expect(prefs.hotKeys[1] == nil)
        #expect(prefs.hotKeys[5] == HotKey.defaultHotKey(slot: 5))
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

    // MARK: - Persistance

    @Test("Les réglages survivent à un redémarrage")
    func allerRetour() {
        let (prefs, store) = neuves()
        prefs.characterOrder = ["Aeryn", "Nova"]
        prefs.slotCount = 4
        prefs.barVisible = false
        prefs.showClasses = false
        prefs.attentionAction = .focus
        prefs.barOnlyWithDofus = true
        prefs.autoCenterBar = false
        prefs.barOrigin = CGPoint(x: 120, y: 640)
        prefs.cyclePrevious = HotKey(keyCode: 48, modifiers: UInt32(shiftKey))
        prefs.menuBarIcon = .symbole

        // Même stockage, nouvelle instance : c'est ce que fait un relancement.
        let relu = Preferences.forTesting(store: store)
        #expect(relu.characterOrder == ["Aeryn", "Nova"])
        #expect(relu.slotCount == 4)
        #expect(relu.barVisible == false)
        #expect(relu.showClasses == false)
        #expect(relu.attentionAction == .focus)
        #expect(relu.barOnlyWithDofus == true)
        #expect(relu.autoCenterBar == false)
        #expect(relu.barOrigin == CGPoint(x: 120, y: 640))
        #expect(relu.cyclePrevious == HotKey(keyCode: 48, modifiers: UInt32(shiftKey)))
        #expect(relu.menuBarIcon == .symbole)
    }

    /// Les réglages ajoutés après coup sont facultatifs dans `Stored` : une
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
        #expect(prefs.slotCount == 2)
        // Valeurs de repli des réglages apparus depuis.
        #expect(prefs.showClasses == true)
        #expect(prefs.attentionAction == .highlight)
        #expect(prefs.autoCenterBar == true)
        #expect(prefs.barOnlyWithDofus == false)
        #expect(prefs.menuBarIcon == .logo)
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

    /// Le mode « enchaîner » installe un moniteur global de souris : il ne doit
    /// jamais s'activer tout seul à la faveur d'une mise à jour, pas plus que
    /// les aperçus.
    @Test("Le mode « enchaîner » est éteint par défaut et se relit")
    func enchainementAuClic() {
        let (prefs, store) = neuves()
        #expect(prefs.advanceOnClick == false)

        // Sa bascule a un défaut, elle : ce raccourci n'est réservé auprès du
        // système que lorsque la fonction est active.
        #expect(prefs.advanceArmHotKey == HotKey.defaultAdvanceArm)
        #expect(!HotKey.digitRow.contains(HotKey.defaultAdvanceArm.keyCode))

        prefs.advanceOnClick = true
        prefs.advanceArmHotKey = HotKey(keyCode: 96, modifiers: 0)   // F5

        let relues = Preferences.forTesting(store: store)
        #expect(relues.advanceOnClick == true)
        #expect(relues.advanceArmHotKey == HotKey(keyCode: 96, modifiers: 0))
    }

    /// Une installation antérieure à la bascule ne l'a jamais eue : elle doit la
    /// recevoir, sans que cela confisque quoi que ce soit — la fonction reste
    /// éteinte, et le raccourci n'est réservé qu'avec elle.
    @Test("La bascule du mode arrive aux installations qui ne l'avaient pas")
    func repriseDeLaBascule() {
        let ancien = """
        {"characterOrder":[],"hotKeys":[],"barVisible":true,"showNumbers":true,
         "slotCount":5,"defaultsVersion":3}
        """
        let store = StockageMemoire([Preferences.key: Data(ancien.utf8)])

        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.advanceArmHotKey == HotKey.defaultAdvanceArm)
        #expect(prefs.advanceOnClick == false)
    }

    @Test("Une sauvegarde illisible ramène aux valeurs par défaut")
    func sauvegardeIllisible() {
        let store = StockageMemoire([Preferences.key: Data("pas du JSON".utf8)])
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.slotCount == 5)
        #expect(prefs.hotKeys.count == 5)
    }
}
