// Bascule vers un perso — focus, signal de bascule, rotation, lancement de session.

import AppKit
import ApplicationServices

extension WindowManager {
    // MARK: - Focus

    func focus(slot: Int) {
        guard slot >= 0, slot < effectif.count else {
            NSSound.beep()
            return
        }
        focus(effectif[slot])
    }

    /// `signaler` : faire clignoter la pastille du perso atteint
    /// (`basculeSignalee`) si le réglage le veut. Faux quand le geste vient
    /// de la pastille elle-même.
    func focus(_ client: DofusClient, signaler: Bool = true) {
        let reachable = isReachable(client)
        if signaler, prefs.signalerBascule, client.pid != frontmostPID {
            signalerBascule(client)
        }
        if reachable {
            AccessibilityReader.unminimize(client.axWindow)
        }

        // L'activation vient en premier : c'est elle, et non `AXRaise`, qui fait
        // basculer macOS vers l'espace où vit la fenêtre quand le client est en
        // plein écran. Dans l'ordre inverse, le raise s'appliquait à une fenêtre
        // d'un autre espace et ne menait nulle part.
        NSRunningApplication(processIdentifier: client.pid)?.activate()

        // Les attributs AX ne servent qu'à départager plusieurs fenêtres d'un même
        // processus ; on les pose une fois la transition d'espace engagée — et
        // seulement s'il y a quelque chose à départager : pour un client à
        // fenêtre unique, l'activation fait tout, et deux appels AX de plus
        // n'ajoutent que de la latence à la bascule. Sur un perso seulement
        // mémorisé, la référence de fenêtre est périmée — il n'y a rien à y poser.
        let siblings = clients.filter { $0.pid == client.pid && !$0.dormant }.count
        if reachable, siblings > 1 {
            let window = client.axWindow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                MainActor.assumeIsolated {
                    AccessibilityReader.set(window, kAXMainAttribute, kCFBooleanTrue)
                    AccessibilityReader.perform(window, action: kAXRaiseAction)
                }
            }
        }

        // La notification d'activation qui va suivre est la nôtre : elle n'aura
        // pas à déclencher un inventaire à chaud. Si le client est déjà devant,
        // aucune ne viendra, et le drapeau resterait collé jusqu'à une
        // activation extérieure qu'il ferait passer pour la nôtre.
        selfActivatedPID = frontmostPID == client.pid ? nil : client.pid
        setFrontmost(pid: client.pid, isDofus: true)
        AttentionWatcher.shared.clear(client)
    }

    /// Désigne la pastille à faire clignoter, le temps de `dureeSignal`. Une
    /// bascule suivante reprend le signal à son compte : une seule pastille
    /// clignote à la fois, celle où l'on est.
    private func signalerBascule(_ client: DofusClient) {
        basculeSignalee = client.slotKey
        finSignal?.cancel()
        let item = DispatchWorkItem {
            MainActor.assumeIsolated { WindowManager.shared.basculeSignalee = nil }
        }
        finSignal = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dureeSignal, execute: item)
    }

    /// Le geste « lancer la session » : ranger les fenêtres selon la dernière
    /// disposition, puis basculer sur le premier perso. Rien que des gestes
    /// existants, enchaînés — et toujours aucun évènement émis.
    func lancerSession() {
        Task {
            await WindowArranger.shared.appliquerDerniere()
            if !effectif.isEmpty { focus(slot: 0) }
        }
    }

    /// Tourne dans l'effectif — l'équipe active, ou tous — en sautant les
    /// clients injoignables : un client qui se ferme ou gèle reste affiché le
    /// temps de mourir, mais s'y poser ne montrerait rien (cf. `Rotation`).
    func cycle(by step: Int) {
        guard !effectif.isEmpty else {
            NSSound.beep()
            return
        }
        // Depuis Chrome ou Discord — ou depuis un perso hors de l'équipe —, on
        // ne « cycle » pas : on revient au premier perso joignable.
        let injoignables = unreachablePIDs
        let joignables = effectif.map { !injoignables.contains($0.pid) }
        guard let next = Rotation.suivant(depuis: currentIndex, pas: step, joignables: joignables) else {
            NSSound.beep()
            return
        }
        focus(effectif[next])
    }
}
