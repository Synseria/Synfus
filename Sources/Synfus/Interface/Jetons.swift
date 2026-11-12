// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 8e252f614957292a · contenu 6ef8a7a1eea8d269
import SwiftUI

/// Les valeurs de design Synseria telles que Synfus les reçoit : toute couleur, taille ou durée
/// d'une vue vient d'ici, jamais d'un chiffre écrit dans la vue.
enum Jetons {
    enum Apparence: Sendable, Hashable { case clair, sombre }

    enum Prereglage: String, CaseIterable, Sendable, Identifiable {
        case azur, jade, framboise, corail, ardoise
        var id: String { rawValue }
        var nom: String {
            switch self {
            case .azur: "Azur"
            case .jade: "Jade"
            case .framboise: "Framboise"
            case .corail: "Corail"
            case .ardoise: "Ardoise"
            }
        }
        /// Teinte OKLCH, en degrés : celle des fonds quand ils suivent la primaire.
        var teinte: Int {
            switch self {
            case .azur: 260
            case .jade: 172
            case .framboise: 10
            case .corail: 38
            case .ardoise: 262
            }
        }
    }

    /// « Autre… » refuse une teinte trop proche du safran, qui dit « regarde ici », ou d'une couleur
    /// que l'app réserve à un sens : la primaire ne se confond avec aucune.
    static func teinteAcceptee(_ teinte: Int) -> Bool {
        [84, 293].allSatisfy { abs(((teinte - $0) % 360 + 540) % 360 - 180) >= 30 }
    }

    /// La couleur de l'app : un préréglage, ou « Autre… » = une teinte OKLCH en degrés.
    enum Couleur: Sendable, Hashable { case prereglage(Prereglage), teinte(Int) }
    /// La teinte des fonds : seule la teinte des neutres change, jamais leur clarté.
    enum Fonds: Sendable, Hashable { case primaire, nuit, neutre, teinte(Int) }

    static let couleurParDefaut = Couleur.prereglage(.jade)
    /// Tant que l'utilisateur n'a rien choisi : le même défaut dans toutes les apps.
    static func fondsParDefaut(_ apparence: Apparence) -> Fonds { apparence == .sombre ? .nuit : .primaire }
    static let apparences: [Apparence] = [.clair, .sombre]

    struct RVB: Sendable, Hashable {
        let hex: UInt32
        let opacite: Double
        init(_ hex: UInt32, opacite: Double = 1) {
            self.hex = hex
            self.opacite = opacite
        }
        func voile(_ opacite: Double) -> RVB { RVB(hex, opacite: opacite) }
        var couleur: Color {
            Color(.sRGB, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: opacite)
        }
    }

    struct Theme: Sendable, Hashable {
        let fenetre: RVB
        let surface: RVB
        let creux: RVB
        let filet: RVB
        let contourControle: RVB
        let encre: RVB
        let encreSecondaire: RVB
        let encreTertiaire: RVB
        let survol: RVB
        let pression: RVB
        let primaire: RVB
        let primaireEncre: RVB
        let primaireFond: RVB
        let encreSurPrimaire: RVB
        let nuit: RVB
        let nuitProfond: RVB
        let safran: RVB
        let safranTexte: RVB
        let safranFond: RVB
        let danger: RVB
        let alerte: RVB
        let succes: RVB
        let dangerPlein: RVB
        let encreSurDanger: RVB
        let suggestionSynfus: RVB
    }

    static func theme(_ couleur: Couleur = couleurParDefaut, fonds: Fonds? = nil,
                      _ apparence: Apparence) -> Theme {
        let sombre = apparence == .sombre
        let rangee: Int
        switch fonds ?? fondsParDefaut(apparence) {
        case .primaire:
            switch couleur {
            case .prereglage(let p): rangee = p.teinte
            case .teinte(let t): rangee = ((t % 360) + 360) % 360
            }
        case .nuit: rangee = 268
        case .neutre: rangee = 360
        case .teinte(let t): rangee = ((t % 360) + 360) % 360
        }
        let n = Array(Table.neutres[rangee].dropFirst(sombre ? 8 : 0).prefix(8)).map { RVB($0) }
        let ligne: [UInt32]
        switch couleur {
        case .prereglage(let p): ligne = Table.prereglages[Prereglage.allCases.firstIndex(of: p) ?? 0]
        case .teinte(let t): ligne = Table.primaires[((t % 360) + 360) % 360]
        }
        let plein = RVB(ligne[sombre ? 2 : 0])
        return Theme(
            fenetre: n[0],
            surface: n[1],
            creux: n[2],
            filet: n[3],
            contourControle: n[4],
            encre: n[5],
            encreSecondaire: n[6],
            encreTertiaire: n[7],
            survol: n[5].voile(sombre ? 0.08 : 0.06),
            pression: n[5].voile(sombre ? 0.14 : 0.12),
            primaire: plein,
            primaireEncre: RVB(ligne[sombre ? 3 : 1]),
            primaireFond: plein.voile(sombre ? 0.22 : 0.12),
            encreSurPrimaire: sombre ? RVB(0x0e1322) : RVB(0xffffff),
            nuit: RVB(0x16284f),
            nuitProfond: RVB(0x0e1322),
            safran: RVB(0xffc53d),
            safranTexte: sombre ? RVB(0xffc53d) : RVB(0x895900),
            safranFond: sombre ? RVB(0xffc53d, opacite: 0.2) : RVB(0xffc53d, opacite: 0.22),
            danger: sombre ? RVB(0xff7a7a) : RVB(0xc4161c),
            alerte: sombre ? RVB(0xf38c47) : RVB(0xb04d00),
            succes: sombre ? RVB(0x5ed689) : RVB(0x1a7539),
            dangerPlein: sombre ? RVB(0xca3732) : RVB(0x84000a),
            encreSurDanger: sombre ? RVB(0xffffff) : RVB(0xffffff),
            suggestionSynfus: sombre ? RVB(0x9e73f2) : RVB(0x7c4de0))
    }

    /// Un enfant prend le cran sous son parent ; trois rayons au plus par écran.
    enum Rayon {
        static let pastille: CGFloat = 4
        static let controle: CGFloat = 8
        static let carte: CGFloat = 12
        static let panneau: CGFloat = 16
        static let capsule: CGFloat = 9999
    }

    /// Grille de 4 pt.
    enum Espace {
        static let un: CGFloat = 4
        static let deux: CGFloat = 8
        static let trois: CGFloat = 12
        static let quatre: CGFloat = 16
        static let six: CGFloat = 24
        static let huit: CGFloat = 32
        static let dix: CGFloat = 40
    }

    enum Taille {
        static let controle: CGFloat = 28
        static let boutonIcone: CGFloat = 28
        static let cibleMin: CGFloat = 24
        static let `case`: CGFloat = 14
        static let interrupteurLargeur: CGFloat = 32
        static let interrupteurHauteur: CGFloat = 18
        static let rangee: CGFloat = 28
        static let rangeePalette: CGFloat = 36
        static let touche: CGFloat = 18
        static let iconeBarre: CGFloat = 17
    }

    enum Trait {
        static let filet: CGFloat = 1
        static let etat: CGFloat = 1.5
        static let focus: CGFloat = 2
        static let focusEcart: CGFloat = 2
        static let iconeFine: CGFloat = 1.25
        static let iconeNormale: CGFloat = 1.5
    }

    /// Seules l'opacité et la couleur s'animent ; la sortie dure `sortie` × l'entrée.
    enum Duree {
        static let pression: Double = 0.1
        static let survol: Double = 0.12
        static let etat: Double = 0.16
        static let menu: Double = 0.2
        static let feuille: Double = 0.28
        static let sortie: Double = 0.7
        static func animation(_ duree: Double) -> Animation {
            .timingCurve(0.2, 0, 0, 1, duration: duree)
        }
    }

    struct Ombre: Sendable, Hashable {
        let y, flou: CGFloat
        let couleur: RVB
        static let flottant = Ombre(y: 4, flou: 12, couleur: RVB(0x0e1322, opacite: 0.18))
        static let aide = Ombre(y: 1, flou: 4, couleur: RVB(0x0e1322, opacite: 0.28))
    }

    struct Typo: Sendable, Hashable {
        enum Famille: Sendable, Hashable { case texte, titre, code }
        let taille, interligne: CGFloat
        let graisse: Font.Weight
        let famille: Famille
        let chiffresFixes: Bool

        var police: Font {
            let base: Font
            switch famille {
            case .texte: base = .system(size: taille, weight: graisse)
            case .titre: base = .system(size: taille, weight: graisse, design: .rounded)
            case .code:
                base = Typo.codeInstallee ? .custom("Google Sans Code", fixedSize: taille).weight(graisse)
                    : .system(size: taille, weight: graisse, design: .monospaced)
            }
            return chiffresFixes ? base.monospacedDigit() : base
        }

        /// Aucune police n'est livrée avec les apps : Google Sans Code si elle est installée.
        private static let codeInstallee: Bool = {
            #if canImport(AppKit)
            NSFont(name: "Google Sans Code", size: 12) != nil
            #else
            UIFont(name: "Google Sans Code", size: 12) != nil
            #endif
        }()

