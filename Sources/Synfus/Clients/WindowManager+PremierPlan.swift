// Suivi de l’application au premier plan : pid et « est-ce un client Dofus ».

import AppKit

extension WindowManager {
    /// Mémorise l'application de premier plan et si c'est un client Dofus.
    func setFrontmost(_ app: NSRunningApplication?) {
        setFrontmost(pid: app?.processIdentifier, bundleID: app?.bundleIdentifier)
    }

    func setFrontmost(pid: pid_t?, bundleID: String?) {
        setFrontmost(pid: pid, isDofus: DofusProcesses.isDofusBundle(bundleID))
    }

    /// Ne republie que ce qui change : ces deux valeurs sont relues à chaque
    /// tour de timer, et chaque affectation d'un `@Published` réveille toutes
    /// les vues qui l'observent, changement ou pas.
    func setFrontmost(pid: pid_t?, isDofus: Bool) {
        if frontmostPID != pid { frontmostPID = pid }
        if frontmostIsDofus != isDofus { frontmostIsDofus = isDofus }
    }

    /// Rang du perso au premier plan dans l'effectif ; `nil` s'il n'en fait
    /// pas partie.
    var currentIndex: Int? {
        guard let pid = frontmostPID else { return nil }
        return effectif.firstIndex { $0.pid == pid }
    }

    func isFrontmost(_ client: DofusClient) -> Bool {
        client.pid == frontmostPID
    }
}
