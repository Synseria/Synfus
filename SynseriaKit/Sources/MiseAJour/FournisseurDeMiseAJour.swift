// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 25f4236349ad81d5 · contenu 8e8be4e543b80537
// Ce que chaque app fournit à la mise à jour (sa source de releases, ses assets, sa vérification,
// ses gestes propres), ses échecs, et les vérifications au choix.

import CryptoKit
import Foundation
import Security

/// Ce qui empêche une mise à jour. Sans texte : chaque app dit l'échec dans ses mots.
public enum EchecDeMiseAJour: Error, Equatable, Sendable {
    /// La release ou ses fichiers ne se téléchargent pas.
    case reseau
    /// Le DMG n'a pas l'empreinte publiée avec la release.
    case empreinte
    /// Le DMG ne se monte pas, ou ne contient pas d'app.
    case image
    /// L'app extraite n'est pas cette app (autre identifiant), ou sa signature est abîmée.
    case app
    /// L'app extraite ne satisfait pas l'exigence de signature de l'app installée.
    case signature
    /// L'app extraite n'a pas le numéro de la release.
    case version
    /// L'app extraite exige un macOS plus récent que celui-ci.
    case systeme
    /// L'app installée ne se remplace pas (dossier en lecture seule…) : reste le téléchargement à
    /// la main. Le détail est celui du système.
    case ecriture(String)
    /// Ce que l'app a levé (sa source, sa pose), dans ses mots (`LocalizedError`).
    case autre(String)
}

/// La part de l'app : d'où viennent ses releases, lequel de leurs fichiers est son DMG, comment le
/// vérifier, et ce qu'elle fait de propre après la pose. Appelé hors du main actor.
public protocol FournisseurDeMiseAJour: Sendable {
    /// La release à suivre sur `canal`, avec ce qu'il faut pour la télécharger (choisie par
    /// `ReleasePubliee.plusHaute`) ; nil s'il n'y en a pas, ou si elle est incomplète pour ce Mac :
    /// rien ne se dit alors (`repos`), ni « à jour » ni échec.
    func derniere(canal: CanalDeMiseAJour) async throws -> ReleasePubliee?
    /// Télécharge le DMG de `release` dans `dossier` (vide) et rend son chemin.
    func telecharger(_ release: ReleasePubliee, dans dossier: URL) async throws -> URL
    /// Contrôle le DMG avant de le monter (`VerificationDeMiseAJour.empreinteSHA256`). Par défaut, rien.
    func verifierImage(_ image: URL, de release: ReleasePubliee) async throws
    /// Contrôle l'app extraite, après les contrôles communs (identifiant, numéro, macOS) :
    /// `VerificationDeMiseAJour.exigenceDesignee` ou `.signatureIntacte`.
    func verifierApp(_ app: URL, contre installee: URL) throws
    /// Après la pose, avant la relance : ce que la nouvelle version demande (une remise à zéro des
    /// autorisations d'une app signée ad hoc). Par défaut, rien.
    func apresPose(de app: URL)
}

public extension FournisseurDeMiseAJour {
    func verifierImage(_: URL, de _: ReleasePubliee) async throws {}
    func apresPose(de _: URL) {}
}

/// Les vérifications que les apps choisissent.
public enum VerificationDeMiseAJour {
    /// `app` doit satisfaire l'exigence désignée de `reference`. C'est celle que TCC retient : une app
    /// qui la passe garde ses autorisations, et une app qui ne vient pas du même signataire est
    /// refusée. Sans portée pour une signature ad hoc (l'exigence y est le `cdhash`, propre à
    /// chaque build) : elle demande un certificat stable.
    public static func exigenceDesignee(_ app: URL, contre reference: URL) throws {
        var attendue: SecStaticCode?
        var exigence: SecRequirement?
        guard SecStaticCodeCreateWithPath(reference as CFURL, [], &attendue) == errSecSuccess, let attendue,
              SecCodeCopyDesignatedRequirement(attendue, [], &exigence) == errSecSuccess, let exigence
        else { throw EchecDeMiseAJour.signature }
        guard valide(app, exigence: exigence) else { throw EchecDeMiseAJour.signature }
    }

    /// La signature de `app` est intacte, code imbriqué compris (`codesign --verify --deep --strict`),
    /// quel qu'en soit le signataire : ce qui reste à vérifier d'une app signée ad hoc.
    public static func signatureIntacte(_ app: URL) throws {
        guard valide(app, exigence: nil) else { throw EchecDeMiseAJour.app }
    }

    /// Le DMG a l'empreinte que `sommes` (un `SHA256SUMS.txt`, au format de `shasum`) donne pour son nom.
    public static func empreinteSHA256(_ image: URL, sommes: String) throws {
        guard let attendue = empreinte(de: image.lastPathComponent, dans: sommes),
              let contenu = try? Data(contentsOf: image, options: .mappedIfSafe),
              SHA256.hash(data: contenu).map({ String(format: "%02x", $0) }).joined() == attendue
        else { throw EchecDeMiseAJour.empreinte }
    }

    /// L'empreinte SHA-256 de `nom` dans un `SHA256SUMS.txt` (« <hex>  <nom> »), en minuscules ; nil
    /// si le nom exact n'y est pas.
    public static func empreinte(de nom: String, dans sommes: String) -> String? {
        for ligne in sommes.split(whereSeparator: \.isNewline) {
            let morceaux = ligne.split(separator: " ", omittingEmptySubsequences: true)
            guard morceaux.count == 2, morceaux[1].trimmingCharacters(in: CharacterSet(charactersIn: "*")) == nom,
                  morceaux[0].count == 64, morceaux[0].allSatisfy(\.isHexDigit)
            else { continue }
            return morceaux[0].lowercased()
        }
        return nil
    }

    private static func valide(_ app: URL, exigence: SecRequirement?) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return false }
        // `kSecCSStrictValidate` seul laisse passer un lien qui sort du paquet. Pas de
        // `kSecCSRestrictSidebandData` : un FinderInfo posé par le Finder ferait refuser une app saine.
        let controles = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
            | kSecCSRestrictSymlinks)
        return SecStaticCodeCheckValidity(code, controles, exigence) == errSecSuccess
    }
}