        static let titrePage = Typo(taille: 24, interligne: 30, graisse: .semibold, famille: .titre, chiffresFixes: false)
        static let titre = Typo(taille: 15, interligne: 20, graisse: .semibold, famille: .titre, chiffresFixes: false)
        static let corps = Typo(taille: 13, interligne: 18, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let corpsFort = Typo(taille: 13, interligne: 18, graisse: .semibold, famille: .texte, chiffresFixes: false)
        static let note = Typo(taille: 12, interligne: 16, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let petit = Typo(taille: 11, interligne: 14, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let micro = Typo(taille: 10, interligne: 12, graisse: .medium, famille: .texte, chiffresFixes: false)
        static let chiffre = Typo(taille: 12, interligne: 16, graisse: .regular, famille: .texte, chiffresFixes: true)
        static let grandChiffre = Typo(taille: 24, interligne: 28, graisse: .medium, famille: .titre, chiffresFixes: true)
        static let code = Typo(taille: 13, interligne: 19, graisse: .regular, famille: .code, chiffresFixes: false)
        static let codeInterface = Typo(taille: 12, interligne: 16, graisse: .regular, famille: .code, chiffresFixes: false)
        static let raccourci = Typo(taille: 11, interligne: 14, graisse: .medium, famille: .texte, chiffresFixes: false)
    }

    /// Rangées 0…359 : teintes des fonds ; 360 : « Neutre ». Huit neutres clairs puis huit sombres,
    /// déjà ajustés aux seuils de contraste (`outils/theme.py`) : l'app ne calcule rien.
    private enum Table {
        static let neutres = lire("""
f8f3f4 ffffff f1eaec e5dadd 8f777d 28141a 72565d 957e84 1c1215 281a1e 37242a 4a333a a0868d f5eef0 bca4aa 988086
f8f3f4 ffffff f1eaeb e5dadc 8f777d 28141a 72565d 967e84 1c1215 281a1e 38242a 4a333a a0868d f5eef0 bda4aa 988086
f8f3f4 ffffff f1eaeb e5dadc 8f777d 281419 72565d 967e84 1c1215 281a1e 382429 4a3339 a0868d f5eef0 bda4aa 998086
f8f3f4 ffffff f1eaeb e5dadc 90777c 281419 72565c 967e83 1c1214 281a1d 382429 4a3339 a1868c f5eef0 bda4a9 998085
f8f3f4 ffffff f1eaeb e5dadc 90777c 281419 72565c 967e83 1c1214 281a1d 382429 4a3339 a1868c f5eeef bda4a9 998085
f8f3f4 ffffff f2eaeb e5dadc 90777c 281419 72565b 967e83 1c1214 281a1d 382429 4b3338 a1868c f6eeef bda4a8 998085
f8f3f4 ffffff f2eaeb e5dadc 90777b 281418 72565b 967e82 1c1214 281a1d 382428 4b3338 a1868b f6eeef bda4a8 998084
f8f3f3 ffffff f2eaeb e5dadb 90777b 281418 72565b 967e82 1c1214 281a1c 382428 4b3338 a1868b f6eeef bda4a8 998084
f8f3f3 ffffff f2eaeb e5dadb 90777a 281418 72565a 967e82 1c1214 291a1c 382428 4b3337 a1868a f6eeef bda4a7 998083
f8f3f3 ffffff f2eaeb e5dadb 90777a 291417 73565a 967e81 1c1214 291a1c 382427 4b3337 a1878a f6eeef bda4a7 998083
f8f3f3 ffffff f2eaea e5dadb 90777a 291417 735659 967e81 1c1213 291a1c 382427 4b3337 a1878a f6eeef bda4a7 998083
f8f3f3 ffffff f2eaea e5dadb 907779 291417 735659 967e81 1c1213 291a1c 382427 4b3336 a18789 f6eeef bda4a6 998082
f8f3f3 ffffff f2eaea e5dadb 907779 291416 735659 967e80 1c1213 291a1b 382527 4b3336 a18789 f6eeef bda4a6 998082
f8f3f3 ffffff f2eaea e5dada 907779 291416 735658 967e80 1c1213 291a1b 382526 4b3436 a18789 f6eeee bea4a6 998082
f8f3f3 ffffff f2eaea e6dada 907778 291416 735658 977e80 1c1213 291a1b 382526 4b3435 a18788 f6eeee bea4a5 998081
f8f3f3 ffffff f2eaea e6dada 907778 291416 735657 977e7f 1c1213 291a1b 382526 4b3435 a18788 f6eeee bea4a5 9a8081
f8f3f3 ffffff f2eaea e6dada 907778 291415 735657 977e7f 1c1213 291a1b 382526 4b3435 a18787 f6eeee bea4a5 9a8081
f8f3f3 ffffff f2eaea e6dada 917777 291415 735657 977e7f 1c1212 291a1a 382525 4b3434 a18787 f6eeee bea4a4 9a8080
f8f3f3 ffffff f2eaea e6dada 917777 291415 735656 977e7e 1c1212 291a1a 382525 4b3434 a28787 f6eeee bea4a4 9a8080
f8f3f3 ffffff f2eaea e6dada 917777 291414 735656 977e7e 1c1212 291a1a 382525 4b3434 a28786 f6eeee bea4a4 9a8080
f8f3f3 ffffff f2eae9 e6dad9 917776 291414 735655 977e7e 1c1212 291a1a 382524 4b3433 a28786 f6eeee bea4a3 9a807f
f8f3f3 ffffff f2eae9 e6dad9 917776 291414 735655 977e7d 1c1212 291a1a 382524 4b3433 a28786 f6eeee bea4a3 9a807f
f8f3f3 ffffff f2eae9 e6dad9 917776 291413 735655 977e7d 1c1212 291a19 382524 4b3433 a28785 f6eeee bea4a3 9a807f
f8f3f2 ffffff f2eae9 e6dad9 917775 291413 735654 977e7d 1c1212 291a19 382524 4b3432 a28785 f6eeee bea4a2 9a807e
f8f3f2 ffffff f2eae9 e6dad9 917775 291413 735654 977e7c 1c1212 291a19 382523 4b3432 a28785 f6eeed bea4a2 9a807e
f8f3f2 ffffff f2eae9 e6dad9 917775 291412 735653 977f7c 1c1211 291a19 382523 4b3432 a28784 f6eeed bea4a2 9a807e
f8f3f2 ffffff f2eae9 e6dad9 917774 291412 735653 977f7c 1c1211 291a19 382523 4b3431 a28784 f6eeed bea4a1 9a807d
f8f3f2 ffffff f2eae9 e6dad8 917774 291412 735653 977f7b 1c1211 291a18 382523 4b3431 a28784 f6eeed bea4a1 9a807d
f8f3f2 ffffff f2eae9 e6dad8 917774 291412 735652 977f7b 1c1211 291a18 382522 4b3431 a28783 f6eeed bea4a1 9a807d
f8f3f2 ffffff f2eae9 e6dad8 917873 291411 735652 977f7b 1c1211 291a18 382522 4b3430 a18783 f6eeed bea5a0 9a817c
f8f3f2 ffffff f2eae8 e6dad8 907873 291411 735752 977f7a 1c1211 291a18 382522 4b3430 a18783 f6eeed bea5a0 9a817c
f8f3f2 ffffff f2eae8 e6dad8 907873 291411 735751 977f7a 1c1211 291a18 382521 4b3430 a18782 f6eeed bea5a0 99817c
f8f3f2 ffffff f2eae8 e5dad8 907872 291410 735751 977f7a 1c1210 291a17 382521 4b3430 a18882 f6eeed bea59f 99817b
f8f3f2 ffffff f2eae8 e5dad8 907872 291510 735750 967f7a 1c1310 291a17 382521 4b342f a18882 f6eeed bea59f 99817b
f8f3f2 ffffff f2eae8 e5dad7 907872 291510 735750 967f79 1c1310 291a17 382521 4b342f a18881 f6eeed bda59f 99817b
f8f3f2 ffffff f2eae8 e5dad7 907872 291510 735750 967f79 1c1310 291a17 382520 4b342f a18881 f6eeec bda59f 99817b
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 73574f 967f79 1c1310 291b17 382520 4b352e a18881 f6eeec bda59e 99817a
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 73574f 967f78 1c1310 291b16 382520 4b352e a18880 f6eeec bda59e 99817a
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 72574f 967f78 1c1310 291b16 382620 4b352e a18880 f6eeec bda59e 99817a
f8f3f2 ffffff f2eae8 e5dad7 907870 29150e 72574e 967f78 1c1310 291b16 382620 4b352e a18880 f6eeec bda59d 998179
f8f3f1 ffffff f2eae8 e5dad7 907870 28150e 72574e 967f78 1c1310 281b16 38261f 4b352d a18880 f6eeec bda59d 998179
f8f3f1 ffffff f1eae8 e5dad7 907870 28150e 72574e 968077 1c130f 281b16 38261f 4b352d a1887f f5eeec bda59d 998179
f8f3f1 ffffff f1eae7 e5dad6 907870 28150e 72584d 968077 1c130f 281b16 38261f 4a352d a1887f f5efec bda59d 998179
f8f3f1 ffffff f1eae7 e5dad6 90796f 28150d 72584d 968077 1c130f 281b15 38261f 4a352c a0887f f5efec bda69c 998278
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584d 968077 1c130f 281b15 38261e 4a352c a0887e f5efec bda69c 988278
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584c 958076 1c130f 281b15 38261e 4a352c a0897e f5efec bca69c 988278
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584c 958076 1c130f 281b15 38261e 4a352c a0897e f5efec bca69c 988278
f8f3f1 ffffff f1eae7 e5dbd6 8f796e 28150c 71584c 958076 1c130f 281b15 37261e 4a352b a0897e f5efec bca69b 988277
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160c 71584c 958076 1c130f 281b15 37261e 4a362b a0897d f5efeb bca69b 988277
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160c 71584b 958075 1c130f 281b14 37261d 4a362b a0897d f5efeb bca69b 988277
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160b 71584b 958075 1c130e 281b14 37261d 4a362b a0897d f5efeb bca69b 988277
f7f3f1 ffffff f1eae7 e5dbd5 8f796d 28160b 71594b 958075 1c130e 281b14 37261d 4a362a 9f897d f5efeb bca69a 988276
f7f3f1 ffffff f1eae7 e4dbd5 8e796d 27160b 71594a 958075 1b130e 281b14 37271d 49362a 9f897c f5efeb bca69a 978276
f7f3f1 ffffff f1eae7 e4dbd5 8e796d 27160b 71594a 948175 1b130e 281b14 37271d 49362a 9f897c f5efeb bba69a 978276
f7f3f1 ffffff f1ebe7 e4dbd5 8e7a6d 27160b 70594a 948174 1b130e 281b14 37271c 49362a 9f897c f5efeb bba79a 978376
f7f3f1 ffffff f1ebe7 e4dbd5 8e7a6c 27160a 70594a 948174 1b130e 271c14 37271c 49362a 9f8a7c f5efeb bba79a 978375
f7f3f1 ffffff f1ebe6 e4dbd5 8e7a6c 27160a 705949 948174 1b130e 271c13 37271c 493629 9f8a7c f5efeb bba799 978375
f7f3f1 ffffff f1ebe6 e4dbd5 8e7a6c 27160a 705949 948174 1b130e 271c13 36271c 493629 9e8a7b f5efeb bba799 978375
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6c 27160a 705949 948174 1b130e 271c13 36271c 493629 9e8a7b f5efeb baa799 968375
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6c 271709 6f5949 938173 1b130e 271c13 36271b 483729 9e8a7b f5efeb baa799 968375
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6b 271709 6f5a48 938173 1b130e 271c13 36271b 483729 9e8a7b f5efeb baa799 968375
f7f3f1 ffffff f0ebe6 e4dbd5 8d7a6b 261709 6f5a48 938173 1b140d 271c13 36271b 483728 9e8a7b f5efeb baa798 968374
f7f3f1 ffffff f0ebe6 e4dbd5 8d7a6b 261709 6f5a48 938173 1b140d 271c13 36271b 483728 9d8a7a f4efeb baa798 968374
f7f3f1 ffffff f0ebe6 e4dbd4 8c7b6b 261709 6f5a48 938273 1b140d 271c13 36271b 483728 9d8a7a f4efeb baa898 968474
f7f4f1 ffffff f0ebe6 e3dbd4 8c7b6b 261708 6e5a48 938273 1b140d 271c12 35281b 483728 9d8b7a f4efeb b9a898 958474
f7f4f1 ffffff f0ebe6 e3dbd4 8c7b6b 261708 6e5a47 928273 1b140d 261c12 35281b 473728 9d8b7a f4efeb b9a898 958474
f7f4f0 ffffff f0ebe6 e3dcd4 8c7b6b 261708 6e5a47 928272 1b140d 261c12 35281a 473728 9d8b7a f4efea b9a898 958474
f7f4f0 ffffff f0ebe6 e3dcd4 8c7b6a 261708 6e5b47 928272 1a140d 261c12 35281a 473727 9c8b7a f4efea b9a898 958473
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 928272 1a140d 261c12 35281a 473827 9c8b79 f4efea b8a897 948473
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 918272 1a140d 261c12 35281a 473827 9c8b79 f4efea b8a897 948473
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 918272 1a140d 261d12 35281a 463827 9c8b79 f4efea b8a897 948473
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251807 6d5b47 918272 1a140d 261d12 34281a 463827 9b8b79 f4efea b8a897 948473
f7f4f0 ffffff f0ebe6 e3dcd4 8a7c6a 251807 6c5b46 918372 1a140d 261d12 34281a 463827 9b8c79 f4efea b7a997 948573
f6f4f0 ffffff f0ebe6 e2dcd4 8a7c6a 251807 6c5b46 918372 1a140d 251d12 34281a 463827 9b8c79 f4efea b7a997 938573
f6f4f0 ffffff f0ebe6 e2dcd4 8a7c6a 241807 6c5b46 908371 1a140d 251d12 34291a 463827 9b8c79 f4efea b7a997 938573
f6f4f0 ffffff efebe6 e2dcd4 8a7c69 241807 6c5c46 908371 1a140d 251d12 342919 453827 9a8c79 f4f0ea b7a997 938573
f6f4f0 ffffff efebe6 e2dcd4 8a7c69 241807 6b5c46 908371 1a140d 251d12 332919 453826 9a8c79 f3f0ea b6a997 938572
f6f4f0 ffffff efebe6 e2dcd4 897c69 241807 6b5c46 908371 1a140d 251d11 332919 453926 9a8c79 f3f0ea b6a996 928572
f6f4f0 ffffff efebe6 e2dcd4 897c69 241907 6b5c46 8f8371 19140d 251d11 332919 453926 9a8c78 f3f0ea b6a996 928572
f6f4f0 ffffff efebe6 e2dcd4 897c69 231907 6a5c46 8f8371 19140d 251d11 332919 443926 998c78 f3f0ea b6a996 928572
f6f4f0 ffffff efebe6 e2dcd4 887d69 231907 6a5c46 8f8471 19140d 241d11 332919 443926 998d78 f3f0ea b5aa96 918672
f6f4f0 ffffff efebe6 e1dcd4 887d69 231907 6a5c46 8f8471 19150d 241d11 322919 443926 998d78 f3f0ea b5aa96 918672
f6f4f0 ffffff efebe6 e1dcd4 887d69 231906 6a5d45 8e8471 19150d 241d11 322919 443926 988d78 f3f0ea b5aa96 918672
f6f4f0 ffffff efece6 e1dcd4 887d69 231906 695d45 8e8471 19150c 241e11 322919 443926 988d78 f3f0ea b5aa96 918672
f6f4f0 ffffff efece6 e1dcd4 877d69 221906 695d45 8e8471 19150c 241e11 322a19 433926 988d78 f3f0ea b4aa96 908672
f6f4f0 ffffff efece6 e1ddd4 877d69 221906 695d45 8e8471 19150c 241e11 322a19 433a26 988d78 f3f0ea b4aa96 908672
f6f4f0 ffffff eeece6 e1ddd4 877d69 221a06 685d45 8d8471 19150c 241e11 312a19 433a26 978d78 f3f0ea b4aa96 908672
f6f4f0 ffffff eeece6 e1ddd4 867d69 221a06 685d45 8d8471 18150c 231e11 312a19 423a26 978d78 f3f0ea b3aa96 8f8672
f6f4f0 ffffff eeece6 e1ddd4 867e69 211a06 685e45 8d8471 18150c 231e11 312a19 423a26 978e78 f2f0ea b3ab96 8f8772
f6f4f0 ffffff eeece6 e0ddd4 867e69 211a06 675e45 8c8571 18150c 231e11 312a19 423a26 968e78 f2f0ea b3ab96 8f8772
f6f4f0 ffffff eeece6 e0ddd4 867e69 211a06 675e45 8c8571 18150c 231e11 312a19 423a26 968e78 f2f0ea b2ab96 8f8772
f5f4f0 ffffff eeece6 e0ddd4 857e69 211a06 675e45 8c8571 18150c 231e11 302a19 413a26 968e78 f2f0ea b2ab96 8e8772
f5f4f0 ffffff eeece6 e0ddd4 857e69 211a06 665e45 8c8571 18150c 221e11 302a19 413a26 958e78 f2f0ea b2ab96 8e8772
f5f4f0 ffffff eeece6 e0ddd4 857e69 201a06 665e45 8b8571 18150c 221e11 302a19 413b26 958e78 f2f0ea b2ab96 8e8772
f5f4f0 ffffff eeece6 e0ddd4 847e69 201a06 665e45 8b8571 18150c 221e11 302b19 413b26 958e78 f2f0ea b1ab96 8d8772
f5f4f0 ffffff eeece6 e0ddd4 847e69 201b06 655f45 8b8571 18150d 221e11 2f2b19 403b26 948f78 f2f0ea b1ab96 8d8772
f5f4f0 ffffff edece6 dfddd4 847f69 201b06 655f46 8a8571 17150d 221f11 2f2b19 403b26 948f78 f2f0ea b1ac96 8d8872
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 8a8671 17150d 221f11 2f2b19 403b26 948f78 f2f0ea b0ac96 8c8872
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 8a8671 17150d 211f11 2f2b19 3f3b26 938f78 f1f0ea b0ac96 8c8872
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 898671 17150d 211f11 2e2b19 3f3b26 938f79 f1f0ea b0ac96 8c8872
f5f4f0 ffffff edece6 dfddd4 827f69 1f1b07 635f46 898671 17150d 211f11 2e2b19 3f3b26 938f79 f1f0ea afac97 8b8872
f5f4f0 ffffff edece6 dfddd4 827f69 1e1b07 635f46 898671 17160d 211f12 2e2b19 3e3b26 928f79 f1f0ea afac97 8b8872
f5f4f0 ffffff edece6 deddd4 827f6a 1e1b07 636046 888671 17160d 211f12 2e2b19 3e3c27 928f79 f1f0ea afac97 8b8873
f5f4f0 ffffff edece6 deded4 817f6a 1e1b07 626046 888672 16160d 201f12 2d2b1a 3e3c27 929079 f1f1ea aeac97 8a8873
f5f4f0 ffffff edece6 deded4 81806a 1d1c07 626046 888672 16160d 201f12 2d2c1a 3e3c27 919079 f1f1ea aead97 8a8973
f5f4f0 ffffff edece6 deded4 81806a 1d1c07 616046 878672 16160d 201f12 2d2c1a 3d3c27 919079 f1f1ea aead97 8a8973
f5f4f0 ffffff ecece6 deded4 80806a 1d1c07 616047 878772 16160d 201f12 2d2c1a 3d3c27 919079 f1f1ea adad97 898973
f4f5f0 ffffff ecece6 deded4 80806a 1d1c07 616047 878772 16160d 201f12 2c2c1a 3d3c27 909079 f1f1ea adad97 898973
f4f5f0 ffffff ecece6 deded4 80806a 1c1c08 606047 868772 16160d 1f1f12 2c2c1a 3c3c27 909079 f0f1ea adad97 898973
f4f5f0 ffffff ecece6 ddded4 7f806a 1c1c08 606147 868772 16160d 1f1f12 2c2c1a 3c3c27 8f907a f0f1ea acad98 888973
f4f5f0 ffffff ecede6 ddded4 7f806a 1c1c08 5f6147 868772 16160d 1f2012 2b2c1a 3c3c27 8f907a f0f1ea acad98 888974
f4f5f1 ffffff ecede6 ddded4 7f806b 1b1c08 5f6147 858772 15160d 1f2012 2b2c1a 3b3d28 8f917a f0f1eb acad98 888974
f4f5f1 ffffff ecede6 ddded4 7e806b 1b1c08 5f6148 858773 15160d 1f2012 2b2c1b 3b3d28 8e917a f0f1eb abad98 878974
f4f5f1 ffffff ecede6 ddded4 7e816b 1b1c08 5e6148 858773 15160d 1e2013 2b2c1b 3b3d28 8e917a f0f1eb abae98 878a74
f4f5f1 ffffff ecede6 ddded5 7e816b 1b1d09 5e6148 848773 15160d 1e2013 2a2d1b 3a3d28 8e917a f0f1eb abae98 878a74
f4f5f1 ffffff ecede6 dcded5 7d816b 1a1d09 5d6148 848873 15160d 1e2013 2a2d1b 3a3d28 8d917b f0f1eb aaae98 868a74
f4f5f1 ffffff ebede6 dcded5 7d816b 1a1d09 5d6148 848873 15160e 1e2013 2a2d1b 3a3d28 8d917b f0f1eb aaae99 868a74
f4f5f1 ffffff ebede6 dcded5 7d816c 1a1d09 5d6249 838873 15160e 1e2013 292d1b 393d29 8d917b f0f1eb a9ae99 868a75
f4f5f1 ffffff ebede6 dcded5 7c816c 191d09 5c6249 838874 14160e 1d2013 292d1b 393d29 8c917b eff1eb a9ae99 858a75
f4f5f1 ffffff ebede6 dcded5 7c816c 191d09 5c6249 838874 14160e 1d2013 292d1c 393d29 8c927b eff1eb a9ae99 858a75
f4f5f1 ffffff ebede6 dcded5 7b816c 191d0a 5b6249 828874 14160e 1d2013 292d1c 383e29 8b927c eff1eb a8ae99 848a75
f4f5f1 ffffff ebede7 dbded5 7b816c 181d0a 5b624a 828874 14160e 1d2013 282d1c 383e29 8b927c eff1eb a8ae9a 848a75
f3f5f1 ffffff ebede7 dbdfd5 7b826d 181d0a 5b624a 828874 14160e 1c2014 282d1c 383e2a 8b927c eff1eb a8af9a 848b76
f3f5f1 ffffff ebede7 dbdfd5 7a826d 181d0a 5a624a 818875 14170e 1c2014 282d1c 373e2a 8a927c eff1eb a7af9a 838b76
f3f5f1 ffffff ebede7 dbdfd5 7a826d 171d0b 5a624a 818975 14170e 1c2014 272d1d 373e2a 8a927c eff1eb a7af9a 838b76
f3f5f1 ffffff eaede7 dbdfd5 7a826d 171e0b 59634b 818975 13170e 1c2114 272d1d 373e2a 8a927d eff1eb a7af9a 838b76
f3f5f1 ffffff eaede7 dbdfd6 79826e 171e0b 59634b 808975 13170e 1c2114 272e1d 363e2b 89927d eff1eb a6af9b 828b77
f3f5f1 ffffff eaede7 dbdfd6 79826e 161e0b 58634b 808975 13170e 1b2114 272e1d 363e2b 89927d eff1eb a6af9b 828b77
f3f5f1 ffffff eaede7 dadfd6 79826e 161e0c 58634b 808976 13170f 1b2114 262e1d 363e2b 88927d eef1eb a6af9b 828b77
f3f5f1 ffffff eaede7 dadfd6 78826e 161e0c 58634c 7f8976 13170f 1b2115 262e1e 353e2b 88937e eef1ec a5af9b 818b77
f3f5f1 ffffff eaede7 dadfd6 78826e 151e0c 57634c 7f8976 13170f 1b2115 262e1e 353f2c 88937e eef1ec a5af9c 818b78
f3f5f1 ffffff eaede7 dadfd6 78826f 151e0c 57634c 7f8976 13170f 1a2115 252e1e 343f2c 87937e eef1ec a5af9c 818b78
f3f5f1 ffffff eaede7 dadfd6 77836f 151e0d 56634d 7e8977 12170f 1a2115 252e1e 343f2c 87937e eef1ec a4b09c 808c78
f3f5f1 ffffff eaede7 dadfd6 77836f 141e0d 56634d 7e8977 12170f 1a2115 252e1e 343f2c 87937f eef1ec a4b09c 808c78
f3f5f1 ffffff eaede7 dadfd6 778370 141e0d 56644d 7e8977 12170f 1a2115 252e1f 333f2d 86937f eef1ec a4b09d 808c79
f3f5f1 ffffff e9ede8 d9dfd7 768370 141e0e 55644e 7d8a77 12170f 1a2116 242e1f 333f2d 86937f eef2ec a3b09d 7f8c79
f3f5f2 ffffff e9ede8 d9dfd7 768370 131e0e 55644e 7d8a78 12170f 192116 242e1f 333f2d 869380 eef2ec a3b09d 7f8c79
f3f5f2 ffffff e9ede8 d9dfd7 768370 131f0e 54644e 7d8a78 121710 192116 242e1f 323f2d 859380 eef2ec a3b09d 7f8c79
f2f5f2 ffffff e9ede8 d9dfd7 758371 131f0e 54644f 7d8a78 121710 192116 232e20 323f2e 859380 eef2ec a2b09e 7e8c7a
f2f5f2 ffffff e9ede8 d9dfd7 758371 121f0f 53644f 7c8a78 111710 192116 232e20 323f2e 859380 edf2ec a2b09e 7e8c7a
f2f5f2 ffffff e9ede8 d9dfd7 748371 121f0f 53644f 7c8a79 111710 182117 232f20 313f2e 849481 edf2ec a2b09e 7e8c7a
f2f5f2 ffffff e9ede8 d9dfd7 748372 111f0f 536450 7c8a79 111710 182117 222f20 313f2f 849481 edf2ec a1b09f 7d8c7b
f2f5f2 ffffff e9ede8 d8dfd7 748372 111f10 526450 7b8a79 111710 182117 222f21 313f2f 839481 edf2ed a1b09f 7d8c7b
f2f5f2 ffffff e9eee8 d8dfd8 738372 111f10 526450 7b8a7a 111710 182117 222f21 30402f 839482 edf2ed a1b09f 7d8c7b
f2f5f2 ffffff e9eee8 d8dfd8 738472 101f10 516451 7b8a7a 111710 182217 222f21 30402f 839482 edf2ed a0b19f 7c8d7b
f2f5f2 ffffff e9eee8 d8dfd8 738473 101f10 516551 7a8a7a 111711 172217 212f21 304030 829482 edf2ed a0b1a0 7c8d7c
f2f5f2 ffffff e8eee9 d8dfd8 738473 101f11 516551 7a8a7a 101711 172218 212f22 2f4030 829483 edf2ed a0b1a0 7c8d7c
f2f5f2 ffffff e8eee9 d8dfd8 728473 0f1f11 506552 7a8a7b 101711 172218 212f22 2f4030 829483 edf2ed 9fb1a0 7b8d7c
f2f5f2 ffffff e8eee9 d8e0d8 728474 0f1f11 506552 798a7b 101711 172218 202f22 2f4031 819483 edf2ed 9fb1a1 7b8d7d
f2f5f2 ffffff e8eee9 d7e0d8 728474 0f1f12 4f6553 798b7b 101711 172218 202f22 2e4031 819484 edf2ed 9fb1a1 7b8d7d
f2f5f2 ffffff e8eee9 d7e0d9 718474 0e1f12 4f6553 798b7c 101711 162218 202f23 2e4031 819484 ecf2ed 9eb1a1 7a8d7d
f2f5f2 ffffff e8eee9 d7e0d9 718475 0e1f12 4f6553 798b7c 101711 162219 202f23 2e4032 819484 ecf2ed 9eb1a2 7a8d7e
f2f5f2 ffffff e8eee9 d7e0d9 718475 0d1f13 4e6554 788b7c 101711 162219 1f2f23 2d4032 809485 ecf2ed 9eb1a2 7a8d7e
f2f5f2 ffffff e8eee9 d7e0d9 708475 0d1f13 4e6554 788b7d 0f1712 162219 1f2f24 2d4032 809485 ecf2ee 9eb1a2 798d7e
f2f5f3 ffffff e8eee9 d7e0d9 708476 0d1f13 4e6555 788b7d 0f1812 162219 1f2f24 2d4033 809585 ecf2ee 9db1a3 798d7f
f2f5f3 ffffff e8eee9 d7e0d9 708476 0c2014 4d6555 778b7d 0f1812 15221a 1e2f24 2c4033 7f9586 ecf2ee 9db1a3 798d7f
f1f5f3 ffffff e8eee9 d7e0d9 6f8476 0c1f14 4d6555 778b7e 0f1812 15221a 1e2f24 2c4033 7f9586 ecf2ee 9db1a3 798d7f
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b1f14 4d6556 778b7e 0f1812 15221a 1e2f25 2c4034 7f9586 ecf2ee 9cb1a4 788d80
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b2014 4c6556 778b7e 0f1812 15221a 1e2f25 2b4034 7e9587 ecf2ee 9cb1a4 788d80
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b2015 4c6557 768b7f 0f1812 15221a 1d2f25 2b4034 7e9587 ecf2ee 9cb1a4 788d80
f1f5f3 ffffff e7eeea d6e0da 6e8478 0a2015 4b6657 768b7f 0f1813 14221b 1d2f26 2b4035 7e9588 ecf2ee 9cb1a5 778d81
f1f5f3 ffffff e7eeea d6e0da 6e8478 0a2015 4b6657 768b7f 0e1813 14221b 1d2f26 2b4035 7e9588 ecf2ee 9bb1a5 778e81
f1f5f3 ffffff e7eeea d6e0da 6e8578 0a2016 4b6658 768b80 0e1813 14221b 1d3026 2a4135 7d9588 ecf2ee 9bb2a5 778e81
f1f5f3 ffffff e7eeea d6e0da 6e8579 092016 4a6658 758b80 0e1813 14221b 1c3026 2a4136 7d9589 ecf2ef 9bb2a6 778e82
f1f5f3 ffffff e7eeea d6e0db 6d8579 092016 4a6659 758b80 0e1813 14221b 1c3027 2a4136 7d9589 ebf2ef 9bb2a6 768e82
f1f5f3 ffffff e7eeea d6e0db 6d8579 092017 4a6659 758b81 0e1813 13221c 1c3027 294136 7d9589 ebf2ef 9ab2a6 768e82
f1f5f3 ffffff e7eeeb d6e0db 6d857a 082017 4a6659 758b81 0e1813 13221c 1c3027 294137 7c958a ebf2ef 9ab2a7 768e83
f1f5f3 ffffff e7eeeb d5e0db 6d857a 082017 49665a 748b81 0e1814 13221c 1b3027 294137 7c958a ebf2ef 9ab2a7 768e83
f1f5f3 ffffff e7eeeb d5e0db 6c857b 082018 49665a 748b82 0e1814 13221c 1b3028 294137 7c958a ebf2ef 9ab2a8 758e84
f1f5f4 ffffff e7eeeb d5e0db 6c857b 072018 49665b 748b82 0e1814 13221c 1b3028 284138 7c958b ebf2ef 99b2a8 758e84
f1f5f4 ffffff e7eeeb d5e0dc 6c857b 072018 48665b 748b82 0d1814 13221d 1b3028 284138 7b958b ebf2ef 99b2a8 758e84
f1f5f4 ffffff e7eeeb d5e0dc 6c857c 072019 48665b 748b83 0d1814 12221d 1b3029 284138 7b958c ebf2ef 99b2a9 758e85
f1f5f4 ffffff e7eeeb d5e0dc 6c857c 062019 48665c 738b83 0d1814 12221d 1a3029 284139 7b958c ebf2ef 99b2a9 758e85
f1f5f4 ffffff e6eeeb d5e0dc 6b857c 062019 48665c 738b83 0d1814 12221d 1a3029 274139 7b958c ebf2f0 99b2a9 748e85
f1f5f4 ffffff e6eeeb d5e0dc 6b857d 062019 47665d 738b84 0d1815 12221e 1a302a 274139 7a958d ebf2f0 99b2aa 748e86
f1f5f4 ffffff e6eeeb d5e0dc 6b857d 06201a 47665d 738b84 0d1815 12221e 1a302a 27413a 7a958d ebf2f0 98b2aa 748e86
f1f5f4 ffffff e6eeec d5e0dd 6b857d 05201a 47665e 738b84 0d1815 12221e 1a302a 27413a 7a958d ebf2f0 98b2aa 748e86
f1f5f4 ffffff e6eeec d5e0dd 6b857e 05201a 47665e 738b85 0d1815 12221e 19302a 27413a 7a958e ebf2f0 98b2ab 748e87
f1f5f4 ffffff e6eeec d5e0dd 6a857e 05201b 46665e 728b85 0d1815 11221e 19302b 26413b 7a958e ebf2f0 98b2ab 748e87
f1f5f4 ffffff e6eeec d4e0dd 6a857e 05201b 46665f 728b85 0d1815 11221f 19302b 26413b 7a958f ebf2f0 98b2ab 738e87
f1f5f4 ffffff e6eeec d4e0dd 6a857f 05201b 46665f 728b86 0d1815 11221f 19302b 26413b 79958f ebf2f0 98b2ac 738e88
f1f5f4 ffffff e6eeec d4e0dd 6a857f 04201c 466660 728b86 0d1816 11221f 19302b 26413c 79958f ebf2f0 97b2ac 738e88
f1f5f4 ffffff e6eeec d4e0de 6a8580 04201c 466660 728b86 0c1816 11221f 19302c 26413c 799590 ebf2f0 97b2ac 738e89
f1f5f4 ffffff e6eeec d4e0de 6a8580 04201c 456660 728b87 0c1816 11221f 18302c 26413c 799590 ebf2f1 97b2ad 738e89
f0f5f5 ffffff e6eeec d4e0de 6a8580 04201d 456661 728b87 0c1816 112220 18302c 25413d 799590 eaf2f1 97b2ad 738e89
f0f5f5 ffffff e6eeed d4e0de 698581 04201d 456661 718b87 0c1816 112220 18302d 25413d 799591 eaf2f1 97b2ae 738e8a
f0f5f5 ffffff e6eeed d4e0de 698581 03201d 456662 718b88 0c1816 112220 18302d 25413d 799591 eaf2f1 97b2ae 728e8a
f0f5f5 ffffff e6eeed d4e0de 698581 03201d 456662 718b88 0c1816 112220 18302d 25413e 789592 eaf2f1 97b2ae 728e8a
f0f5f5 ffffff e6eeed d4e0de 698582 03201e 456662 718b88 0c1817 102221 18302d 25413e 789592 eaf2f1 97b2af 728e8b
f0f5f5 ffffff e6eeed d4e0df 698582 03201e 456663 718b89 0c1817 102221 18302e 25413e 789592 eaf2f1 96b2af 728e8b
f0f5f5 ffffff e6eeed d4e0df 698582 03201e 446663 718b89 0c1817 102221 18302e 25413f 789593 eaf2f1 96b2af 728e8b
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b89 0c1817 102221 18302e 25413f 789593 eaf2f1 96b2b0 728e8c
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b8a 0c1817 102221 17302f 24413f 789593 eaf2f2 96b2b0 728e8c
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b8a 0c1817 102222 17302f 244140 789594 eaf2f2 96b2b0 728e8c
f0f5f5 ffffff e6eeee d4e0df 698584 03201f 446665 718b8a 0c1817 102222 17302f 244140 789594 eaf2f2 96b2b1 728e8d
f0f5f5 ffffff e6eeee d4e0e0 698584 021f1f 446665 718b8b 0c1818 102222 172f2f 244040 789594 eaf2f2 96b2b1 728e8d
f0f5f5 ffffff e6eeee d4e0e0 688584 021f20 446666 718b8b 0c1818 102222 172f30 244041 789595 eaf2f2 96b2b1 728e8d
f0f5f5 ffffff e6eeee d4e0e0 688485 021f20 446666 718b8b 0c1818 102222 172f30 244041 789595 eaf2f2 96b1b2 728e8e
f0f5f5 ffffff e6eeee d4e0e0 688485 021f20 446566 718b8c 0c1818 102223 172f30 244041 789595 eaf2f2 96b1b2 728d8e
f0f5f6 ffffff e6eeee d4e0e0 688485 021f21 446567 718b8c 0c1818 102223 172f30 244041 789596 eaf2f2 96b1b2 728d8e
f0f5f6 ffffff e6eeee d4e0e0 688486 021f21 446567 708b8c 0c1818 102223 172f31 244042 789596 eaf2f2 96b1b3 728d8f
f0f5f6 ffffff e6eeee d4e0e0 688486 031f21 446567 708b8d 0c1818 102223 172f31 244042 789596 eaf2f2 96b1b3 728d8f
f0f5f6 ffffff e6eeee d4e0e1 688486 031f22 446568 708b8d 0c1818 102223 172f31 244042 789597 eaf2f2 96b1b3 728d8f
f0f5f6 ffffff e6eeee d4e0e1 688487 031f22 446568 708b8d 0c1819 102223 172f31 244043 789597 eaf2f3 96b1b4 728d90
f0f5f6 ffffff e6eeef d4e0e1 688487 031f22 446569 718b8d 0c1719 102224 172f32 244043 789597 eaf2f3 96b1b4 728d90
f0f5f6 ffffff e6eeef d4e0e1 688487 031f22 446569 718b8e 0c1719 102224 172f32 244043 789498 eaf2f3 96b1b4 728d90
f0f5f6 ffffff e6eeef d4e0e1 688488 031f23 446569 718b8e 0c1719 102224 172f32 244044 789498 eaf2f3 96b1b5 728d91
f0f5f6 ffffff e6eeef d4e0e1 688488 031f23 44656a 718b8e 0c1719 102224 172f32 244044 789498 eaf2f3 96b1b5 728d91
f0f5f6 ffffff e6eeef d4e0e1 698488 031f23 44656a 718b8f 0c1719 102224 172f33 244044 789499 eaf2f3 96b1b5 728d91
f0f5f6 ffffff e6eeef d4e0e2 698489 031f23 44656a 718b8f 0c1719 102225 172f33 244044 789499 eaf2f3 96b1b5 728d92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a8f 0c1719 102225 172f33 244045 789499 eaf2f3 96b1b6 728d92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a8f 0c171a 102225 182f33 254045 78949a eaf2f3 96b1b6 728d92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a90 0c171a 102225 182f33 254045 78949a eaf2f3 96b1b6 728d92
f0f5f6 ffffff e6eeef d4dfe2 69848a 031f24 45656c 718a90 0c171a 102225 182f34 254045 78949a eaf2f3 96b1b7 728d93
f0f5f6 ffffff e6eeef d4dfe2 69848a 031f25 45646c 718a90 0c171a 102125 182f34 254046 78949b eaf2f4 96b1b7 728d93
f0f5f6 ffffff e6eef0 d4dfe2 69838a 041f25 45646c 718a91 0c171a 112126 182f34 253f46 78949b eaf2f4 97b1b7 728d93
f0f5f7 ffffff e6eef0 d4dfe3 69838b 041f25 45646d 718a91 0c171a 112126 182f34 253f46 78949b eaf2f4 97b0b7 728c94
f0f5f7 ffffff e6eef0 d4dfe3 69838b 041f25 45646d 718a91 0c171a 112126 182f35 253f46 79949b eaf2f4 97b0b8 728c94
f0f5f7 ffffff e6edf0 d4dfe3 69838b 041f25 45646d 718a91 0c171a 112126 182e35 253f47 79949c eaf2f4 97b0b8 738c94
f0f5f7 ffffff e6edf0 d4dfe3 6a838b 041e26 45646d 728a92 0c171a 112126 182e35 263f47 79949c eaf2f4 97b0b8 738c94
f0f5f7 ffffff e6edf0 d4dfe3 6a838c 041e26 46646e 728a92 0c171a 112126 192e35 263f47 79939c eaf2f4 97b0b9 738c95
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646e 728a92 0d171b 112126 192e35 263f47 79939d ebf2f4 97b0b9 738c95
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646e 728a92 0d171b 112127 192e36 263f48 79939d ebf2f4 97b0b9 738c95
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646f 728a93 0d171b 112127 192e36 263f48 79939d ebf2f4 97b0b9 738c95
f1f5f7 ffffff e6edf0 d4dfe3 6a838d 051e27 46646f 728993 0d171b 112127 192e36 263f48 7a939d ebf2f4 98b0ba 738c96
f1f5f7 ffffff e6edf0 d4dfe4 6a838d 061e27 47636f 728993 0d171b 122127 192e36 273f48 7a939e ebf1f4 98b0ba 738c96
f1f5f7 ffffff e6edf0 d5dfe4 6b838d 061e27 47636f 728993 0d171b 122127 1a2e36 273f49 7a939e ebf1f4 98b0ba 748c96
f1f5f7 ffffff e6edf1 d5dfe4 6b838d 061e27 476370 738993 0d171b 122127 1a2e36 273f49 7a939e ebf1f5 98b0ba 748c96
f1f5f7 ffffff e6edf1 d5dfe4 6b828d 061e27 476370 738994 0d171b 122127 1a2e37 273e49 7a939e ebf1f5 98afba 748b96
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 476370 738994 0d171b 122128 1a2e37 273e49 7a939e ebf1f5 98afbb 748b97
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 486370 738994 0d171b 122128 1a2e37 283e49 7b939f ebf1f5 99afbb 748b97
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 486371 738994 0d171b 122128 1b2e37 283e49 7b929f ebf1f5 99afbb 758b97
f1f5f7 ffffff e6edf1 d5dfe4 6c828e 071d28 486371 748994 0d171c 132128 1b2d37 283e4a 7b929f ebf1f5 99afbb 758b97
f1f5f7 ffffff e7edf1 d5dfe4 6c828f 081d28 496371 748995 0e171c 132128 1b2d37 283e4a 7b929f ebf1f5 99afbb 758b98
f1f5f7 ffffff e7edf1 d5dfe4 6c828f 081d28 496271 748995 0e171c 132028 1b2d38 293e4a 7b92a0 ebf1f5 99afbc 758b98
f1f5f7 ffffff e7edf1 d5dfe5 6c828f 081d29 496272 748995 0e171c 132028 1b2d38 293e4a 7c92a0 ebf1f5 9aafbc 758b98
f1f5f7 ffffff e7edf1 d5dfe5 6d828f 091d29 496272 748895 0e161c 132028 1c2d38 293e4a 7c92a0 ebf1f5 9aafbc 768b98
f1f5f7 ffffff e7edf1 d5dfe5 6d828f 091d29 4a6272 758895 0e161c 132028 1c2d38 293e4b 7c92a0 ebf1f5 9aafbc 768b98
f1f5f7 ffffff e7edf1 d6dee5 6d818f 091d29 4a6272 758896 0e161c 142029 1c2d38 2a3e4b 7c92a0 ebf1f5 9aaebc 768a98
f1f5f8 ffffff e7edf1 d6dee5 6d8190 0a1d29 4a6272 758896 0e161c 142029 1c2d38 2a3d4b 7d92a0 ebf1f5 9baebd 768a99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0a1d29 4b6273 758896 0e161c 142029 1d2d38 2a3d4b 7d91a1 ebf1f5 9baebd 778a99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0a1d29 4b6273 768896 0e161c 142029 1d2d38 2a3d4b 7d91a1 ecf1f5 9baebd 778a99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0b1d29 4b6273 768896 0f161c 142029 1d2d39 2b3d4b 7d91a1 ecf1f5 9baebd 778a99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0b1d2a 4c6173 768896 0f161c 142029 1d2d39 2b3d4b 7e91a1 ecf1f5 9baebd 778a99
f1f5f8 ffffff e7edf1 d6dee5 6f8190 0b1c2a 4c6173 768896 0f161c 152029 1e2c39 2b3d4c 7e91a1 ecf1f5 9caebd 788a99
f1f5f8 ffffff e7edf2 d6dee5 6f8190 0c1c2a 4c6173 768797 0f161c 152029 1e2c39 2c3d4c 7e91a1 ecf1f6 9caebd 788a9a
f1f5f8 ffffff e7edf2 d6dee5 6f8191 0c1c2a 4d6173 778797 0f161c 152029 1e2c39 2c3d4c 7f91a2 ecf1f6 9caebe 788a9a
f1f5f8 ffffff e7edf2 d6dee5 6f8091 0d1c2a 4d6174 778797 0f161c 152029 1e2c39 2c3d4c 7f91a2 ecf1f6 9dadbe 788a9a
f1f5f8 ffffff e8edf2 d7dee5 708091 0d1c2a 4d6174 778797 0f161d 152029 1f2c39 2d3d4c 7f91a2 ecf1f6 9dadbe 79899a
f2f5f8 ffffff e8edf2 d7dee5 708091 0d1c2a 4e6174 788797 0f161d 161f29 1f2c39 2d3c4c 7f90a2 ecf1f6 9dadbe 79899a
f2f5f8 ffffff e8edf2 d7dee6 708091 0e1c2a 4e6074 788797 0f161d 161f29 1f2c39 2d3c4c 8090a2 ecf1f6 9dadbe 79899a
f2f5f8 ffffff e8ecf2 d7dee6 718091 0e1c2a 4e6074 788797 10161d 161f2a 1f2c39 2d3c4c 8090a2 ecf1f6 9eadbe 7a899a
f2f5f8 ffffff e8ecf2 d7dee6 718091 0e1c2a 4f6074 788797 10161d 161f2a 202c3a 2e3c4c 8090a2 ecf1f6 9eadbe 7a899a
f2f5f8 ffffff e8ecf2 d7dee6 718091 0f1c2b 4f6074 798797 10161d 161f2a 202c3a 2e3c4c 8190a2 ecf1f6 9eadbe 7a899a
f2f4f8 ffffff e8ecf2 d7dee6 718091 0f1b2b 4f6074 798797 10161d 171f2a 202c3a 2e3c4d 8190a2 ecf1f6 9eadbe 7a899a
f2f4f8 ffffff e8ecf2 d7dee6 728092 0f1b2b 506074 798698 10161d 171f2a 212c3a 2f3c4d 8190a2 edf1f6 9fadbf 7b899b
f2f4f8 ffffff e8ecf2 d8dee6 727f92 101b2b 506075 7a8698 10161d 171f2a 212b3a 2f3c4d 8290a3 edf1f6 9facbf 7b889b
f2f4f8 ffffff e8ecf2 d8dee6 727f92 101b2b 516075 7a8698 10161d 171f2a 212b3a 2f3c4d 828fa3 edf0f6 9facbf 7b889b
f2f4f8 ffffff e8ecf2 d8dde6 737f92 101b2b 515f75 7a8698 11161d 171f2a 212b3a 303b4d 828fa3 edf0f6 a0acbf 7c889b
f2f4f8 ffffff e8ecf2 d8dde6 737f92 111b2b 515f75 7a8698 11151d 181f2a 222b3a 303b4d 838fa3 edf0f6 a0acbf 7c889b
f2f4f8 ffffff e9ecf2 d8dde6 737f92 111b2b 525f75 7b8698 11151d 181f2a 222b3a 303b4d 838fa3 edf0f6 a0acbf 7c889b
f2f4f8 ffffff e9ecf2 d8dde6 747f92 111b2b 525f75 7b8698 11151d 181f2a 222b3a 313b4d 838fa3 edf0f6 a1acbf 7d889b
f2f4f8 ffffff e9ecf2 d8dde6 747f92 121b2b 535f75 7b8698 11151d 181f2a 222b3a 313b4d 848fa3 edf0f6 a1acbf 7d889b
f2f4f8 ffffff e9ecf2 d8dde6 747f92 121b2b 535f75 7c8598 11151d 181f2a 232b3a 313b4d 848fa3 edf0f6 a1acbf 7d889b
f2f4f8 ffffff e9ecf2 d9dde6 757e92 121a2b 535f75 7c8598 11151d 191e2a 232b3a 323b4d 848fa3 edf0f6 a2acbf 7e889b
f2f4f8 ffffff e9ecf2 d9dde6 757e92 131a2b 545e75 7c8598 11151d 191e2a 232b3a 323b4d 858ea3 edf0f6 a2abbf 7e879b
f2f4f8 ffffff e9ecf2 d9dde6 757e92 131a2b 545e75 7d8598 12151d 191e2a 242a3a 323b4d 858ea3 edf0f6 a2abbf 7e879b
f3f4f8 ffffff e9ecf2 d9dde6 767e92 131a2b 555e75 7d8598 12151d 191e2a 242a3a 333a4d 858ea3 eef0f6 a3abbf 7f879b
f3f4f8 ffffff e9ecf2 d9dde6 767e92 141a2b 555e75 7d8598 12151d 1a1e2a 242a3a 333a4d 868ea3 eef0f6 a3abbf 7f879b
f3f4f8 ffffff e9ecf2 d9dde6 767e92 141a2b 555e75 7e8598 12151d 1a1e2a 242a3a 333a4d 868ea3 eef0f6 a3abbf 7f879b
f3f4f8 ffffff eaecf2 d9dde6 777e92 141a2b 565e75 7e8598 12151d 1a1e2a 252a3a 343a4d 868ea3 eef0f6 a4abbf 80879b
f3f4f8 ffffff eaecf2 dadde6 777e92 151a2b 565e75 7e8598 12151d 1a1e2a 252a3a 343a4d 878ea3 eef0f6 a4abbf 80879b
f3f4f8 ffffff eaecf2 dadde6 777e92 151a2b 575d75 7e8498 12151d 1a1e2a 252a3a 343a4d 878ea3 eef0f6 a4abbf 80879b
f3f4f8 ffffff eaecf2 dadde6 787d92 151a2b 575d75 7f8498 13151d 1b1e2a 262a3a 353a4d 878da3 eef0f6 a5aabf 81869b
f3f4f8 ffffff eaecf2 dadde6 787d92 16192b 575d75 7f8498 13151d 1b1e2a 262a3a 353a4d 888da3 eef0f6 a5aabf 81869b
f3f4f8 ffffff eaecf2 dadde6 787d92 16192b 585d75 7f8498 13151d 1b1e2a 262a3a 353a4d 888da3 eef0f6 a5aabf 81869b
f3f4f8 ffffff eaecf2 dadce6 797d92 16192b 585d75 808498 13151d 1b1e2a 262a3a 36394d 898da3 eef0f6 a6aabf 82869b
f3f4f8 ffffff eaecf2 dbdce6 797d92 17192b 595d75 808498 13151d 1b1e2a 27293a 36394d 898da3 eff0f6 a6aabf 82869b
f3f4f8 ffffff eaebf2 dbdce6 797d92 17192b 595d75 808498 13151d 1c1d2a 27293a 36394d 898da3 eff0f6 a6aabf 82869b
f3f4f8 ffffff eaebf2 dbdce6 7a7d92 17192b 595d75 818498 13151d 1c1d2a 27293a 37394d 8a8da3 eff0f6 a7aabf 83869b
f3f4f8 ffffff ebebf2 dbdce6 7a7d92 18192b 5a5c75 818498 14141d 1c1d2a 28293a 37394d 8a8da3 eff0f6 a7aabf 83869b
f3f4f8 ffffff ebebf2 dbdce6 7a7c91 18192b 5a5c74 818397 14141d 1c1d2a 28293a 37394d 8a8ca2 eff0f6 a7a9be 83859a
f3f4f8 ffffff ebebf2 dbdce6 7b7c91 18192b 5b5c74 828397 14141d 1d1d2a 28293a 38394c 8b8ca2 eff0f6 a8a9be 84859a
f4f4f8 ffffff ebebf2 dbdce6 7b7c91 18192a 5b5c74 828397 14141d 1d1d2a 28293a 38394c 8b8ca2 eff0f6 a8a9be 84859a
f4f4f8 ffffff ebebf2 dcdce6 7b7c91 19182a 5b5c74 828397 14141d 1d1d2a 292939 38394c 8b8ca2 eff0f6 a8a9be 84859a
f4f4f8 ffffff ebebf2 dcdce6 7c7c91 19182a 5c5c74 838397 14141d 1d1d29 292939 39384c 8c8ca2 eff0f6 a9a9be 85859a
f4f4f8 ffffff ebebf2 dcdce6 7c7c91 19182a 5c5c74 838397 14141d 1d1d29 292939 39384c 8c8ca2 efeff6 a9a9be 85859a
f4f4f8 ffffff ebebf2 dcdce5 7c7c91 1a182a 5d5b74 838397 15141d 1e1d29 292939 39384c 8c8ca2 f0eff6 a9a9be 85859a
f4f4f8 ffffff ebebf2 dcdce5 7d7c91 1a182a 5d5b74 848397 15141d 1e1d29 2a2839 3a384c 8d8ca2 f0eff6 aaa9be 86859a
f4f4f8 ffffff ebebf2 dcdce5 7d7b91 1a182a 5d5b73 848397 15141c 1e1d29 2a2839 3a384c 8d8ba2 f0eff6 aaa9be 86859a
f4f4f8 ffffff ecebf2 dddce5 7e7b91 1b182a 5e5b73 848297 15141c 1e1d29 2a2839 3a384c 8e8ba1 f0eff6 aaa8be 86849a
f4f4f8 ffffff ecebf2 dddce5 7e7b90 1b182a 5e5b73 858296 15141c 1e1d29 2b2839 3b384c 8e8ba1 f0eff6 aba8bd 878499
f4f4f8 ffffff ecebf1 dddce5 7e7b90 1b182a 5f5b73 858296 15141c 1f1c29 2b2839 3b384b 8e8ba1 f0eff5 aba8bd 878499
f4f4f8 ffffff ecebf1 dddce5 7f7b90 1b1829 5f5b73 858296 15141c 1f1c29 2b2839 3b384b 8f8ba1 f0eff5 aba8bd 888499
f4f4f8 ffffff ecebf1 dddce5 7f7b90 1c1729 5f5b73 868296 15141c 1f1c29 2b2838 3c374b 8f8ba1 f0eff5 aca8bd 888499
f4f4f8 ffffff ecebf1 dddbe5 7f7b90 1c1729 605a73 868296 16141c 1f1c29 2c2838 3c374b 8f8ba1 f0eff5 aca8bd 888499
f4f4f8 ffffff ecebf1 dddbe5 807b90 1c1729 605a72 868296 16141c 1f1c29 2c2838 3c374b 908ba1 f0eff5 aca8bd 898499
f4f3f8 ffffff ecebf1 dedbe5 807b8f 1c1729 605a72 878296 16141c 201c29 2c2838 3c374b 908ba0 f1eff5 ada8bc 898499
f5f3f7 ffffff ecebf1 dedbe5 807a8f 1d1729 615a72 878295 16141c 201c28 2c2838 3d374b 908aa0 f1eff5 ada8bc 898498
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1729 615a72 878195 16141c 201c28 2d2738 3d374a 918aa0 f1eff5 ada7bc 8a8398
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1729 625a72 888195 16141c 201c28 2d2738 3d374a 918aa0 f1eff5 aea7bc 8a8398
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1728 625a71 888195 16141c 201c28 2d2738 3e374a 918aa0 f1eff5 aea7bc 8a8398
f5f3f7 ffffff edebf1 dedbe4 827a8f 1e1728 625a71 888195 17131c 201c28 2d2737 3e374a 928a9f f1eff5 aea7bc 8b8398
f5f3f7 ffffff edebf1 dfdbe4 827a8e 1e1728 635971 898195 17131c 211c28 2e2737 3e374a 928a9f f1eff5 afa7bb 8b8397
f5f3f7 ffffff edebf1 dfdbe4 827a8e 1e1728 635971 898194 17131b 211c28 2e2737 3f364a 928a9f f1eff5 afa7bb 8b8397
f5f3f7 ffffff edebf1 dfdbe4 837a8e 1e1728 635970 898194 17131b 211c28 2e2737 3f3649 938a9f f1eff5 afa7bb 8c8397
f5f3f7 ffffff edebf1 dfdbe4 837a8e 1f1628 645970 898194 17131b 211c28 2e2737 3f3649 938a9f f1eff5 b0a7bb 8c8397
f5f3f7 ffffff edeaf1 dfdbe4 837a8e 1f1627 645970 8a8194 17131b 211c27 2f2737 3f3649 93899e f2eff5 b0a7bb 8c8397
f5f3f7 ffffff edeaf1 dfdbe4 83798d 1f1627 655970 8a8194 17131b 221b27 2f2736 403649 94899e f2eff5 b0a6ba 8c8296
f5f3f7 ffffff eeeaf0 dfdbe4 84798d 1f1627 65596f 8a8093 17131b 221b27 2f2736 403649 94899e f2eff5 b1a6ba 8d8296
f5f3f7 ffffff eeeaf0 e0dbe4 84798d 201627 65596f 8b8093 18131b 221b27 2f2736 403648 94899e f2eff4 b1a6ba 8d8296
f5f3f7 ffffff eeeaf0 e0dbe4 84798d 201627 66596f 8b8093 18131b 221b27 302736 413648 95899d f2eff4 b1a6ba 8d8296
f5f3f7 ffffff eeeaf0 e0dbe3 85798c 201626 66586f 8b8093 18131b 221b27 302636 413648 95899d f2eff4 b2a6b9 8e8295
f5f3f7 ffffff eeeaf0 e0dbe3 85798c 201626 66586e 8c8092 18131b 221b27 302636 413648 95899d f2eff4 b2a6b9 8e8295
f6f3f7 ffffff eeeaf0 e0dbe3 85798c 211626 67586e 8c8092 18131b 231b26 302635 413647 96899d f2eff4 b2a6b9 8e8295
f6f3f7 ffffff eeeaf0 e0dbe3 86798c 211626 67586e 8c8092 18131b 231b26 302635 423547 96899c f2eff4 b3a6b9 8f8295
f6f3f7 ffffff eeeaf0 e0dbe3 86798b 211626 67586e 8c8092 18131a 231b26 312635 423547 96899c f2eff4 b3a6b8 8f8294
f6f3f7 ffffff eeeaf0 e1dae3 86798b 211625 68586d 8d8091 18131a 231b26 312635 423547 97899c f2eff4 b3a6b8 8f8294
f6f3f7 ffffff eeeaf0 e1dae3 86798b 211525 68586d 8d8091 18131a 231b26 312635 423547 97889c f3eff4 b3a6b8 908294
f6f3f7 ffffff efeaf0 e1dae3 87788b 221525 68586d 8d8091 19131a 231b26 312634 433546 97889b f3eef4 b4a5b8 908194
f6f3f7 ffffff efeaf0 e1dae2 87788a 221525 69586c 8e8091 19131a 241b26 322634 433546 98889b f3eef4 b4a5b7 908193
f6f3f6 ffffff efeaf0 e1dae2 87788a 221525 69586c 8e7f90 19131a 241b25 322634 433546 98889b f3eef4 b4a5b7 908193
f6f3f6 ffffff efeaef e1dae2 88788a 221524 69576c 8e7f90 19131a 241b25 322634 433546 98889a f3eef4 b5a5b7 918193
f6f3f6 ffffff efeaef e1dae2 88788a 231524 69576b 8e7f90 19131a 241b25 322634 443545 98889a f3eef3 b5a5b7 918193
f6f3f6 ffffff efeaef e2dae2 887889 231524 6a576b 8f7f90 19131a 241b25 322633 443545 99889a f3eef3 b5a5b6 918192
f6f3f6 ffffff efeaef e2dae2 887889 231524 6a576b 8f7f8f 191319 241b25 332633 443545 99889a f3eef3 b5a5b6 918192
f6f3f6 ffffff efeaef e2dae2 897889 231523 6a576a 8f7f8f 191319 241b25 332633 443544 998899 f3eef3 b6a5b6 928192
f6f3f6 ffffff efeaef e2dae2 897888 231523 6b576a 8f7f8f 191319 251b24 332533 453544 9a8899 f3eef3 b6a5b5 928191
f6f3f6 ffffff efeaef e2dae1 897888 241523 6b576a 907f8f 191319 251a24 332532 453544 9a8899 f3eef3 b6a5b5 928191
f6f3f6 ffffff efeaef e2dae1 897888 241523 6b5769 907f8e 1a1319 251a24 332532 453444 9a8898 f3eef3 b6a5b5 928191
f6f3f6 ffffff efeaef e2dae1 8a7887 241522 6b5769 907f8e 1a1319 251a24 332532 453443 9a8798 f4eef3 b7a5b4 938190
f6f3f6 ffffff f0eaef e2dae1 8a7887 241522 6c5769 907f8e 1a1219 251a24 342532 453443 9b8798 f4eef3 b7a5b4 938190
f7f3f6 ffffff f0eaef e2dae1 8a7887 241522 6c5768 917f8d 1a1219 251a24 342531 463443 9b8797 f4eef3 b7a5b4 938190
f7f3f6 ffffff f0eaee e3dae1 8a7787 241522 6c5768 917f8d 1a1218 251a23 342531 463442 9b8797 f4eef3 b7a5b3 938190
f7f3f6 ffffff f0eaee e3dae1 8b7786 251421 6d5668 917f8d 1a1218 261a23 342531 463442 9b8797 f4eef2 b8a4b3 94808f
f7f3f6 ffffff f0eaee e3dae0 8b7786 251421 6d5667 917f8c 1a1218 261a23 342531 463442 9c8796 f4eef2 b8a4b3 94808f
f7f3f6 ffffff f0eaee e3dae0 8b7786 251421 6d5667 917f8c 1a1218 261a23 342530 463442 9c8796 f4eef2 b8a4b3 94808f
f7f3f6 ffffff f0eaee e3dae0 8b7785 251421 6d5667 927f8c 1a1218 261a23 352530 473441 9c8796 f4eef2 b8a4b2 94808e
f7f3f5 ffffff f0eaee e3dae0 8c7785 251420 6e5666 927e8c 1a1218 261a22 352530 473441 9c8795 f4eef2 b9a4b2 95808e
f7f3f5 ffffff f0eaee e3dae0 8c7785 251420 6e5666 927e8b 1a1218 261a22 352530 473441 9d8795 f4eef2 b9a4b2 95808e
f7f3f5 ffffff f0eaee e3dae0 8c7784 261420 6e5665 927e8b 1b1218 261a22 35252f 473440 9d8795 f4eef2 b9a4b1 95808d
f7f3f5 ffffff f0eaee e3dae0 8c7784 261420 6e5665 927e8b 1b1217 261a22 35252f 473440 9d8794 f4eef2 b9a4b1 95808d
f7f3f5 ffffff f0eaee e4dadf 8c7784 26141f 6e5665 937e8a 1b1217 271a22 35252f 483440 9d8794 f4eef2 b9a4b1 95808d
f7f3f5 ffffff f0eaed e4dadf 8d7783 26141f 6f5664 937e8a 1b1217 271a21 36252f 48343f 9d8794 f4eef2 baa4b0 96808c
f7f3f5 ffffff f1eaed e4dadf 8d7783 26141f 6f5664 937e8a 1b1217 271a21 36252e 48343f 9e8793 f5eef1 baa4b0 96808c
f7f3f5 ffffff f1eaed e4dadf 8d7783 26141e 6f5663 937e89 1b1217 271a21 36252e 48343f 9e8793 f5eef1 baa4b0 96808c
f7f3f5 ffffff f1eaed e4dadf 8d7782 26141e 6f5663 937e89 1b1217 271a21 36252e 48343f 9e8793 f5eef1 baa4af 96808b
f7f3f5 ffffff f1eaed e4dadf 8d7782 27141e 6f5663 947e89 1b1217 271a21 36252e 48343e 9e8792 f5eef1 baa4af 96808b
f7f3f5 ffffff f1eaed e4dade 8e7782 27141e 705662 947e88 1b1217 271a20 36252d 49343e 9e8792 f5eef1 bba4ae 97808b
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705662 947e88 1b1216 271a20 36252d 49343e 9f8791 f5eef1 bba4ae 97808a
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705662 947e88 1b1216 271a20 36252d 49343d 9f8791 f5eef1 bba4ae 97808a
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705661 947e87 1b1216 271a20 37252d 49343d 9f8791 f5eef1 bba4ad 97808a
f7f3f5 ffffff f1eaec e4dade 8e7780 27141c 705661 947e87 1b1216 281a20 37252c 49333d 9f8790 f5eef1 bba4ad 978089
f7f3f4 ffffff f1eaec e5dade 8e7780 27141c 715660 957e87 1b1216 281a1f 37252c 49333c 9f8790 f5eef1 bba4ad 978089
f7f3f4 ffffff f1eaec e5dadd 8e777f 27141c 715660 957e86 1b1216 281a1f 37242c 49333c 9f8790 f5eef0 bca4ac 988088
f7f3f4 ffffff f1eaec e5dadd 8f777f 27141c 71565f 957e86 1c1216 281a1f 37242b 49333c a0868f f5eef0 bca4ac 988088
f7f3f4 ffffff f1eaec e5dadd 8f777f 28141b 71565f 957e86 1c1215 281a1f 37242b 4a333b a0868f f5eef0 bca4ac 988088
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141b 71565f 957e85 1c1215 281a1f 37242b 4a333b a0868e f5eef0 bca4ab 988087
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141b 71565e 957e85 1c1215 281a1e 37242b 4a333b a0868e f5eef0 bca4ab 988087
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141a 71565e 957e85 1c1215 281a1e 37242a 4a333a a0868e f5eef0 bca4ab 988087
f4f4f4 ffffff ececec dddddd 7e7e7e 1b1b1b 5e5e5e 858585 151515 1e1e1e 2b2b2b 3b3b3b 8e8e8e f0f0f0 ababab 878787
""")
        /// « Autre… » : plein clair, encre teintée claire, plein sombre, encre teintée sombre.
        static let primaires = lire("""
b43368 962554 f089aa fab9cc
b43366 962553 f089a9 fab9cb
b53364 972551 f189a7 fab9ca
b53362 972550 f189a6 fab9c9
b63360 97244e f289a4 fbb9c8
b6335e 98244c f289a3 fbb9c7
b6325d 98244b f289a1 fbb9c6
b7325b 982449 f389a0 fbb9c5
b73259 992447 f3899e fcb9c4
b73257 992446 f3899d fcb9c3
b83255 992444 f3899b fcb9c2
b83253 992442 f4899a fcb9c1
b83251 9a2441 f48998 fcb9c0
b9324f 9a243f f48a96 fcb9bf
b9334d 9a243d f48a95 fcb9be
b9334b 9a243b f58a93 fdb9bd
b93349 9a2439 f58a92 fdbabc
b93347 9a2437 f58a90 fdbabb
b93345 9a2436 f58a8f fdbabb
ba3343 9a2534 f58a8d fdbaba
ba3441 9a2431 f58a8b fdbab9
ba343e 9a2530 f58b8a fdbab8
ba343c 9b252e f58b88 fdbab7
ba343a 9b252c f58b87 fdbab6
ba3538 9a2529 f58b85 fdbab5
ba3535 9a2527 f58b84 fdbbb4
ba3533 9a2625 f58c82 fdbbb3
ba3630 9a2623 f58c81 fdbbb2
ba362e 9a2720 f58c7f fdbbb2
ba362b 9a271e f58c7e fdbbb1
ba3728 9a271b f58d7c fdbbb0
ba3725 9a2819 f58d7b fdbbaf
ba3822 9a2815 f58d79 fdbcae
b9381f 9a2913 f58d77 fcbcad
b9391b 9a290e f48e76 fcbcac
b93917 992909 f48e74 fcbcac
b93a13 992a04 f48e73 fcbcab
b93a0e 992b00 f48f71 fcbdaa
b83b07 972d00 f48f70 fcbda9
b83c00 952f00 f38f6e fbbda8
b73e00 943100 f3906d fbbda8
b54000 933200 f3906c fbbda7
b44200 923400 f2916a fbbea6
b24400 903500 f29169 fbbea5
b14500 8f3700 f29167 fabea5
af4700 8d3800 f19266 fabea4
ae4800 8c3900 f19264 fabfa3
ad4a00 8c3a00 f19363 f9bfa2
ab4b00 8b3b00 f09362 f9bfa2
aa4c00 893c00 f09360 f9bfa1
a94e00 883d00 ef945f f8c0a0
a84f00 873e00 ef945d f8c0a0
a75000 863f00 ee955c f8c09f
a65100 854000 ee955b f7c09e
a55200 844100 ed9659 f7c19e
a45300 834100 ed9658 f7c19d
a25400 824200 ec9757 f6c19d
a15500 814300 eb9756 f6c19c
a05500 814300 eb9854 f5c29c
9f5600 7f4400 ea9853 f5c29b
9e5700 7f4400 ea9952 f4c29a
9d5800 7d4500 e99951 f4c39a
9c5900 7d4500 e89a50 f3c399
9c5900 7c4600 e79a4e f3c399
9b5a00 7b4700 e79b4d f2c499
9a5b00 7b4700 e69b4c f2c498
995b00 794700 e59c4b f1c498
985c00 794800 e49c4a f1c497
975d00 784900 e49d49 f0c597
965d00 774900 e39e48 f0c596
955e00 764900 e29e47 efc596
945e00 754a00 e19f46 efc696
935f00 754a00 e09f45 eec695
936000 734a00 dfa045 edc695
926000 734b00 dfa044 edc795
916100 724b00 dea143 ecc795
906100 724c00 dda242 ecc794
8f6200 714c00 dca242 ebc894
8e6200 704d00 dba341 eac894
8d6300 704d00 daa341 eac894
8d6300 6f4d00 d9a440 e9c994
8c6400 6e4e00 d8a440 e8c993
8b6400 6e4e00 d7a53f e7c993
8a6500 6d4e00 d6a63f e7ca93
896500 6c4f00 d5a63e e6ca93
886600 6c4f00 d4a73e e5ca93
886600 6a4f00 d2a73e e5cb93
876700 694f00 d1a83e e4cb93
866700 695000 d0a83e e3cb93
856800 685000 cfa93e e2cc93
846800 675100 ceaa3e e1cc93
836800 675100 cdaa3e e1cd93
826900 665100 cbab3e e0cd93
816900 655100 caab3e dfcd93
816a00 655200 c9ac3e dece93
806a00 645200 c8ad3f ddce93
7f6b00 635300 c6ad3f ddce93
7e6b00 625300 c5ae40 dccf94
7d6c00 615300 c4ae40 dbcf94
7c6c00 605300 c3af41 dacf94
7b6c00 605400 c1af41 d9d094
7a6d00 5f5400 c0b042 d8d094
796d00 5e5400 bfb042 d8d095
786e00 5d5500 bdb143 d7d195
776e00 5d5500 bcb244 d6d195
766f00 5b5500 bab245 d5d196
756f00 5a5500 b9b345 d4d296
746f00 595600 b8b346 d3d296
737000 595600 b6b447 d2d297
727000 575600 b5b448 d1d397
707100 565700 b3b549 d0d397
6f7100 565700 b2b54a cfd398
6e7200 555700 b0b64b ced398
6d7200 535800 afb64c cdd499
6c7300 535800 adb74d cdd499
6a7300 515800 abb74f ccd49a
697400 505900 aab850 cbd59a
677400 4f5900 a8b851 cad59b
667500 4e5900 a7b952 c9d59b
657500 4c5a00 a5b953 c8d69c
637500 4b5a00 a3ba55 c7d69c
617600 4a5a00 a2ba56 c6d69d
607600 485a00 a0bb57 c5d69e
5e7700 475b00 9fbb59 c4d79e
5c7800 465b00 9dbc5a c3d79f
5a7800 445b00 9bbc5b c2d79f
587900 425c00 99bd5d c1d8a0
567900 415c00 98bd5e c0d8a1
547a00 3f5c00 96bd60 bfd8a1
527a00 3d5d00 94be61 bed8a2
4f7b00 3b5d00 92be62 bdd9a3
4d7b00 395d00 91bf64 bcd9a4
4a7c00 375e00 8fbf65 bbd9a4
477d00 345e00 8dbf67 bad9a5
437d00 315f00 8bc068 b9daa6
407e00 2f5f00 89c06a b8daa7
3c7f00 2b5f00 88c16b b7daa7
377f00 285f00 86c16d b6daa8
328000 246000 84c16e b5daa9
2c8100 1f6000 82c270 b4dbaa
258101 196000 80c271 b3dbab
208209 126100 7ec273 b2dbab
1a8210 076100 7cc375 b1dbac
118316 006206 7ac376 b0dbad
05831a 00610f 78c378 afdcae
008321 006116 76c479 aedcaf
008328 00611b 74c47b aedcb0
00832d 006120 72c47c addcb0
008232 006123 70c47e acdcb1
008236 006127 6ec580 abddb2
00823a 00612a 6cc581 aaddb3
00823d 00612c 6ac583 a9ddb4
008240 00602e 68c584 a8ddb5
008143 006031 66c686 a7ddb6
008146 006033 64c688 a6ddb7
008148 006035 62c689 a5ddb8
00814b 006037 5fc68b a4deb9
00814d 006038 5dc68c a4deba
00814f 00603a 5bc78e a3deba
008051 00603c 59c790 a2debb
008053 00603d 57c791 a1debc
008055 00603f 54c793 a0debd
008057 005f3f 52c794 9fdebe
008058 005f41 50c796 9fdebf
00805a 005f42 4ec898 9edec0
00805b 005f43 4bc899 9ddec1
007f5d 005f45 49c89b 9cdfc2
007f5e 005f46 46c89c 9cdfc3
007f60 005f47 44c89e 9bdfc4
007f61 005f48 42c8a0 9adfc5
007f62 005f49 3fc8a1 9adfc6
007f64 005f4a 3dc8a3 99dfc7
007f65 005f4b 3ac8a4 98dfc8
007e66 005f4c 38c8a6 98dfc9
007e67 005f4d 35c8a8 97dfca
007e68 005f4f 32c8a9 96dfcb
007e6a 005f4f 30c8ab 96dfcc
007e6b 005e4f 2dc8ac 95dfcd
007e6c 005e50 2ac8ae 95dfce
007e6d 005e51 27c8af 94dfcf
007e6e 005e52 24c8b1 94dfd0
007d6f 005e53 21c8b3 93dfd1
007d70 005e54 1ec8b4 93dfd1
007d71 005e55 1ac8b6 92dfd2
007d72 005e56 17c8b7 92dfd3
007d73 005e56 13c8b9 91dfd4
007d74 005e57 0fc8ba 91dfd5
007d75 005e58 0ac8bc 91dfd6
007d76 005e59 04c8bd 90dfd7
007c77 005e5a 00c8bf 90dfd8
007c77 005e5b 00c7c0 90dfd9
007c78 005e5b 00c7c1 90dfda
007c79 005e5b 00c7c3 8fdedb
007c7a 005d5c 00c7c4 8fdedc
007c7b 005d5d 00c7c6 8fdedd
007c7c 005d5d 00c7c7 8fdedd
007c7d 005d5e 00c6c8 8fdede
007b7e 005d5f 00c6ca 8fdedf
007b7f 005d60 00c6cb 8edee0
007b7f 005d61 00c6cc 8edee1
007b80 005d61 00c6ce 8edee2
007b81 005d62 00c5cf 8edee3
007b82 005d63 00c5d0 8edde4
007b83 005d64 00c5d2 8edde4
007b84 005d64 00c5d3 8edde5
007a85 005c64 00c5d4 8fdde6
007a85 005c65 00c4d6 8fdde7
007a86 005c66 00c4d7 8fdde8
007a87 005c67 00c4d8 8fdde8
007a88 005c68 00c4da 8fdce9
007a89 005c68 00c3db 8fdcea
007a8a 005c69 02c3dc 90dceb
00798b 005c6a 07c3de 90dceb
00798c 005c6a 0cc3df 90dcec
00798d 005b6a 11c2e0 90dced
00798d 005b6b 15c2e1 91dbee
00798e 005b6c 18c2e2 91dbee
00798f 005b6d 1cc1e3 91dbef
007890 005b6e 1fc1e4 92dbf0
007891 005b6f 22c1e5 92dbf1
007892 005b70 25c0e6 93daf1
007893 005b71 28c0e7 93daf2
007894 005b72 2bc0e9 94daf3
007895 005b72 2dbfea 94daf3
007796 005a73 30bfeb 95d9f4
007797 005a73 33beeb 95d9f4
007798 005a75 35beec 96d9f5
007799 005a76 38beed 96d9f6
00779a 005a77 3abdee 97d8f6
00769c 005a78 3dbdef 98d8f7
00769d 005a79 3fbcf0 98d8f7
00769e 005a7a 41bcf1 99d8f8
00769f 005a7a 44bcf2 99d7f8
0075a0 00597b 46bbf2 9ad7f9
0075a2 00597c 48bbf3 9bd7f9
0075a3 00597e 4abaf4 9bd7fa
0074a4 00597f 4dbaf5 9cd6fa
0074a6 005980 4fb9f6 9dd6fb
0074a7 005881 51b9f6 9ed6fb
0073a9 005882 53b8f7 9ed6fc
0073aa 005884 55b8f8 9fd5fc
0073ac 005886 58b8f8 a0d5fd
0072ae 005786 5ab7f9 a1d5fd
0072af 005788 5cb7f9 a2d4fd
0071b1 005789 5eb6fa a2d4fe
0071b3 00568a 60b6fa a3d4fe
0070b5 00568d 62b5fb a4d4fe
0070b7 00568f 64b5fb a5d3ff
006fb9 005590 66b4fc a6d3ff
006fbb 005593 68b4fc a7d3ff
006ebe 005594 6ab3fd a8d2ff
006dc1 005497 6cb3fd a9d2ff
006cc3 00549a 6eb2fe aad2ff
006bc6 00539c 70b2fe abd1ff
006aca 00529e 71b1fe acd1ff
096acb 0052a3 73b1ff add1ff
1369cb 0051a6 75b0ff aed0ff
1a68cb 0750a6 77b0ff afd0ff
2068cb 0f50a7 79afff b0d0ff
2567cc 1550a7 7bafff b1d0ff
2966cc 194fa8 7daeff b2cfff
2d66cc 1e4fa8 7faeff b3cfff
3065cc 214ea8 81adff b4cfff
3465cc 244ea9 83adff b5ceff
3764cd 274ea9 84acff b5ceff
3a63cd 2a4da9 86acff b6ceff
3d63cd 2d4daa 88abff b7cdff
4062cd 2f4ca9 8aabff b8cdff
4261cd 324ca9 8baaff b9cdff
4561cd 344ba9 8daaff bacdff
4760cd 364ba9 8ea9ff bbccff
4a5fcc 394aa9 90a9ff bcccff
4c5fcc 3b4aaa 92a8ff bdccff
4e5ecc 3d49a9 93a8ff bdcbff
505dcc 3f49a9 95a7ff becbff
525dcc 4149a9 96a7ff bfcbff
555ccb 4348a9 98a6ff c0caff
575bcb 4548a9 99a5ff c1caff
595bcb 4647a9 9ba5ff c2caff
5a5acb 4846a8 9da4ff c3c9ff
5c5aca 4a46a9 9ea4ff c3c9ff
5e59ca 4b46a8 a0a3fe c4c9ff
6058c9 4d45a8 a1a3fe c5c8ff
6258c9 4e45a7 a3a2fd c6c8ff
6457c9 5044a7 a4a2fd c7c8ff
6556c8 5244a7 a6a1fd c8c7ff
6756c8 5343a7 a7a1fc c9c7ff
6955c7 5543a6 a9a0fc cac7ff
6a55c6 5642a6 aaa0fb cbc6ff
6c54c6 5842a6 ac9ffb cbc6fe
6e53c5 5942a5 ad9ffa ccc6fe
6f53c5 5b41a5 ae9efa cdc5fe
7152c4 5c41a4 b09ef9 cec5fd
7252c3 5e40a3 b19df9 cfc5fd
7451c2 5e3fa2 b39df8 d0c5fd
7550c2 603fa2 b49cf7 d1c4fc
7750c1 613fa2 b59cf7 d2c4fc
784fc0 633ea1 b79cf6 d3c4fb
7a4fbf 643da0 b89bf5 d3c3fb
7b4ebe 653d9f b99bf5 d4c3fa
7d4dbe 663d9f bb9af4 d5c3fa
7e4dbd 683c9e bc9af3 d6c3f9
7f4cbc 693c9d bd99f2 d7c2f9
814cbb 6a3b9c bf99f1 d8c2f8
824bba 6b3b9c c098f1 d9c2f8
834bb9 6c3b9b c198f0 d9c1f7
854ab8 6e3a9a c298ef dac1f7
864ab7 6f3a99 c497ee dbc1f6
8749b6 703998 c597ed dcc1f6
8848b5 713897 c696ec ddc0f5
8a48b3 723896 c796eb ddc0f5
8b47b2 733795 c895ea dec0f4
8c47b1 743794 c995e9 dfc0f3
8d46b0 753793 cb95e8 e0bff3
8e46af 763692 cc94e7 e1bff2
9045ae 773691 cd94e6 e1bff1
9145ac 783590 ce93e5 e2bff1
9244ab 79358f cf93e4 e3bef0
9344aa 7a348e d093e3 e4beef
9443a9 7b348d d192e2 e4beef
9543a7 7c348c d292e1 e5beee
9642a6 7d338b d392e0 e6beed
9742a5 7e3389 d491df e6bdec
9841a3 7e3288 d591de e7bdec
9941a2 7f3287 d691dc e8bdeb
9a40a1 803186 d790db e8bdea
9b409f 813185 d890da e9bde9
9c3f9e 823083 d990d9 eabce9
9d3f9c 833082 da8fd7 eabce8
9e3e9b 832f81 db8fd6 ebbce7
9f3e99 842f80 dc8fd5 ecbce6
a03d98 852f7e dd8ed4 ecbce6
a13d96 862e7d de8ed2 edbce5
a23c95 872e7c df8ed1 eebbe4
a33c93 872e7a df8dd0 eebbe3
a43c92 882d79 e08dce efbbe2
a43b90 892d78 e18dcd efbbe1
a53b8f 8a2c76 e28dcc f0bbe0
a63a8d 8a2c75 e38cca f0bbe0
a73a8c 8b2c74 e38cc9 f1badf
a8398a 8c2b72 e48cc8 f1bade
a83988 8c2b71 e58cc6 f2badd
a93987 8d2a6f e68cc5 f2badc
aa3885 8e2a6e e68bc4 f3badb
ab3883 8e2a6d e78bc2 f3bada
ab3782 8f296b e88bc1 f4bad9
ac3780 8f296a e88bbf f4bad9
ad377e 902968 e98bbe f5bad8
ad367d 902866 ea8abc f5bad7
ae367b 912865 ea8abb f6b9d6
af3679 912764 eb8ab9 f6b9d5
af3578 922862 ec8ab8 f6b9d4
b03576 932761 ec8ab7 f7b9d3
b03574 93275f ed8ab5 f7b9d2
b13572 93265e ed8ab4 f8b9d1
b23471 94265c ee8ab2 f8b9d0
b2346f 94265a ee89b1 f8b9cf
b3346d 952659 ef89af f9b9ce
b3346b 952557 ef89ae f9b9cd
b4336a 962556 f089ac f9b9cc
""")
        static let prereglages = lire("""
0b5fe0 004aba 7cadff b1ceff
0e7a62 005f4c 4bcba9 9fe2cc
cf365f a11642 f27f93 f9b1bb
c6481b 992d00 ea8869 f3b6a3
4c5667 3a4352 b6becc d9dee7
""")
        private static func lire(_ texte: String) -> [[UInt32]] {
            texte.split(separator: "\n").map { $0.split(separator: " ").map { UInt32($0, radix: 16) ?? 0 } }
        }
    }
}
