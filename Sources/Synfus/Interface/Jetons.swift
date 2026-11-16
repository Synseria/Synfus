// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 3a1cf9d706c5146a · contenu 7073937b041911fc
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
        let selectionInactive: RVB
        let primaire: RVB
        let primaireEncre: RVB
        let primaireFond: RVB
        let encreSurPrimaire: RVB
        let nuit: RVB
        let nuitProfond: RVB
        let safran: RVB
        let voileImage: RVB
        let encreSurImage: RVB
        let encreSecondaireSurImage: RVB
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
            selectionInactive: n[5].voile(sombre ? 0.14 : 0.1),
            primaire: plein,
            primaireEncre: RVB(ligne[sombre ? 3 : 1]),
            primaireFond: plein.voile(sombre ? 0.22 : 0.12),
            encreSurPrimaire: sombre ? RVB(0x0e1322) : RVB(0xffffff),
            nuit: RVB(0x16284f),
            nuitProfond: RVB(0x0e1322),
            safran: RVB(0xffc53d),
            voileImage: RVB(0x0e1322, opacite: 0.88),
            encreSurImage: RVB(0xffffff),
            encreSecondaireSurImage: RVB(0xffffff, opacite: 0.78),
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
        static let controle: CGFloat = 32
        static let boutonIcone: CGFloat = 32
        static let cibleMin: CGFloat = 24
        static let `case`: CGFloat = 14
        static let interrupteurLargeur: CGFloat = 32
        static let interrupteurHauteur: CGFloat = 18
        static let rangee: CGFloat = 32
        static let rangeeNavigation: CGFloat = 36
        static let rangeePalette: CGFloat = 40
        static let touche: CGFloat = 20
        static let iconeBarre: CGFloat = 19
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
        static let titre = Typo(taille: 16, interligne: 22, graisse: .semibold, famille: .titre, chiffresFixes: false)
        static let corps = Typo(taille: 14, interligne: 20, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let corpsFort = Typo(taille: 14, interligne: 20, graisse: .semibold, famille: .texte, chiffresFixes: false)
        static let note = Typo(taille: 13, interligne: 18, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let petit = Typo(taille: 12, interligne: 16, graisse: .regular, famille: .texte, chiffresFixes: false)
        static let micro = Typo(taille: 11, interligne: 14, graisse: .medium, famille: .texte, chiffresFixes: false)
        static let chiffre = Typo(taille: 13, interligne: 18, graisse: .regular, famille: .texte, chiffresFixes: true)
        static let grandChiffre = Typo(taille: 24, interligne: 28, graisse: .medium, famille: .titre, chiffresFixes: true)
        static let code = Typo(taille: 14, interligne: 20, graisse: .regular, famille: .code, chiffresFixes: false)
        static let codeInterface = Typo(taille: 13, interligne: 18, graisse: .regular, famille: .code, chiffresFixes: false)
        static let raccourci = Typo(taille: 12, interligne: 16, graisse: .medium, famille: .texte, chiffresFixes: false)
        static let navigation = Typo(taille: 15, interligne: 20, graisse: .medium, famille: .texte, chiffresFixes: false)
    }

    /// Rangées 0…359 : teintes des fonds ; 360 : « Neutre ». Huit neutres clairs puis huit sombres,
    /// déjà ajustés aux seuils de contraste (`outils/theme.py`) : l'app ne calcule rien.
    private enum Table {
        static let neutres = lire("""
f8f3f4 ffffff f1eaec e5dadd 8f777d 28141a 72565d 957e84 291e21 36262b 463237 594148 a1878e fffdfd c9b0b7 998087
f8f3f4 ffffff f1eaeb e5dadc 8f777d 28141a 72565d 967e84 291e21 36262b 463237 594148 a1878e fffdfd c9b0b6 998087
f8f3f4 ffffff f1eaeb e5dadc 8f777d 281419 72565d 967e84 291e21 36262a 463237 594147 a1878d fffdfd c9b0b6 998086
f8f3f4 ffffff f1eaeb e5dadc 90777c 281419 72565c 967e83 291e21 36262a 463237 594147 a1878d fffdfd cab0b6 998086
f8f3f4 ffffff f1eaeb e5dadc 90777c 281419 72565c 967e83 291e21 36262a 463236 594147 a1878c fffdfd cab0b5 998086
f8f3f4 ffffff f2eaeb e5dadc 90777c 281419 72565b 967e83 291e20 36262a 463236 5a4146 a1878c fffdfd cab0b5 998085
f8f3f4 ffffff f2eaeb e5dadc 90777b 281418 72565b 967e82 291e20 362629 463236 5a4146 a1878c fffdfd cab0b5 9a8085
f8f3f3 ffffff f2eaeb e5dadb 90777b 281418 72565b 967e82 291e20 362629 463235 5a4146 a1878b fffdfd cab0b4 9a8084
f8f3f3 ffffff f2eaeb e5dadb 90777a 281418 72565a 967e82 291e20 362629 463235 5a4145 a2878b fffdfd cab0b4 9a8084
f8f3f3 ffffff f2eaeb e5dadb 90777a 291417 73565a 967e81 291e20 362629 463235 5a4245 a2878b fffdfd cab0b4 9a8084
f8f3f3 ffffff f2eaea e5dadb 90777a 291417 735659 967e81 291e20 362729 463235 5a4245 a2878a fffdfd cab0b3 9a8083
f8f3f3 ffffff f2eaea e5dadb 907779 291417 735659 967e81 291e20 362728 463234 5a4244 a2878a fffdfd cab0b3 9a8083
f8f3f3 ffffff f2eaea e5dadb 907779 291416 735659 967e80 291e1f 362728 473234 5a4244 a2878a fffdfd cab0b3 9a8083
f8f3f3 ffffff f2eaea e5dada 907779 291416 735658 967e80 291e1f 362728 473234 5a4244 a28789 fffdfd cab0b2 9a8082
f8f3f3 ffffff f2eaea e6dada 907778 291416 735658 977e80 291e1f 362728 473233 5a4243 a28789 fffdfd cab0b2 9a8082
f8f3f3 ffffff f2eaea e6dada 907778 291416 735657 977e7f 291e1f 362727 473233 5a4243 a28788 fffdfd cab0b1 9a8082
f8f3f3 ffffff f2eaea e6dada 907778 291415 735657 977e7f 291e1f 362727 473233 5a4243 a28788 fffdfd cab0b1 9a8181
f8f3f3 ffffff f2eaea e6dada 917777 291415 735657 977e7f 291e1f 362727 473232 5a4242 a28788 fffdfd cbb0b1 9a8181
f8f3f3 ffffff f2eaea e6dada 917777 291415 735656 977e7e 291e1f 362727 473232 5a4242 a28787 fffdfd cbb0b0 9a8181
f8f3f3 ffffff f2eaea e6dada 917777 291414 735656 977e7e 291e1e 362727 473232 5a4242 a28787 fffdfd cbb1b0 9a8180
f8f3f3 ffffff f2eae9 e6dad9 917776 291414 735655 977e7e 291f1e 362726 473232 5a4241 a28787 fffdfd cbb1b0 9a8180
f8f3f3 ffffff f2eae9 e6dad9 917776 291414 735655 977e7d 291f1e 362726 473231 5a4241 a28786 fffdfd cbb1af 9a8180
f8f3f3 ffffff f2eae9 e6dad9 917776 291413 735655 977e7d 291f1e 362726 473231 5a4241 a28886 fffdfd cbb1af 9a817f
f8f3f2 ffffff f2eae9 e6dad9 917775 291413 735654 977e7d 291f1e 362726 473231 5a4240 a28886 fffdfc cbb1af 9a817f
f8f3f2 ffffff f2eae9 e6dad9 917775 291413 735654 977e7c 291f1e 362726 473231 5a4240 a28885 fffdfc cbb1ae 9a817f
f8f3f2 ffffff f2eae9 e6dad9 917775 291412 735653 977f7c 291f1e 362725 473230 5a4240 a28885 fffdfc cbb1ae 9a817e
f8f3f2 ffffff f2eae9 e6dad9 917774 291412 735653 977f7c 291f1d 362725 473230 5a423f a28885 fffdfc cbb1ae 9a817e
f8f3f2 ffffff f2eae9 e6dad8 917774 291412 735653 977f7b 291f1d 362725 473230 5a423f a28884 fffdfc cbb1ad 9a817e
f8f3f2 ffffff f2eae9 e6dad8 917774 291412 735652 977f7b 291f1d 362725 47322f 5a423f a28884 fffdfc cbb1ad 9a817d
f8f3f2 ffffff f2eae9 e6dad8 917873 291411 735652 977f7b 291f1d 362724 47322f 5a423e a28884 fffdfc cbb1ad 9a817d
f8f3f2 ffffff f2eae8 e6dad8 907873 291411 735752 977f7a 291f1d 362724 47322f 5a423e a28883 fffdfc cab1ac 9a817d
f8f3f2 ffffff f2eae8 e6dad8 907873 291411 735751 977f7a 291f1d 362724 47332f 5a423e a28883 fffdfc cab1ac 9a817c
f8f3f2 ffffff f2eae8 e5dad8 907872 291410 735751 977f7a 291f1d 362724 47332e 5a423d a28883 fffdfc cab1ac 9a817c
f8f3f2 ffffff f2eae8 e5dad8 907872 291510 735750 967f7a 291f1c 362724 47332e 5a423d a28882 fffdfc cab1ac 9a817c
f8f3f2 ffffff f2eae8 e5dad7 907872 291510 735750 967f79 291f1c 362723 47332e 5a433d a28882 fffdfc cab1ab 9a817b
f8f3f2 ffffff f2eae8 e5dad7 907872 291510 735750 967f79 291f1c 362723 47332e 5a433d a28882 fffdfc cab1ab 9a827b
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 73574f 967f79 291f1c 362723 46332d 5a433c a28881 fffdfc cab1ab 9a827b
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 73574f 967f78 291f1c 362723 46332d 5a433c a28881 fffdfc cab2aa 9a827b
f8f3f2 ffffff f2eae8 e5dad7 907871 29150f 72574f 967f78 291f1c 362723 46332d 5a433c a28981 fffdfc cab2aa 9a827a
f8f3f2 ffffff f2eae8 e5dad7 907870 29150e 72574e 967f78 291f1c 362723 46332d 5a433b a18980 fffdfc cab2aa 9a827a
f8f3f1 ffffff f2eae8 e5dad7 907870 28150e 72574e 967f78 291f1c 362722 46332c 5a433b a18980 fffdfc cab2aa 9a827a
f8f3f1 ffffff f1eae8 e5dad7 907870 28150e 72574e 968077 291f1b 362722 46332c 5a433b a18980 fffdfc cab2a9 998279
f8f3f1 ffffff f1eae7 e5dad6 907870 28150e 72584d 968077 291f1b 362822 46332c 59433b a18980 fffdfc cab2a9 998279
f8f3f1 ffffff f1eae7 e5dad6 90796f 28150d 72584d 968077 291f1b 362822 46332c 59433a a1897f fffdfc c9b2a9 998279
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584d 968077 291f1b 362822 46332b 59433a a1897f fffdfc c9b2a8 998279
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584c 958076 291f1b 362822 46332b 59433a a1897f fffdfc c9b2a8 998278
f8f3f1 ffffff f1eae7 e5dbd6 8f796f 28150d 72584c 958076 291f1b 362821 46332b 59433a a1897f fffdfc c9b2a8 998278
f8f3f1 ffffff f1eae7 e5dbd6 8f796e 28150c 71584c 958076 291f1b 362821 46342b 594439 a1897e fffdfc c9b2a8 998278
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160c 71584c 958076 291f1b 362821 46342b 594439 a0897e fffdfc c9b2a7 998378
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160c 71584b 958075 291f1b 352821 45342a 594439 a08a7e fffdfc c9b3a7 988377
f7f3f1 ffffff f1eae7 e5dbd6 8f796e 28160b 71584b 958075 281f1a 352821 45342a 594439 a08a7d fffdfc c9b3a7 988377
f7f3f1 ffffff f1eae7 e5dbd5 8f796d 28160b 71594b 958075 281f1a 352821 45342a 584438 a08a7d fffdfc c8b3a7 988377
f7f3f1 ffffff f1eae7 e4dbd5 8e796d 27160b 71594a 958075 281f1a 352820 45342a 584438 a08a7d fffdfc c8b3a7 988377
f7f3f1 ffffff f1eae7 e4dbd5 8e796d 27160b 71594a 948175 28201a 352820 45342a 584438 a08a7d fffdfc c8b3a6 988376
f7f3f1 ffffff f1ebe7 e4dbd5 8e7a6d 27160b 70594a 948174 28201a 352820 453429 584438 a08a7d fffdfb c8b3a6 988376
f7f3f1 ffffff f1ebe7 e4dbd5 8e7a6c 27160a 70594a 948174 28201a 352820 453429 584437 9f8a7c fffdfb c8b3a6 988376
f7f3f1 ffffff f1ebe6 e4dbd5 8e7a6c 27160a 705949 948174 28201a 352820 453429 584437 9f8a7c fffdfb c8b3a6 978376
f7f3f1 ffffff f1ebe6 e4dbd5 8e7a6c 27160a 705949 948174 28201a 352820 453429 584537 9f8a7c fffdfb c7b3a5 978376
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6c 27160a 705949 948174 28201a 352920 443429 574537 9f8a7c fffdfb c7b3a5 978475
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6c 271709 6f5949 938173 28201a 34291f 443528 574537 9f8b7c fffdfb c7b4a5 978475
f7f3f1 ffffff f1ebe6 e4dbd5 8d7a6b 271709 6f5a48 938173 28201a 34291f 443528 574536 9e8b7b fffdfb c7b4a5 978475
f7f3f1 ffffff f0ebe6 e4dbd5 8d7a6b 261709 6f5a48 938173 28201a 34291f 443528 574536 9e8b7b fffdfb c7b4a5 978475
f7f3f1 ffffff f0ebe6 e4dbd5 8d7a6b 261709 6f5a48 938173 282019 34291f 443528 574536 9e8b7b fffdfb c6b4a5 968475
f7f3f1 ffffff f0ebe6 e4dbd4 8c7b6b 261709 6f5a48 938273 282019 34291f 443528 574536 9e8b7b fffdfb c6b4a4 968475
f7f4f1 ffffff f0ebe6 e3dbd4 8c7b6b 261708 6e5a48 938273 272019 34291f 443528 564536 9e8b7b fffdfb c6b4a4 968474
f7f4f1 ffffff f0ebe6 e3dbd4 8c7b6b 261708 6e5a47 928273 272019 34291f 433528 564536 9d8b7a fffdfb c6b4a4 968474
f7f4f0 ffffff f0ebe6 e3dcd4 8c7b6b 261708 6e5a47 928272 272019 34291f 433527 564635 9d8b7a fffdfb c6b4a4 958474
f7f4f0 ffffff f0ebe6 e3dcd4 8c7b6a 261708 6e5b47 928272 272019 34291f 433527 564635 9d8c7a fffdfb c5b5a4 958574
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 928272 272019 33291f 433527 564635 9d8c7a fffdfb c5b5a4 958574
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 918272 272019 33291e 433527 554635 9c8c7a fffdfb c5b5a4 958574
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251808 6d5b47 918272 272019 33291e 423627 554635 9c8c7a fffdfb c5b5a3 958574
f7f4f0 ffffff f0ebe6 e3dcd4 8b7b6a 251807 6d5b47 918272 272019 33291e 423627 554635 9c8c7a fffdfb c4b5a3 948573
f7f4f0 ffffff f0ebe6 e3dcd4 8a7c6a 251807 6c5b46 918372 272019 332a1e 423627 554635 9c8c7a fffdfb c4b5a3 948573
f6f4f0 ffffff f0ebe6 e2dcd4 8a7c6a 251807 6c5b46 918372 272019 332a1e 423627 554634 9b8c79 fffdfa c4b5a3 948573
f6f4f0 ffffff f0ebe6 e2dcd4 8a7c6a 241807 6c5b46 908371 272119 332a1e 423627 544634 9b8c79 fffdfa c4b5a3 948573
f6f4f0 ffffff efebe6 e2dcd4 8a7c69 241807 6c5c46 908371 262119 322a1e 423627 544734 9b8c79 fffdfa c3b5a3 938673
f6f4f0 ffffff efebe6 e2dcd4 8a7c69 241807 6b5c46 908371 262119 322a1e 413626 544734 9b8d79 fffdfa c3b6a3 938673
f6f4f0 ffffff efebe6 e2dcd4 897c69 241807 6b5c46 908371 262119 322a1e 413626 544734 9a8d79 fffdfa c3b6a3 938673
f6f4f0 ffffff efebe6 e2dcd4 897c69 241907 6b5c46 8f8371 262119 322a1e 413626 534734 9a8d79 fffdfa c3b6a3 938673
f6f4f0 ffffff efebe6 e2dcd4 897c69 231907 6a5c46 8f8371 262119 322a1e 413726 534734 9a8d79 fffdfa c2b6a3 928673
f6f4f0 ffffff efebe6 e2dcd4 887d69 231907 6a5c46 8f8471 262119 322a1e 413726 534734 9a8d79 fffdfa c2b6a3 928673
f6f4f0 ffffff efebe6 e1dcd4 887d69 231907 6a5c46 8f8471 262119 312a1e 403726 534734 998d79 fffdfa c2b6a3 928673
f6f4f0 ffffff efebe6 e1dcd4 887d69 231906 6a5d45 8e8471 262119 312a1e 403726 524734 998d79 fffdfa c2b6a2 928673
f6f4f0 ffffff efece6 e1dcd4 887d69 231906 695d45 8e8471 262118 312a1e 403726 524834 998e79 fffdfa c1b6a2 918773
f6f4f0 ffffff efece6 e1dcd4 877d69 221906 695d45 8e8471 252118 312a1e 403726 524834 988e79 fffdf9 c1b7a2 918773
f6f4f0 ffffff efece6 e1ddd4 877d69 221906 695d45 8e8471 252118 312b1e 3f3726 524834 988e79 fffdf9 c1b7a2 918773
f6f4f0 ffffff eeece6 e1ddd4 877d69 221a06 685d45 8d8471 252118 312b1e 3f3726 514834 988e79 fffdf9 c0b7a2 908773
f6f4f0 ffffff eeece6 e1ddd4 867d69 221a06 685d45 8d8471 252118 302b1e 3f3726 514834 988e79 fffdf9 c0b7a2 908773
f6f4f0 ffffff eeece6 e1ddd4 867e69 211a06 685e45 8d8471 252118 302b1e 3f3726 514834 978e79 fffdf9 c0b7a2 908773
f6f4f0 ffffff eeece6 e0ddd4 867e69 211a06 675e45 8c8571 252118 302b1e 3e3826 504834 978e79 fffdf9 bfb7a2 8f8773
f6f4f0 ffffff eeece6 e0ddd4 867e69 211a06 675e45 8c8571 252118 302b1e 3e3826 504834 978e79 fffdf8 bfb7a2 8f8773
f5f4f0 ffffff eeece6 e0ddd4 857e69 211a06 675e45 8c8571 252118 302b1e 3e3826 504934 968f79 fffdf8 bfb7a2 8f8873
f5f4f0 ffffff eeece6 e0ddd4 857e69 211a06 665e45 8c8571 242118 302b1e 3e3826 504934 968f79 fffdf8 beb8a2 8f8873
f5f4f0 ffffff eeece6 e0ddd4 857e69 201a06 665e45 8b8571 242218 2f2b1e 3e3826 4f4934 968f79 fffdf8 beb8a2 8e8873
f5f4f0 ffffff eeece6 e0ddd4 847e69 201a06 665e45 8b8571 242219 2f2b1e 3d3826 4f4934 958f79 fffdf7 beb8a2 8e8873
f5f4f0 ffffff eeece6 e0ddd4 847e69 201b06 655f45 8b8571 242219 2f2b1e 3d3826 4f4934 958f79 fffdf7 beb8a3 8e8873
f5f4f0 ffffff edece6 dfddd4 847f69 201b06 655f46 8a8571 242219 2f2b1e 3d3826 4e4934 958f79 fffdf7 bdb8a3 8d8873
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 8a8671 242219 2f2b1e 3c3826 4e4934 948f79 fffdf7 bdb8a3 8d8873
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 8a8671 242219 2e2c1e 3c3926 4e4934 948f79 fffef7 bdb8a3 8d8873
f5f4f0 ffffff edece6 dfddd4 837f69 1f1b07 645f46 898671 242219 2e2c1e 3c3926 4d4a34 949079 fffef7 bcb8a3 8c8973
f5f4f0 ffffff edece6 dfddd4 827f69 1f1b07 635f46 898671 232219 2e2c1e 3c3926 4d4a34 939079 fefef7 bcb9a3 8c8973
f5f4f0 ffffff edece6 dfddd4 827f69 1e1b07 635f46 898671 232219 2e2c1e 3b3926 4d4a34 939079 fefef7 bcb9a3 8c8973
f5f4f0 ffffff edece6 deddd4 827f6a 1e1b07 636046 888671 232219 2e2c1e 3b3927 4d4a34 939079 fefef7 bbb9a3 8b8973
f5f4f0 ffffff edece6 deded4 817f6a 1e1b07 626046 888672 232219 2d2c1e 3b3927 4c4a34 929079 fefef7 bbb9a3 8b8973
f5f4f0 ffffff edece6 deded4 81806a 1d1c07 626046 888672 232219 2d2c1e 3b3927 4c4a35 92907a fefef7 bbb9a3 8b8973
f5f4f0 ffffff edece6 deded4 81806a 1d1c07 616046 878672 232219 2d2c1e 3a3927 4c4a35 91907a fefef7 bab9a3 8a8973
f5f4f0 ffffff ecece6 deded4 80806a 1d1c07 616047 878772 232219 2d2c1e 3a3927 4b4a35 91917a fefef7 bab9a3 8a8974
f4f5f0 ffffff ecece6 deded4 80806a 1d1c07 616047 878772 222219 2c2c1e 3a3927 4b4b35 91917a fefef8 b9b9a4 8a8a74
f4f5f0 ffffff ecece6 deded4 80806a 1c1c08 606047 868772 222219 2c2c1e 393a27 4b4b35 90917a fefef8 b9baa4 898a74
f4f5f0 ffffff ecece6 ddded4 7f806a 1c1c08 606147 868772 222219 2c2c1f 393a27 4a4b35 90917a fefef8 b9baa4 898a74
f4f5f0 ffffff ecede6 ddded4 7f806a 1c1c08 5f6147 868772 222219 2c2c1f 393a27 4a4b35 90917a fdfef8 b8baa4 898a74
f4f5f1 ffffff ecede6 ddded4 7f806b 1b1c08 5f6147 858772 222219 2c2d1f 393a28 4a4b35 8f917a fdfef8 b8baa4 888a74
f4f5f1 ffffff ecede6 ddded4 7e806b 1b1c08 5f6148 858773 222319 2b2d1f 383a28 494b36 8f917b fdfef8 b8baa4 888a74
f4f5f1 ffffff ecede6 ddded4 7e816b 1b1c08 5e6148 858773 212319 2b2d1f 383a28 494b36 8f917b fdfef8 b7baa4 888a75
f4f5f1 ffffff ecede6 ddded5 7e816b 1b1d09 5e6148 848773 212319 2b2d1f 383a28 494b36 8e917b fdfef8 b7baa5 878a75
f4f5f1 ffffff ecede6 dcded5 7d816b 1a1d09 5d6148 848873 212319 2b2d1f 373a28 484b36 8e927b fdfef8 b7baa5 878a75
f4f5f1 ffffff ebede6 dcded5 7d816b 1a1d09 5d6148 848873 21231a 2b2d1f 373a28 484c36 8e927b fdfef8 b6bba5 868b75
f4f5f1 ffffff ebede6 dcded5 7d816c 1a1d09 5d6249 838873 21231a 2a2d1f 373a28 474c36 8d927b fdfef8 b6bba5 868b75
f4f5f1 ffffff ebede6 dcded5 7c816c 191d09 5c6249 838874 21231a 2a2d20 373a29 474c37 8d927c fdfef8 b6bba5 868b75
f4f5f1 ffffff ebede6 dcded5 7c816c 191d09 5c6249 838874 21231a 2a2d20 363b29 474c37 8c927c fdfef8 b5bba5 858b76
f4f5f1 ffffff ebede6 dcded5 7b816c 191d0a 5b6249 828874 20231a 2a2d20 363b29 464c37 8c927c fcfef8 b5bba6 858b76
f4f5f1 ffffff ebede7 dbded5 7b816c 181d0a 5b624a 828874 20231a 292d20 363b29 464c37 8c927c fcfef8 b5bba6 858b76
f3f5f1 ffffff ebede7 dbdfd5 7b826d 181d0a 5b624a 828874 20231a 292d20 353b29 464c38 8b927d fcfef8 b4bba6 848b76
f3f5f1 ffffff ebede7 dbdfd5 7a826d 181d0a 5a624a 818875 20231a 292d20 353b29 454c38 8b937d fcfef8 b4bba6 848b76
f3f5f1 ffffff ebede7 dbdfd5 7a826d 171d0b 5a624a 818975 20231a 292d20 353b2a 454c38 8b937d fcfef8 b3bba7 848b77
f3f5f1 ffffff eaede7 dbdfd5 7a826d 171e0b 59634b 818975 20231a 292e21 343b2a 454c38 8a937d fcfef8 b3bba7 838c77
f3f5f1 ffffff eaede7 dbdfd6 79826e 171e0b 59634b 808975 20231a 282e21 343b2a 444d38 8a937d fcfef8 b3bca7 838c77
f3f5f1 ffffff eaede7 dbdfd6 79826e 161e0b 58634b 808975 1f231b 282e21 343b2a 444d39 89937e fcfef9 b2bca7 838c77
f3f5f1 ffffff eaede7 dadfd6 79826e 161e0c 58634b 808976 1f231b 282e21 343b2a 444d39 89937e fcfff9 b2bca7 828c78
f3f5f1 ffffff eaede7 dadfd6 78826e 161e0c 58634c 7f8976 1f231b 282e21 333b2b 434d39 89937e fcfff9 b2bca8 828c78
f3f5f1 ffffff eaede7 dadfd6 78826e 151e0c 57634c 7f8976 1f231b 272e21 333b2b 434d39 88937e fbfff9 b1bca8 828c78
f3f5f1 ffffff eaede7 dadfd6 78826f 151e0c 57634c 7f8976 1f231b 272e21 333c2b 434d3a 88937f fbfff9 b1bca8 818c78
f3f5f1 ffffff eaede7 dadfd6 77836f 151e0d 56634d 7e8977 1f231b 272e22 323c2b 424d3a 88937f fbfff9 b1bca8 818c79
f3f5f1 ffffff eaede7 dadfd6 77836f 141e0d 56634d 7e8977 1e231b 272e22 323c2c 424d3a 87947f fbfff9 b0bca9 818c79
f3f5f1 ffffff eaede7 dadfd6 778370 141e0d 56644d 7e8977 1e231b 262e22 323c2c 414d3a 879480 fbfff9 b0bca9 808c79
f3f5f1 ffffff e9ede8 d9dfd7 768370 141e0e 55644e 7d8a77 1e241b 262e22 313c2c 414d3b 879480 fbfff9 b0bca9 808c79
f3f5f2 ffffff e9ede8 d9dfd7 768370 131e0e 55644e 7d8a78 1e241c 262e22 313c2c 414d3b 869480 fbfff9 afbdaa 7f8d7a
f3f5f2 ffffff e9ede8 d9dfd7 768370 131f0e 54644e 7d8a78 1e241c 262e23 313c2d 404e3b 869480 fbfff9 afbdaa 7f8d7a
f2f5f2 ffffff e9ede8 d9dfd7 758371 131f0e 54644f 7d8a78 1e241c 262e23 313c2d 404e3c 859481 fbfff9 afbdaa 7f8d7a
f2f5f2 ffffff e9ede8 d9dfd7 758371 121f0f 53644f 7c8a78 1e241c 252e23 303c2d 404e3c 859481 fbfff9 aebdaa 7e8d7b
f2f5f2 ffffff e9ede8 d9dfd7 748371 121f0f 53644f 7c8a79 1d241c 252e23 303c2d 3f4e3c 859481 fbfffa aebdab 7e8d7b
f2f5f2 ffffff e9ede8 d9dfd7 748372 111f0f 536450 7c8a79 1d241c 252e23 303c2e 3f4e3c 849482 fafffa aebdab 7e8d7b
f2f5f2 ffffff e9ede8 d8dfd7 748372 111f10 526450 7b8a79 1d241c 252e23 2f3c2e 3f4e3d 849482 fafffa adbdab 7d8d7b
f2f5f2 ffffff e9eee8 d8dfd8 738372 111f10 526450 7b8a7a 1d241c 242f24 2f3c2e 3e4e3d 849482 fafffa adbdac 7d8d7c
f2f5f2 ffffff e9eee8 d8dfd8 738472 101f10 516451 7b8a7a 1d241d 242f24 2f3c2e 3e4e3d 839483 fafffa adbdac 7d8d7c
f2f5f2 ffffff e9eee8 d8dfd8 738473 101f10 516551 7a8a7a 1d241d 242f24 2e3d2f 3e4e3e 839583 fafffa acbdac 7c8d7c
f2f5f2 ffffff e8eee9 d8dfd8 738473 101f11 516551 7a8a7a 1d241d 242f24 2e3d2f 3d4e3e 839583 fafffa acbdac 7c8d7d
f2f5f2 ffffff e8eee9 d8dfd8 728473 0f1f11 506552 7a8a7b 1c241d 242f24 2e3d2f 3d4e3e 829584 fafffa acbdad 7c8d7d
f2f5f2 ffffff e8eee9 d8e0d8 728474 0f1f11 506552 798a7b 1c241d 232f25 2e3d2f 3d4e3f 829584 fafffa abbdad 7c8d7d
f2f5f2 ffffff e8eee9 d7e0d8 728474 0f1f12 4f6553 798b7b 1c241d 232f25 2d3d30 3c4e3f 829584 fafffa abbdad 7b8e7e
f2f5f2 ffffff e8eee9 d7e0d9 718474 0e1f12 4f6553 798b7c 1c241d 232f25 2d3d30 3c4e3f 819585 fafffa abbeae 7b8e7e
f2f5f2 ffffff e8eee9 d7e0d9 718475 0e1f12 4f6553 798b7c 1c241e 232f25 2d3d30 3c4f40 819585 fafffb aabeae 7b8e7e
f2f5f2 ffffff e8eee9 d7e0d9 718475 0d1f13 4e6554 788b7c 1c241e 232f25 2d3d30 3b4f40 819585 fafffb aabeae 7a8e7f
f2f5f2 ffffff e8eee9 d7e0d9 708475 0d1f13 4e6554 788b7d 1c241e 222f26 2c3d31 3b4f40 809586 fafffb aabeaf 7a8e7f
f2f5f3 ffffff e8eee9 d7e0d9 708476 0d1f13 4e6555 788b7d 1b241e 222f26 2c3d31 3b4f41 809586 fafffb aabeaf 7a8e7f
f2f5f3 ffffff e8eee9 d7e0d9 708476 0c2014 4d6555 778b7d 1b241e 222f26 2c3d31 3a4f41 809586 fafffb a9beaf 798e80
f1f5f3 ffffff e8eee9 d7e0d9 6f8476 0c1f14 4d6555 778b7e 1b241e 222f26 2b3d32 3a4f41 809587 f9fffb a9beb0 798e80
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b1f14 4d6556 778b7e 1b241e 222f27 2b3d32 3a4f42 7f9587 f9fffb a9beb0 798e80
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b2014 4c6556 778b7e 1b241f 212f27 2b3d32 394f42 7f9587 f9fffb a9beb0 798e81
f1f5f3 ffffff e7eeea d6e0da 6f8477 0b2015 4c6557 768b7f 1b241f 212f27 2b3d32 394f42 7f9588 f9fffb a8beb1 788e81
f1f5f3 ffffff e7eeea d6e0da 6e8478 0a2015 4b6657 768b7f 1b241f 212f27 2a3d33 394f43 7e9588 f9fffc a8beb1 788e81
f1f5f3 ffffff e7eeea d6e0da 6e8478 0a2015 4b6657 768b7f 1b241f 212f27 2a3d33 394f43 7e9588 f9fffc a8beb2 788e82
f1f5f3 ffffff e7eeea d6e0da 6e8578 0a2016 4b6658 768b80 1b241f 212f28 2a3d33 384f43 7e9589 f9fffc a7beb2 788e82
f1f5f3 ffffff e7eeea d6e0da 6e8579 092016 4a6658 758b80 1a241f 202f28 2a3d34 384f44 7e9689 f9fffc a7beb2 778e82
f1f5f3 ffffff e7eeea d6e0db 6d8579 092016 4a6659 758b80 1a241f 202f28 293d34 384f44 7d968a f9fffc a7beb3 778e83
f1f5f3 ffffff e7eeea d6e0db 6d8579 092017 4a6659 758b81 1a2420 202f28 293d34 384f44 7d968a f9fffc a7beb3 778e83
f1f5f3 ffffff e7eeeb d6e0db 6d857a 082017 4a6659 758b81 1a2420 202f29 293d35 374f45 7d968a f9fffc a7beb3 778e83
f1f5f3 ffffff e7eeeb d5e0db 6d857a 082017 49665a 748b81 1a2420 202f29 293d35 374f45 7d968b f9fffc a6beb4 768e84
f1f5f3 ffffff e7eeeb d5e0db 6c857b 082018 49665a 748b82 1a2420 202f29 293d35 374f45 7c968b f9fffc a6beb4 768e84
f1f5f4 ffffff e7eeeb d5e0db 6c857b 072018 49665b 748b82 1a2420 1f2f29 283d35 364f46 7c968b f9fffc a6beb4 768e85
f1f5f4 ffffff e7eeeb d5e0dc 6c857b 072018 48665b 748b82 1a2420 1f2f29 283d36 364f46 7c968c f9fffd a6beb5 768e85
f1f5f4 ffffff e7eeeb d5e0dc 6c857c 072019 48665b 748b83 1a2420 1f2f2a 283d36 364f46 7c968c f9fffd a5beb5 758e85
f1f5f4 ffffff e7eeeb d5e0dc 6c857c 062019 48665c 738b83 192421 1f2f2a 283d36 364f47 7b968d f9fffd a5beb5 758e86
f1f5f4 ffffff e6eeeb d5e0dc 6b857c 062019 48665c 738b83 192421 1f2f2a 283d37 364f47 7b968d f9fffd a5beb6 758e86
f1f5f4 ffffff e6eeeb d5e0dc 6b857d 062019 47665d 738b84 192421 1f2f2a 273d37 354f48 7b968d f9fffd a5beb6 758e86
f1f5f4 ffffff e6eeeb d5e0dc 6b857d 06201a 47665d 738b84 192421 1f2f2b 273d37 354f48 7b968e f9fffd a5beb7 758e87
f1f5f4 ffffff e6eeec d5e0dd 6b857d 05201a 47665e 738b84 192421 1e2f2b 273d38 354f48 7b968e f9fffd a5beb7 748e87
f1f5f4 ffffff e6eeec d5e0dd 6b857e 05201a 47665e 738b85 192421 1e2f2b 273d38 354f49 7a968e f9fffd a4beb7 748e87
f1f5f4 ffffff e6eeec d5e0dd 6a857e 05201b 46665e 728b85 192422 1e2f2b 273d38 354f49 7a968f f9fffd a4beb8 748e88
f1f5f4 ffffff e6eeec d4e0dd 6a857e 05201b 46665f 728b85 192422 1e2f2b 263d38 344f49 7a968f f9fffd a4beb8 748e88
f1f5f4 ffffff e6eeec d4e0dd 6a857f 05201b 46665f 728b86 192422 1e2f2c 263d39 344f4a 7a9690 f9fffd a4beb8 748e88
f1f5f4 ffffff e6eeec d4e0dd 6a857f 04201c 466660 728b86 192422 1e2f2c 263d39 344f4a 7a9690 f9fffe a4beb9 748e89
f1f5f4 ffffff e6eeec d4e0de 6a8580 04201c 466660 728b86 192422 1e2f2c 263d39 344f4a 7a9690 f9fffe a4beb9 738e89
f1f5f4 ffffff e6eeec d4e0de 6a8580 04201c 456660 728b87 192422 1e2f2c 263d3a 344f4b 7a9691 f9fffe a3beb9 738e8a
f0f5f5 ffffff e6eeec d4e0de 6a8580 04201d 456661 728b87 192422 1e2f2d 263d3a 344f4b 799691 f8fffe a3beba 738e8a
f0f5f5 ffffff e6eeed d4e0de 698581 04201d 456661 718b87 192423 1d2f2d 263d3a 334f4b 799691 f8fffe a3beba 738e8a
f0f5f5 ffffff e6eeed d4e0de 698581 03201d 456662 718b88 182423 1d2f2d 263d3a 334f4c 799692 f8fffe a3beba 738e8b
f0f5f5 ffffff e6eeed d4e0de 698581 03201d 456662 718b88 182423 1d2f2d 253d3b 334f4c 799692 f8fffe a3bebb 738e8b
f0f5f5 ffffff e6eeed d4e0de 698582 03201e 456662 718b88 182423 1d2f2d 253d3b 334f4c 799692 f8fffe a3bebb 738e8b
f0f5f5 ffffff e6eeed d4e0df 698582 03201e 456663 718b89 182423 1d2f2e 253d3b 334f4d 799693 f8fffe a3bebc 738e8c
f0f5f5 ffffff e6eeed d4e0df 698582 03201e 446663 718b89 182423 1d2f2e 253d3c 334f4d 799693 f8fffe a3bebc 738e8c
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b89 182423 1d2f2e 253d3c 334f4d 799694 f8fffe a3bebc 738e8c
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b8a 182424 1d2f2e 253d3c 334f4e 799694 f8ffff a3bebd 728e8d
f0f5f5 ffffff e6eeed d4e0df 698583 03201f 446664 718b8a 182424 1d2f2f 253d3c 334f4e 789694 f8ffff a2bebd 728e8d
f0f5f5 ffffff e6eeee d4e0df 698584 03201f 446665 718b8a 182424 1d2f2f 253d3d 334f4e 789695 f8ffff a2bebd 728e8d
f0f5f5 ffffff e6eeee d4e0e0 698584 021f1f 446665 718b8b 182424 1d2f2f 253d3d 324f4f 789695 f8ffff a2bebe 728e8e
f0f5f5 ffffff e6eeee d4e0e0 688584 021f20 446666 718b8b 182424 1d2f2f 253d3d 324f4f 789595 f8ffff a2bebe 728e8e
f0f5f5 ffffff e6eeee d4e0e0 688485 021f20 446666 718b8b 182424 1d2f2f 253d3e 324f4f 789596 f8ffff a2bebe 728e8e
f0f5f5 ffffff e6eeee d4e0e0 688485 021f20 446566 718b8c 182424 1d2f30 253d3e 324f50 789596 f8ffff a2bebf 728e8f
f0f5f6 ffffff e6eeee d4e0e0 688485 021f21 446567 718b8c 182425 1d2f30 253d3e 324f50 789596 f9ffff a2bebf 728e8f
f0f5f6 ffffff e6eeee d4e0e0 688486 021f21 446567 708b8c 182425 1d2f30 253d3e 324f50 789597 f9ffff a2bebf 728e8f
f0f5f6 ffffff e6eeee d4e0e0 688486 031f21 446567 708b8d 182425 1d2f30 253d3f 324f51 789597 f9ffff a2bec0 728e90
f0f5f6 ffffff e6eeee d4e0e1 688486 031f22 446568 708b8d 182425 1d2f30 253d3f 324f51 789597 f9ffff a2bec0 728e90
f0f5f6 ffffff e6eeee d4e0e1 688487 031f22 446568 708b8d 182425 1d2f31 253d3f 324f51 789598 f9ffff a2bec0 728e90
f0f5f6 ffffff e6eeef d4e0e1 688487 031f22 446569 718b8d 182425 1d2f31 253d3f 324f52 789598 f9feff a2bec1 728e91
f0f5f6 ffffff e6eeef d4e0e1 688487 031f22 446569 718b8e 182425 1d2f31 253d40 324f52 789598 fafeff a2bec1 728e91
f0f5f6 ffffff e6eeef d4e0e1 688488 031f23 446569 718b8e 182426 1d2f31 253d40 324f52 789599 fafeff a2bec1 728e91
f0f5f6 ffffff e6eeef d4e0e1 688488 031f23 44656a 718b8e 182426 1d2f31 253d40 324e52 789599 fafeff a2bec2 728e92
f0f5f6 ffffff e6eeef d4e0e1 698488 031f23 44656a 718b8f 182426 1d2f32 253d40 334e53 789599 fafeff a2bec2 728e92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f23 44656a 718b8f 182426 1d2f32 253d41 334e53 78959a fafeff a2bec2 728e92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a8f 182426 1d2f32 253d41 334e53 78959a fafeff a2bdc2 728d92
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a8f 182426 1d2f32 253d41 334e54 79959a fafeff a3bdc3 728d93
f0f5f6 ffffff e6eeef d4e0e2 698489 031f24 44656b 718a90 182426 1d2f32 253d41 334e54 79959b fafeff a3bdc3 738d93
f0f5f6 ffffff e6eeef d4dfe2 69848a 031f24 45656c 718a90 182426 1d2f32 253c42 334e54 79959b fafeff a3bdc3 738d93
f0f5f6 ffffff e6eeef d4dfe2 69848a 031f25 45646c 718a90 182427 1d2f33 253c42 334e54 79949b fafeff a3bdc4 738d94
f0f5f6 ffffff e6eef0 d4dfe2 69838a 041f25 45646c 718a91 182427 1d2e33 253c42 334e55 79949b fafeff a3bdc4 738d94
f0f5f7 ffffff e6eef0 d4dfe3 69838b 041f25 45646d 718a91 182427 1d2e33 263c42 334e55 79949c fbfeff a3bdc4 738d94
f0f5f7 ffffff e6eef0 d4dfe3 69838b 041f25 45646d 718a91 192427 1d2e33 263c42 334e55 79949c fbfeff a3bdc4 738d94
f0f5f7 ffffff e6edf0 d4dfe3 69838b 041f25 45646d 718a91 192427 1e2e33 263c43 344e55 79949c fbfeff a3bdc5 738d95
f0f5f7 ffffff e6edf0 d4dfe3 6a838b 041e26 45646d 728a92 192427 1e2e33 263c43 344e56 79949d fbfeff a3bdc5 738d95
f0f5f7 ffffff e6edf0 d4dfe3 6a838c 041e26 46646e 728a92 192427 1e2e34 263c43 344e56 7a949d fbfeff a3bdc5 738d95
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646e 728a92 192427 1e2e34 263c43 344e56 7a949d fbfeff a4bdc6 738d95
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646e 728a92 192427 1e2e34 263c44 344d56 7a949d fbfeff a4bdc6 748d96
f1f5f7 ffffff e6edf0 d4dfe3 6a838c 051e26 46646f 728a93 192428 1e2e34 263c44 344d57 7a949e fbfeff a4bcc6 748c96
f1f5f7 ffffff e6edf0 d4dfe3 6a838d 051e27 46646f 728993 192328 1e2e34 273c44 344d57 7a949e fbfeff a4bcc6 748c96
f1f5f7 ffffff e6edf0 d4dfe4 6a838d 061e27 47636f 728993 192328 1e2e34 273c44 354d57 7a949e fbfeff a4bcc6 748c96
f1f5f7 ffffff e6edf0 d5dfe4 6b838d 061e27 47636f 728993 192328 1e2e34 273c44 354d57 7a949e fbfeff a4bcc7 748c97
f1f5f7 ffffff e6edf1 d5dfe4 6b838d 061e27 476370 738993 192328 1f2e35 273c44 354d58 7b939f fbfeff a4bcc7 748c97
f1f5f7 ffffff e6edf1 d5dfe4 6b828d 061e27 476370 738994 192328 1f2e35 273b45 354d58 7b939f fbfeff a5bcc7 758c97
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 476370 738994 192328 1f2e35 273b45 354d58 7b939f fbfeff a5bcc7 758c97
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 486370 738994 192328 1f2e35 283b45 364d58 7b939f fbfeff a5bcc8 758c98
f1f5f7 ffffff e6edf1 d5dfe4 6b828e 071e28 486371 738994 1a2328 1f2e35 283b45 364d58 7b93a0 fbfeff a5bcc8 758c98
f1f5f7 ffffff e6edf1 d5dfe4 6c828e 071d28 486371 748994 1a2328 1f2e35 283b45 364d59 7c93a0 fbfeff a5bcc8 758c98
f1f5f7 ffffff e7edf1 d5dfe4 6c828f 081d28 496371 748995 1a2328 1f2e35 283b45 364c59 7c93a0 fbfeff a6bcc8 768c98
f1f5f7 ffffff e7edf1 d5dfe4 6c828f 081d28 496271 748995 1a2329 202d36 283b46 374c59 7c93a0 fcfeff a6bbc8 768b98
f1f5f7 ffffff e7edf1 d5dfe5 6c828f 081d29 496272 748995 1a2329 202d36 293b46 374c59 7c93a0 fcfeff a6bbc9 768b99
f1f5f7 ffffff e7edf1 d5dfe5 6d828f 091d29 496272 748895 1a2329 202d36 293b46 374c59 7d93a1 fcfeff a6bbc9 768b99
f1f5f7 ffffff e7edf1 d5dfe5 6d828f 091d29 4a6272 758895 1a2329 202d36 293b46 374c59 7d92a1 fcfeff a6bbc9 768b99
f1f5f7 ffffff e7edf1 d6dee5 6d818f 091d29 4a6272 758896 1a2329 202d36 293b46 384c5a 7d92a1 fcfeff a7bbc9 778b99
f1f5f8 ffffff e7edf1 d6dee5 6d8190 0a1d29 4a6272 758896 1a2329 202d36 2a3b46 384c5a 7d92a1 fcfeff a7bbc9 778b99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0a1d29 4b6273 758896 1a2329 212d36 2a3a46 384c5a 7e92a1 fcfeff a7bbca 778b99
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0a1d29 4b6273 768896 1b2329 212d36 2a3a47 384c5a 7e92a1 fcfeff a7bbca 778b9a
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0b1d29 4b6273 768896 1b2329 212d36 2a3a47 394c5a 7e92a2 fcfeff a8bbca 788b9a
f1f5f8 ffffff e7edf1 d6dee5 6e8190 0b1d2a 4c6173 768896 1b2329 212d36 2b3a47 394b5a 7e92a2 fcfeff a8bbca 788b9a
f1f5f8 ffffff e7edf1 d6dee5 6f8190 0b1c2a 4c6173 768896 1b2329 212d37 2b3a47 394b5a 7f92a2 fcfeff a8baca 788a9a
f1f5f8 ffffff e7edf2 d6dee5 6f8190 0c1c2a 4c6173 768797 1b2329 212d37 2b3a47 3a4b5b 7f92a2 fcfeff a8baca 788a9a
f1f5f8 ffffff e7edf2 d6dee5 6f8191 0c1c2a 4d6173 778797 1b2329 222d37 2b3a47 3a4b5b 7f91a2 fcfeff a9baca 798a9a
f1f5f8 ffffff e7edf2 d6dee5 6f8091 0d1c2a 4d6174 778797 1b2329 222d37 2c3a47 3a4b5b 7f91a2 fcfeff a9bacb 798a9a
f1f5f8 ffffff e8edf2 d7dee5 708091 0d1c2a 4d6174 778797 1b2229 222d37 2c3a47 3a4b5b 8091a2 fcfdff a9bacb 798a9a
f2f5f8 ffffff e8edf2 d7dee5 708091 0d1c2a 4e6174 788797 1b2229 222c37 2c3a47 3b4b5b 8091a2 fcfdff a9bacb 7a8a9b
f2f5f8 ffffff e8edf2 d7dee6 708091 0e1c2a 4e6074 788797 1c222a 222c37 2c3a48 3b4b5b 8091a3 fcfdff aabacb 7a8a9b
f2f5f8 ffffff e8ecf2 d7dee6 718091 0e1c2a 4e6074 788797 1c222a 232c37 2d3948 3b4b5b 8191a3 fcfdff aabacb 7a8a9b
f2f5f8 ffffff e8ecf2 d7dee6 718091 0e1c2a 4f6074 788797 1c222a 232c37 2d3948 3c4a5b 8191a3 fcfdff aabacb 7a8a9b
f2f5f8 ffffff e8ecf2 d7dee6 718091 0f1c2b 4f6074 798797 1c222a 232c37 2d3948 3c4a5b 8191a3 fcfdff abb9cb 7b899b
f2f4f8 ffffff e8ecf2 d7dee6 718091 0f1b2b 4f6074 798797 1c222a 232c37 2d3948 3c4a5b 8290a3 fcfdff abb9cb 7b899b
f2f4f8 ffffff e8ecf2 d7dee6 728092 0f1b2b 506074 798698 1c222a 232c37 2e3948 3d4a5c 8290a3 fcfdff abb9cb 7b899b
f2f4f8 ffffff e8ecf2 d8dee6 727f92 101b2b 506075 7a8698 1c222a 242c37 2e3948 3d4a5c 8290a3 fcfdff abb9cb 7c899b
f2f4f8 ffffff e8ecf2 d8dee6 727f92 101b2b 516075 7a8698 1d222a 242c37 2e3948 3d4a5c 8390a3 fcfdff acb9cb 7c899b
f2f4f8 ffffff e8ecf2 d8dde6 737f92 101b2b 515f75 7a8698 1d222a 242c37 2e3948 3e4a5c 8390a3 fcfdff acb9cc 7c899b
f2f4f8 ffffff e8ecf2 d8dde6 737f92 111b2b 515f75 7a8698 1d222a 242c37 2f3948 3e4a5c 8390a3 fcfdff acb9cc 7d899b
f2f4f8 ffffff e9ecf2 d8dde6 737f92 111b2b 525f75 7b8698 1d222a 242c37 2f3948 3e4a5c 8390a3 fcfdff adb9cc 7d899b
f2f4f8 ffffff e9ecf2 d8dde6 747f92 111b2b 525f75 7b8698 1d222a 252c37 2f3948 3f495c 8490a3 fcfdff adb8cc 7d889b
f2f4f8 ffffff e9ecf2 d8dde6 747f92 121b2b 535f75 7b8698 1d222a 252c37 303848 3f495c 848fa3 fcfdff adb8cc 7e889c
f2f4f8 ffffff e9ecf2 d8dde6 747f92 121b2b 535f75 7c8598 1d222a 252b37 303848 3f495c 858fa4 fcfdff aeb8cc 7e889c
f2f4f8 ffffff e9ecf2 d9dde6 757e92 121a2b 535f75 7c8598 1e222a 252b37 303848 40495c 858fa4 fcfdff aeb8cc 7e889c
f2f4f8 ffffff e9ecf2 d9dde6 757e92 131a2b 545e75 7c8598 1e222a 252b38 303848 40495c 858fa4 fcfdff aeb8cc 7f889c
f2f4f8 ffffff e9ecf2 d9dde6 757e92 131a2b 545e75 7d8598 1e222a 262b38 313848 40495c 868fa4 fdfdff afb8cc 7f889c
f3f4f8 ffffff e9ecf2 d9dde6 767e92 131a2b 555e75 7d8598 1e222a 262b38 313848 41495c 868fa4 fdfdff afb8cc 7f889c
f3f4f8 ffffff e9ecf2 d9dde6 767e92 141a2b 555e75 7d8598 1e212a 262b38 313848 41495c 868fa4 fdfdff afb8cc 80889c
f3f4f8 ffffff e9ecf2 d9dde6 767e92 141a2b 555e75 7e8598 1e212a 262b38 323848 41495c 878fa4 fdfdff b0b7cc 80889c
f3f4f8 ffffff eaecf2 d9dde6 777e92 141a2b 565e75 7e8598 1e212a 272b38 323848 42485c 878ea4 fdfdff b0b7cc 80879c
f3f4f8 ffffff eaecf2 dadde6 777e92 151a2b 565e75 7e8598 1f212a 272b37 323848 42485c 878ea4 fdfdff b0b7cc 81879c
f3f4f8 ffffff eaecf2 dadde6 777e92 151a2b 575d75 7e8498 1f212a 272b37 333748 42485c 888ea4 fdfdff b1b7cc 81879c
f3f4f8 ffffff eaecf2 dadde6 787d92 151a2b 575d75 7f8498 1f212a 272b37 333748 43485c 888ea3 fdfdff b1b7cc 81879c
f3f4f8 ffffff eaecf2 dadde6 787d92 16192b 575d75 7f8498 1f212a 272b37 333748 43485c 888ea3 fdfdff b1b7cc 82879c
f3f4f8 ffffff eaecf2 dadde6 787d92 16192b 585d75 7f8498 1f212a 282b37 333748 43485c 898ea3 fdfdff b2b7cc 82879b
f3f4f8 ffffff eaecf2 dadce6 797d92 16192b 585d75 808498 1f212a 282a37 343748 44485c 898ea3 fdfdff b2b7cc 82879b
f3f4f8 ffffff eaecf2 dbdce6 797d92 17192b 595d75 808498 1f212a 282a37 343748 44485c 898ea3 fdfdff b2b6cc 83879b
f3f4f8 ffffff eaebf2 dbdce6 797d92 17192b 595d75 808498 20212a 282a37 343748 44475c 8a8da3 fdfdff b3b6cb 83869b
f3f4f8 ffffff eaebf2 dbdce6 7a7d92 17192b 595d75 818498 20212a 292a37 353748 45475c 8a8da3 fdfdff b3b6cb 83869b
f3f4f8 ffffff ebebf2 dbdce6 7a7d92 18192b 5a5c75 818498 20212a 292a37 353748 45475c 8b8da3 fdfdff b3b6cb 84869b
f3f4f8 ffffff ebebf2 dbdce6 7a7c91 18192b 5a5c74 818397 20212a 292a37 353748 45475b 8b8da3 fdfdff b4b6cb 84869b
f3f4f8 ffffff ebebf2 dbdce6 7b7c91 18192b 5b5c74 828397 20212a 292a37 353648 46475b 8b8da3 fdfdff b4b6cb 84869b
f4f4f8 ffffff ebebf2 dbdce6 7b7c91 18192a 5b5c74 828397 20212a 292a37 363648 46475b 8c8da3 fdfdff b4b6cb 85869b
f4f4f8 ffffff ebebf2 dcdce6 7b7c91 19182a 5b5c74 828397 20212a 2a2a37 363648 46475b 8c8da3 fdfdff b5b6cb 85869b
f4f4f8 ffffff ebebf2 dcdce6 7c7c91 19182a 5c5c74 838397 21212a 2a2a37 363648 47475b 8c8da3 fdfdff b5b5cb 85869b
f4f4f8 ffffff ebebf2 dcdce6 7c7c91 19182a 5c5c74 838397 212129 2a2a37 373647 47475b 8d8ca3 fdfdff b6b5cb 86859b
f4f4f8 ffffff ebebf2 dcdce5 7c7c91 1a182a 5d5b74 838397 212129 2a2a37 373647 47465b 8d8ca2 fdfdff b6b5cb 86859b
f4f4f8 ffffff ebebf2 dcdce5 7d7c91 1a182a 5d5b74 848397 212029 2a2a37 373647 48465b 8d8ca2 fdfdff b6b5cb 86859a
f4f4f8 ffffff ebebf2 dcdce5 7d7b91 1a182a 5d5b73 848397 212029 2b2a37 373647 48465b 8e8ca2 fdfdff b7b5ca 87859a
f4f4f8 ffffff ecebf2 dddce5 7e7b91 1b182a 5e5b73 848297 212029 2b2937 383647 48465b 8e8ca2 fdfdff b7b5ca 87859a
f4f4f8 ffffff ecebf2 dddce5 7e7b90 1b182a 5e5b73 858296 212029 2b2937 383647 49465a 8e8ca2 fdfdff b7b5ca 87859a
f4f4f8 ffffff ecebf1 dddce5 7e7b90 1b182a 5f5b73 858296 222029 2b2936 383547 49465a 8f8ca2 fdfdff b8b5ca 88859a
f4f4f8 ffffff ecebf1 dddce5 7f7b90 1b1829 5f5b73 858296 222029 2c2936 393547 49465a 8f8ca2 fdfdff b8b5ca 88859a
f4f4f8 ffffff ecebf1 dddce5 7f7b90 1c1729 5f5b73 868296 222029 2c2936 393547 4a465a 908ba1 fdfdff b8b4ca 88859a
f4f4f8 ffffff ecebf1 dddbe5 7f7b90 1c1729 605a73 868296 222029 2c2936 393547 4a465a 908ba1 fdfdff b9b4ca 898499
f4f4f8 ffffff ecebf1 dddbe5 807b90 1c1729 605a72 868296 222029 2c2936 393546 4a455a 908ba1 fdfdff b9b4c9 898499
f4f3f8 ffffff ecebf1 dedbe5 807b8f 1c1729 605a72 878296 222029 2c2936 3a3546 4b455a 918ba1 fdfdff b9b4c9 898499
f5f3f7 ffffff ecebf1 dedbe5 807a8f 1d1729 615a72 878295 222029 2d2936 3a3546 4b4559 918ba1 fdfdff bab4c9 8a8499
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1729 615a72 878195 232029 2d2936 3a3546 4b4559 918ba1 fdfdff bab4c9 8a8499
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1729 625a72 888195 232029 2d2936 3a3546 4c4559 928ba0 fefdff bab4c9 8a8499
f5f3f7 ffffff edebf1 dedbe5 817a8f 1d1728 625a71 888195 232029 2d2936 3b3546 4c4559 928ba0 fefdff bbb4c9 8b8498
f5f3f7 ffffff edebf1 dedbe4 827a8f 1e1728 625a71 888195 232028 2d2935 3b3546 4c4559 928ba0 fefdff bbb4c8 8b8498
f5f3f7 ffffff edebf1 dfdbe4 827a8e 1e1728 635971 898195 232028 2e2935 3b3545 4d4559 938aa0 fefdff bbb3c8 8b8498
f5f3f7 ffffff edebf1 dfdbe4 827a8e 1e1728 635971 898194 232028 2e2835 3b3445 4d4558 938aa0 fefdff bcb3c8 8c8398
f5f3f7 ffffff edebf1 dfdbe4 837a8e 1e1728 635970 898194 232028 2e2835 3c3445 4d4558 938a9f fefdff bcb3c8 8c8398
f5f3f7 ffffff edebf1 dfdbe4 837a8e 1f1628 645970 898194 242028 2e2835 3c3445 4e4458 948a9f fefdff bcb3c8 8c8397
f5f3f7 ffffff edeaf1 dfdbe4 837a8e 1f1627 645970 8a8194 242028 2e2835 3c3445 4e4458 948a9f fefdff bdb3c7 8d8397
f5f3f7 ffffff edeaf1 dfdbe4 83798d 1f1627 655970 8a8194 242028 2f2835 3d3445 4e4458 948a9f fefdff bdb3c7 8d8397
f5f3f7 ffffff eeeaf0 dfdbe4 84798d 1f1627 65596f 8a8093 242028 2f2835 3d3444 4e4457 958a9e fefdff bdb3c7 8d8397
f5f3f7 ffffff eeeaf0 e0dbe4 84798d 201627 65596f 8b8093 241f28 2f2834 3d3444 4f4457 958a9e fefdff beb3c7 8e8397
f5f3f7 ffffff eeeaf0 e0dbe4 84798d 201627 66596f 8b8093 241f28 2f2834 3d3444 4f4457 958a9e fefdff beb3c6 8e8396
f5f3f7 ffffff eeeaf0 e0dbe3 85798c 201626 66586f 8b8093 241f28 2f2834 3d3444 4f4457 968a9e fefdff beb3c6 8e8396
f5f3f7 ffffff eeeaf0 e0dbe3 85798c 201626 66586e 8c8092 241f27 302834 3e3444 504456 96899d fefdff bfb2c6 8f8396
f6f3f7 ffffff eeeaf0 e0dbe3 85798c 211626 67586e 8c8092 251f27 302834 3e3443 504456 96899d fefdff bfb2c6 8f8396
f6f3f7 ffffff eeeaf0 e0dbe3 86798c 211626 67586e 8c8092 251f27 302834 3e3443 504456 97899d fefdff bfb2c5 8f8295
f6f3f7 ffffff eeeaf0 e0dbe3 86798b 211626 67586e 8c8092 251f27 302833 3e3343 504456 97899d fefdff c0b2c5 908295
f6f3f7 ffffff eeeaf0 e1dae3 86798b 211625 68586d 8d8091 251f27 302833 3f3343 514355 97899c fefdff c0b2c5 908295
f6f3f7 ffffff eeeaf0 e1dae3 86798b 211525 68586d 8d8091 251f27 302833 3f3343 514355 98899c fefdff c0b2c5 908295
f6f3f7 ffffff efeaf0 e1dae3 87788b 221525 68586d 8d8091 251f27 312833 3f3342 514355 98899c fefdff c0b2c4 908294
f6f3f7 ffffff efeaf0 e1dae2 87788a 221525 69586c 8e8091 251f27 312833 3f3342 514355 98899c fffcff c1b2c4 918294
f6f3f6 ffffff efeaf0 e1dae2 87788a 221525 69586c 8e7f90 251f27 312833 403342 524354 98899b fffcff c1b2c4 918294
f6f3f6 ffffff efeaef e1dae2 88788a 221524 69576c 8e7f90 261f26 312732 403342 524354 99899b fffcff c1b2c3 918293
f6f3f6 ffffff efeaef e1dae2 88788a 231524 69576b 8e7f90 261f26 312732 403341 524354 99899b fffcff c2b2c3 928293
f6f3f6 ffffff efeaef e2dae2 887889 231524 6a576b 8f7f90 261f26 312732 403341 524354 99889a fffcff c2b2c3 928293
f6f3f6 ffffff efeaef e2dae2 887889 231524 6a576b 8f7f8f 261f26 322732 403341 534353 9a889a fffcff c2b2c3 928293
f6f3f6 ffffff efeaef e2dae2 897889 231523 6a576a 8f7f8f 261f26 322732 413341 534353 9a889a fffcff c2b1c2 928292
f6f3f6 ffffff efeaef e2dae2 897888 231523 6b576a 8f7f8f 261f26 322732 413340 534353 9a889a fffcff c3b1c2 938192
f6f3f6 ffffff efeaef e2dae1 897888 241523 6b576a 907f8f 261f26 322731 413340 534353 9a8899 fffcff c3b1c2 938192
f6f3f6 ffffff efeaef e2dae1 897888 241523 6b5769 907f8e 261f26 322731 413340 544352 9b8899 fffcff c3b1c1 938191
f6f3f6 ffffff efeaef e2dae1 8a7887 241522 6b5769 907f8e 261f25 322731 413340 544252 9b8899 fffcff c3b1c1 938191
f6f3f6 ffffff f0eaef e2dae1 8a7887 241522 6c5769 907f8e 271f25 322731 42333f 544252 9b8898 fffcff c4b1c1 948191
f7f3f6 ffffff f0eaef e2dae1 8a7887 241522 6c5768 917f8d 271f25 332731 42333f 544251 9b8898 fffcfe c4b1c0 948190
f7f3f6 ffffff f0eaee e3dae1 8a7787 241522 6c5768 917f8d 271f25 332730 42323f 554251 9c8898 fffcfe c4b1c0 948190
f7f3f6 ffffff f0eaee e3dae1 8b7786 251421 6d5668 917f8d 271f25 332730 42323f 554251 9c8897 fffcfe c4b1c0 948190
f7f3f6 ffffff f0eaee e3dae0 8b7786 251421 6d5667 917f8c 271f25 332730 42323e 554250 9c8897 fffcfe c5b1bf 958190
f7f3f6 ffffff f0eaee e3dae0 8b7786 251421 6d5667 917f8c 271f25 332730 43323e 554250 9c8897 fffcfe c5b1bf 95818f
f7f3f6 ffffff f0eaee e3dae0 8b7785 251421 6d5667 927f8c 271f25 332730 43323e 554250 9d8896 fffcfe c5b1bf 95818f
f7f3f5 ffffff f0eaee e3dae0 8c7785 251420 6e5666 927e8c 271f24 33272f 43323e 56424f 9d8896 fffcfe c5b1bf 95818f
f7f3f5 ffffff f0eaee e3dae0 8c7785 251420 6e5666 927e8b 271f24 34272f 43323d 56424f 9d8896 fffcfe c6b1be 95818e
f7f3f5 ffffff f0eaee e3dae0 8c7784 261420 6e5665 927e8b 271f24 34272f 43323d 56424f 9d8895 fffcfe c6b1be 96818e
f7f3f5 ffffff f0eaee e3dae0 8c7784 261420 6e5665 927e8b 271f24 34272f 43323d 56424f 9e8795 fffcfe c6b1bd 96818e
f7f3f5 ffffff f0eaee e4dadf 8c7784 26141f 6e5665 937e8a 281f24 34272f 44323d 56424e 9e8795 fffcfe c6b1bd 96818d
f7f3f5 ffffff f0eaed e4dadf 8d7783 26141f 6f5664 937e8a 281f24 34272e 44323c 57424e 9e8794 fffcfe c6b1bd 96818d
f7f3f5 ffffff f1eaed e4dadf 8d7783 26141f 6f5664 937e8a 281e24 34272e 44323c 57424e 9e8794 fffcfe c7b0bc 96818d
f7f3f5 ffffff f1eaed e4dadf 8d7783 26141e 6f5663 937e89 281e23 34272e 44323c 57424d 9e8793 fffcfe c7b0bc 97818c
f7f3f5 ffffff f1eaed e4dadf 8d7782 26141e 6f5663 937e89 281e23 34272e 44323b 57424d 9f8793 fffcfe c7b0bc 97818c
f7f3f5 ffffff f1eaed e4dadf 8d7782 27141e 6f5663 947e89 281e23 34272e 44323b 57424d 9f8793 fffdfe c7b0bb 97808c
f7f3f5 ffffff f1eaed e4dade 8e7782 27141e 705662 947e88 281e23 35272d 44323b 57424c 9f8792 fffdfe c7b0bb 97808b
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705662 947e88 281e23 35272d 45323b 58424c 9f8792 fffdfe c8b0bb 97808b
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705662 947e88 281e23 35272d 45323a 58424c 9f8792 fffdfe c8b0ba 98808a
f7f3f5 ffffff f1eaed e4dade 8e7781 27141d 705661 947e87 281e23 35272d 45323a 58424b 9f8791 fffdfe c8b0ba 98808a
f7f3f5 ffffff f1eaec e4dade 8e7780 27141c 705661 947e87 281e22 35272d 45323a 58424b a08791 fffdfd c8b0ba 98808a
f7f3f4 ffffff f1eaec e5dade 8e7780 27141c 715660 957e87 281e22 35272c 453239 58424b a08791 fffdfd c8b0b9 988089
f7f3f4 ffffff f1eaec e5dadd 8e777f 27141c 715660 957e86 281e22 35262c 453239 58424a a08790 fffdfd c8b0b9 988089
f7f3f4 ffffff f1eaec e5dadd 8f777f 27141c 71565f 957e86 281e22 35262c 453239 58424a a08790 fffdfd c9b0b9 988089
f7f3f4 ffffff f1eaec e5dadd 8f777f 28141b 71565f 957e86 281e22 35262c 453239 59414a a0878f fffdfd c9b0b8 988088
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141b 71565f 957e85 291e22 35262b 453238 594149 a0878f fffdfd c9b0b8 998088
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141b 71565e 957e85 291e22 35262b 463238 594149 a1878f fffdfd c9b0b8 998088
f8f3f4 ffffff f1eaec e5dadd 8f777e 28141a 71565e 957e85 291e21 36262b 463238 594149 a1878e fffdfd c9b0b7 998087
f4f4f4 ffffff ececec dddddd 7e7e7e 1b1b1b 5e5e5e 858585 222222 2b2b2b 383838 494949 8f8f8f fdfdfd b8b8b8 888888
""")
        /// « Autre… » : plein clair, encre teintée claire, plein sombre, encre teintée sombre.
        static let primaires = lire("""
b43368 962554 f089aa ffc8d7
b43366 962553 f089a9 ffc8d6
b53364 972551 f189a7 ffc8d6
b53362 972550 f189a6 ffc8d4
b63360 97244e f289a4 ffc8d4
b6335e 98244c f289a3 ffc8d3
b6325d 98244b f289a1 ffc8d2
b7325b 982449 f389a0 ffc9d2
b73259 992447 f3899e ffc8d0
b73257 992446 f3899d ffc8d0
b83255 992444 f3899b ffc9d0
b83253 992442 f4899a ffc9cf
b83251 9a2441 f48998 ffc9ce
b9324f 9a243f f48a96 ffc9cd
b9334d 9a243d f48a95 ffc9cc
b9334b 9a243b f58a93 ffc9cc
b93349 9a2439 f58a92 ffc9cb
b93347 9a2437 f58a90 ffc9ca
b93345 9a2436 f58a8f ffc9ca
ba3343 9a2534 f58a8d ffcac9
ba3441 9a2431 f58a8b ffc9c8
ba343e 9a2530 f58b8a ffcac7
ba343c 9b252e f58b88 ffcac7
ba343a 9b252c f58b87 ffcac6
ba3538 9a2529 f58b85 ffcac5
ba3535 9a2527 f58b84 ffcac5
ba3533 9a2625 f58c82 ffcbc4
ba3630 9a2623 f58c81 ffcbc4
ba362e 9a2720 f58c7f ffcbc3
ba362b 9a271e f58c7e ffcbc2
ba3728 9a271b f58d7c ffcbc2
ba3725 9a2819 f58d7b ffcbc0
ba3822 9a2815 f58d79 ffcbc0
b9381f 9a2913 f58d77 ffcbbf
b9391b 9a290e f48e76 ffcbbe
b93917 992909 f48e74 ffcbbd
b93a13 992a04 f48e73 ffcbbc
b93a0e 992b00 f48f71 ffcbbb
b83b07 972d00 f48f70 ffcbbb
b83c00 952f00 f38f6e ffcbba
b73e00 943100 f3906d ffccba
b54000 933200 f3906c ffccb9
b44200 923400 f2916a ffccb8
b24400 903500 f29169 ffccb8
b14500 8f3700 f29167 ffccb7
af4700 8d3800 f19266 ffcdb7
ae4800 8c3900 f19264 ffcdb6
ad4a00 8c3a00 f19363 ffcdb4
ab4b00 8b3b00 f09362 ffcdb4
aa4c00 893c00 f09360 ffcdb3
a94e00 883d00 ef945f ffcdb2
a84f00 873e00 ef945d ffcdb0
a75000 863f00 ee955c ffcdb0
a65100 854000 ee955b ffceb0
a55200 844100 ed9659 ffceaf
a45300 834100 ed9658 ffceae
a25400 824200 ec9757 ffceac
a15500 814300 eb9756 ffceab
a05500 814300 eb9854 ffceaa
9f5600 7f4400 ea9853 ffcea8
9e5700 7f4400 ea9952 ffcfa8
9d5800 7d4500 e99951 ffcfa7
9c5900 7d4500 e89a50 ffcfa6
9c5900 7c4600 e79a4e ffcfa4
9b5a00 7b4700 e79b4d ffd0a4
9a5b00 7b4700 e69b4c fed0a3
995b00 794700 e59c4b fdd0a3
985c00 794800 e49c4a fdd0a2
975d00 784900 e49d49 fdd1a2
965d00 774900 e39e48 fcd1a2
955e00 764900 e29e47 fcd1a2
945e00 754a00 e19f46 fbd1a1
935f00 754a00 e09f45 fad2a1
936000 734a00 dfa045 fad2a1
926000 734b00 dfa044 f9d3a0
916100 724b00 dea143 f8d3a0
906100 724c00 dda242 f8d3a0
8f6200 714c00 dca242 f7d4a0
8e6200 704d00 dba341 f6d49f
8d6300 704d00 daa341 f6d49f
8d6300 6f4d00 d9a440 f5d59f
8c6400 6e4e00 d8a440 f4d59f
8b6400 6e4e00 d7a53f f4d59f
8a6500 6d4e00 d6a63f f3d69f
896500 6c4f00 d5a63e f2d69e
886600 6c4f00 d4a73e f2d69f
886600 6a4f00 d2a73e f0d79e
876700 694f00 d1a83e efd79e
866700 695000 d0a83e efd79e
856800 685000 cfa93e eed79e
846800 675100 ceaa3e edd89e
836800 675100 cdaa3e edd89e
826900 665100 cbab3e ecd99e
816900 655100 caab3e ebd99e
816a00 655200 c9ac3e eada9f
806a00 645200 c8ad3f e9da9f
7f6b00 635300 c6ad3f e8da9e
7e6b00 625300 c5ae40 e8db9f
7d6c00 615300 c4ae40 e7db9f
7c6c00 605300 c3af41 e6db9f
7b6c00 605400 c1af41 e5dca0
7a6d00 5f5400 c0b042 e4dca0
796d00 5e5400 bfb042 e4dca0
786e00 5d5500 bdb143 e3dda1
776e00 5d5500 bcb244 e1dda1
766f00 5b5500 bab245 e0dda1
756f00 5a5500 b9b345 e0dda1
746f00 595600 b8b346 dfdea2
737000 595600 b6b447 dedea2
727000 575600 b5b448 dddea2
707100 565700 b3b549 dcdfa3
6f7100 565700 b2b54a dbdfa3
6e7200 555700 b0b64b dae0a4
6d7200 535800 afb64c d9e0a4
6c7300 535800 adb74d d8e0a4
6a7300 515800 abb74f d7e0a4
697400 505900 aab850 d6e0a5
677400 4f5900 a8b851 d5e0a5
667500 4e5900 a7b952 d5e2a7
657500 4c5a00 a5b953 d4e2a7
637500 4b5a00 a3ba55 d2e2a8
617600 4a5a00 a2ba56 d1e2a8
607600 485a00 a0bb57 d1e3a9
5e7700 475b00 9fbb59 cfe3a9
5c7800 465b00 9dbc5a cee3aa
5a7800 445b00 9bbc5b cde3aa
587900 425c00 99bd5d cce3ab
567900 415c00 98bd5e cce4ac
547a00 3f5c00 96bd60 cae4ac
527a00 3d5d00 94be61 cae4ad
4f7b00 3b5d00 92be62 c9e4ae
4d7b00 395d00 91bf64 c8e5af
4a7c00 375e00 8fbf65 c6e5af
477d00 345e00 8dbf67 c5e5b0
437d00 315f00 8bc068 c4e5b0
407e00 2f5f00 89c06a c4e6b2
3c7f00 2b5f00 88c16b c2e6b2
377f00 285f00 86c16d c1e6b3
328000 246000 84c16e c0e6b4
2c8100 1f6000 82c270 bfe6b4
258101 196000 80c271 bee6b5
208209 126100 7ec273 bde6b6
1a8210 076100 7cc375 bce7b7
118316 006206 7ac376 bbe7b8
05831a 00610f 78c378 bae7b8
008321 006116 76c479 bae8ba
008328 00611b 74c47b b9e8bb
00832d 006120 72c47c b8e8bc
008232 006123 70c47e b6e8bc
008236 006127 6ec580 b6e8bd
00823a 00612a 6cc581 b4e8be
00823d 00612c 6ac583 b3e8bf
008240 00602e 68c584 b2e8bf
008143 006031 66c686 b1e8c0
008146 006033 64c688 b1e8c1
008148 006035 62c689 b0e8c2
00814b 006037 5fc68b afe8c3
00814d 006038 5dc68c aee8c4
00814f 00603a 5bc78e ade9c5
008051 00603c 59c790 ace9c6
008053 00603d 57c791 abe9c7
008055 00603f 54c793 aae9c8
008057 005f3f 52c794 aae9c9
008058 005f41 50c796 a9e9c9
00805a 005f42 4ec898 a9eacb
00805b 005f43 4bc899 a8eacc
007f5d 005f45 49c89b a7eacd
007f5e 005f46 46c89c a6eace
007f60 005f47 44c89e a6eacf
007f61 005f48 42c8a0 a5ead0
007f62 005f49 3fc8a1 a4ead1
007f64 005f4a 3dc8a3 a3ead2
007f65 005f4b 3ac8a4 a3ead3
007e66 005f4c 38c8a6 a2ead3
007e67 005f4d 35c8a8 a1ead4
007e68 005f4f 32c8a9 a1ead5
007e6a 005f4f 30c8ab a0ead6
007e6b 005e4f 2dc8ac a0ead7
007e6c 005e50 2ac8ae 9fead8
007e6d 005e51 27c8af 9eead9
007e6e 005e52 24c8b1 9eeada
007d6f 005e53 21c8b3 9eeadb
007d70 005e54 1ec8b4 9deadc
007d71 005e55 1ac8b6 9deadd
007d72 005e56 17c8b7 9ceade
007d73 005e56 13c8b9 9ce9df
007d74 005e57 0fc8ba 9be9df
007d75 005e58 0ac8bc 9ae9e0
007d76 005e59 04c8bd 9ae9e1
007c77 005e5a 00c8bf 9ae9e2
007c77 005e5b 00c7c0 99e8e2
007c78 005e5b 00c7c1 99e8e3
007c79 005e5b 00c7c3 98e8e4
007c7a 005d5c 00c7c4 98e8e5
007c7b 005d5d 00c7c6 98e8e6
007c7c 005d5d 00c7c7 98e8e7
007c7d 005d5e 00c6c8 98e7e8
007b7e 005d5f 00c6ca 98e7e8
007b7f 005d60 00c6cb 98e7e9
007b7f 005d61 00c6cc 98e7eb
007b80 005d61 00c6ce 98e7eb
007b81 005d62 00c5cf 97e7ec
007b82 005d63 00c5d0 97e7ed
007b83 005d64 00c5d2 97e7ee
007b84 005d64 00c5d3 98e7ef
007a85 005c64 00c5d4 98e7f0
007a85 005c65 00c4d6 98e7f1
007a86 005c66 00c4d7 99e7f2
007a87 005c67 00c4d8 99e7f3
007a88 005c68 00c4da 99e7f4
007a89 005c68 00c3db 99e6f4
007a8a 005c69 02c3dc 99e6f4
00798b 005c6a 07c3de 9ae6f6
00798c 005c6a 0cc3df 9ae6f6
00798d 005b6a 11c2e0 9ae5f7
00798d 005b6b 15c2e1 9ae5f7
00798e 005b6c 18c2e2 9ae5f8
00798f 005b6d 1cc1e3 9be5fa
007890 005b6e 1fc1e4 9ce5fa
007891 005b6f 22c1e5 9ce5fb
007892 005b70 25c0e6 9de5fc
007893 005b71 28c0e7 9de5fd
007894 005b72 2bc0e9 9ee5fe
007895 005b72 2dbfea 9fe5fe
007796 005a73 30bfeb a0e5ff
007797 005a73 33beeb a0e4ff
007798 005a75 35beec a2e4ff
007799 005a76 38beed a5e4ff
00779a 005a77 3abdee a4e3ff
00769c 005a78 3dbdef a7e3ff
00769d 005a79 3fbcf0 a9e3ff
00769e 005a7a 41bcf1 aae2ff
00769f 005a7a 44bcf2 abe2ff
0075a0 00597b 46bbf2 ade2ff
0075a2 00597c 48bbf3 afe2ff
0075a3 00597e 4abaf4 aee1ff
0074a4 00597f 4dbaf5 b0e1ff
0074a6 005980 4fb9f6 b2e1ff
0074a7 005881 51b9f6 b4e1ff
0073a9 005882 53b8f7 b3e0ff
0073aa 005884 55b8f8 b4e0ff
0073ac 005886 58b8f8 b6e0ff
0072ae 005786 5ab7f9 b7e0ff
0072af 005788 5cb7f9 b8dfff
0071b1 005789 5eb6fa badfff
0071b3 00568a 60b6fa badfff
0070b5 00568d 62b5fb bbdeff
0070b7 00568f 64b5fb bbdeff
006fb9 005590 66b4fc bcdeff
006fbb 005593 68b4fc bddeff
006ebe 005594 6ab3fd bdddff
006dc1 005497 6cb3fd beddff
006cc3 00549a 6eb2fe bfddff
006bc6 00539c 70b2fe c1ddff
006aca 00529e 71b1fe c1ddff
096acb 0052a3 73b1ff c2ddff
1369cb 0051a6 75b0ff c2dcff
1a68cb 0750a6 77b0ff c3dcff
2068cb 0f50a7 79afff c4dcff
2567cc 1550a7 7bafff c5dcff
2966cc 194fa8 7daeff c4dbff
2d66cc 1e4fa8 7faeff c5dbff
3065cc 214ea8 81adff c6dbff
3465cc 244ea9 83adff c7dbff
3764cd 274ea9 84acff c7daff
3a63cd 2a4da9 86acff c8daff
3d63cd 2d4daa 88abff c9daff
4062cd 2f4ca9 8aabff cadaff
4261cd 324ca9 8baaff c9d9ff
4561cd 344ba9 8daaff cad9ff
4760cd 364ba9 8ea9ff cbd9ff
4a5fcc 394aa9 90a9ff ccd9ff
4c5fcc 3b4aaa 92a8ff cdd9ff
4e5ecc 3d49a9 93a8ff ced9ff
505dcc 3f49a9 95a7ff ced8ff
525dcc 4149a9 96a7ff cfd8ff
555ccb 4348a9 98a6ff d0d8ff
575bcb 4548a9 99a5ff cfd7ff
595bcb 4647a9 9ba5ff d0d7ff
5a5acb 4846a8 9da4ff d1d7ff
5c5aca 4a46a9 9ea4ff d2d7ff
5e59ca 4b46a8 a0a3fe d2d6ff
6058c9 4d45a8 a1a3fe d3d6ff
6258c9 4e45a7 a3a2fd d4d6ff
6457c9 5044a7 a4a2fd d5d6ff
6556c8 5244a7 a6a1fd d5d5ff
6756c8 5343a7 a7a1fc d5d5ff
6955c7 5543a6 a9a0fc d6d5ff
6a55c6 5642a6 aaa0fb d7d4ff
6c54c6 5842a6 ac9ffb d8d4ff
6e53c5 5942a5 ad9ffa d8d4ff
6f53c5 5b41a5 ae9efa d9d4ff
7152c4 5c41a4 b09ef9 dad3ff
7252c3 5e40a3 b19df9 dad3ff
7451c2 5e3fa2 b39df8 dbd3ff
7550c2 603fa2 b49cf7 dbd2ff
7750c1 613fa2 b59cf7 dcd2ff
784fc0 633ea1 b79cf6 ded2ff
7a4fbf 643da0 b89bf5 ded1ff
7b4ebe 653d9f b99bf5 dfd2ff
7d4dbe 663d9f bb9af4 e0d1ff
7e4dbd 683c9e bc9af3 e1d0ff
7f4cbc 693c9d bd99f2 e1d0ff
814cbb 6a3b9c bf99f1 e2d0ff
824bba 6b3b9c c098f1 e3cfff
834bb9 6c3b9b c198f0 e4cfff
854ab8 6e3a9a c298ef e5ceff
864ab7 6f3a99 c497ee e6ceff
8749b6 703998 c597ed e7ceff
8848b5 713897 c696ec e8cdff
8a48b3 723896 c796eb e9cdff
8b47b2 733795 c895ea eacdff
8c47b1 743794 c995e9 ebccff
8d46b0 753793 cb95e8 ecccff
8e46af 763692 cc94e7 edcbfe
9045ae 773691 cd94e6 eecbfe
9145ac 783590 ce93e5 eecbfd
9244ab 79358f cf93e4 efcbfd
9344aa 7a348e d093e3 f0cafb
9443a9 7b348d d192e2 f0cafb
9543a7 7c348c d292e1 f1cafa
9642a6 7d338b d392e0 f2cafa
9742a5 7e3389 d491df f3c9f9
9841a3 7e3288 d591de f4c9f8
9941a2 7f3287 d691dc f4c9f8
9a40a1 803186 d790db f5c9f7
9b409f 813185 d890da f6c9f6
9c3f9e 823083 d990d9 f7c9f5
9d3f9c 833082 da8fd7 f6c8f4
9e3e9b 832f81 db8fd6 f7c8f3
9f3e99 842f80 dc8fd5 f8c8f3
a03d98 852f7e dd8ed4 f9c8f2
a13d96 862e7d de8ed2 fac8f1
a23c95 872e7c df8ed1 fac8f0
a33c93 872e7a df8dd0 fac7ef
a43c92 882d79 e08dce fbc7ee
a43b90 892d78 e18dcd fcc7ee
a53b8f 8a2c76 e28dcc fcc7ed
a63a8d 8a2c75 e38cca fdc7ec
a73a8c 8b2c74 e38cc9 fec7eb
a8398a 8c2b72 e48cc8 fec7ea
a83988 8c2b71 e58cc6 ffc6ea
a93987 8d2a6f e68cc5 ffc6e8
aa3885 8e2a6e e68bc4 ffc6e7
ab3883 8e2a6d e78bc2 ffc6e6
ab3782 8f296b e88bc1 ffc7e5
ac3780 8f296a e88bbf ffc7e4
ad377e 902968 e98bbe ffc7e3
ad367d 902866 ea8abc ffc7e2
ae367b 912865 ea8abb ffc7e1
af3679 912764 eb8ab9 ffc7e0
af3578 922862 ec8ab8 ffc7df
b03576 932761 ec8ab7 ffc7de
b03574 93275f ed8ab5 ffc8de
b13572 93265e ed8ab4 ffc8dd
b23471 94265c ee8ab2 ffc8dc
b2346f 94265a ee89b1 ffc7da
b3346d 952659 ef89af ffc7da
b3346b 952557 ef89ae ffc8d9
b4336a 962556 f089ac ffc8d8
""")
        static let prereglages = lire("""
0b5fe0 004aba 7cadff c5dbff
0e7a62 005f4c 4bcba9 a7ead4
cf365f a11642 f27f93 ffc6cd
c6481b 992d00 ea8869 ffc8b7
4c5667 3a4352 b6becc dbe0e9
""")
        private static func lire(_ texte: String) -> [[UInt32]] {
            texte.split(separator: "\n").map { $0.split(separator: " ").map { UInt32($0, radix: 16) ?? 0 } }
        }
    }
}
