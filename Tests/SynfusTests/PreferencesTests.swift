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
        // ⌃⇥ et non ⌘⇥ : macOS réserve ⌘⇥ pour son sélecteur d'applications.
        #expect(prefs.cycleNext == HotKey(keyCode: 48, modifiers: UInt32(controlKey)))
        #expect(prefs.characterOrder.isEmpty)
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
        prefs.purgeOrder(keeping: WindowManager.isPersistableName)
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
    }

    @Test("Une sauvegarde illisible ramène aux valeurs par défaut")
    func sauvegardeIllisible() {
        let store = StockageMemoire([Preferences.key: Data("pas du JSON".utf8)])
        let prefs = Preferences.forTesting(store: store)
        #expect(prefs.slotCount == 5)
        #expect(prefs.hotKeys.count == 5)
    }
}
