import SwiftUI

/// Une consigne du panneau d'aide : une icône, un texte qui passe à la ligne,
/// en couleur quand elle presse.
private struct Consigne: View {
    let texte: String
    let icone: String
    var urgente = false
    var forte = false

    var body: some View {
        Label {
            Text(texte).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icone)
        }
        .font((forte ? Jetons.Typo.corpsFort : Jetons.Typo.petit).police)
        .foregroundStyle(urgente ? Color.jeton(\.safranTexte) : forte ? Color.jeton(\.encre) : Color.jeton(\.encreSecondaire))
    }
}

// MARK: - Kimbo

/// Le couple d'éléments qui a frappé Kimbo — lu au canal combat, ou choisi
/// ici — dit où se tenir par rapport au Disciple et dans quels éléments
/// frapper.
struct KimboVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        Text(L("boss.kimbo.question")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
        ChoixBoss(choix: [(Kimbo.Etat.impair, L("boss.kimbo.terreEau")), (.pair, L("boss.kimbo.airFeu"))],
                  actuel: aide.session.kimbo) { etat in aide.noter { session, _ in session.kimbo = etat } }
        if let etat = aide.session.kimbo {
            VStack(alignment: .leading, spacing: 0) {
                Text(etat.glyphesImpairs ? L("boss.kimbo.reste.pair") : L("boss.kimbo.reste.impair"))
                    .font(Jetons.Typo.titre.police).foregroundStyle(Color.jeton(\.primaireEncre))
                Text(etat.glyphesImpairs ? L("boss.kimbo.reste.pair.detail") : L("boss.kimbo.reste.impair.detail"))
                    .font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Consigne(texte: etat.glyphesImpairs ? L("boss.kimbo.kimbo.impair") : L("boss.kimbo.kimbo.pair"),
                     icone: "scope")
            Consigne(texte: etat.glyphesImpairs ? L("boss.kimbo.frappe.terreEau") : L("boss.kimbo.frappe.airFeu"),
                     icone: "flame")
        } else {
            Consigne(texte: L("boss.kimbo.attente"), icone: "questionmark.circle")
        }
    }
}

// MARK: - Toxoliath

/// Le compte à rebours avant Poison Volatile, la prochaine vague, et Toxmose
/// une fois le Toxoliath touché.
struct ToxoliathVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        let touche = aide.session.toxoliathTouche
        let sous: Int? = if let tour = aide.tour, let touche, Toxoliath.toxmose(toucheAu: touche, tour: tour) { touche } else { nil }
        // Les deux gestes d'abord, sur une ligne qui ne bouge pas.
        HStack(spacing: Jetons.Espace.un) {
            Button(L("boss.toxoliath.touche")) { aide.noter { session, tour in session.toxoliathTouche = tour ?? 1 } }
                .buttonStyle(.bouton(.secondaire, dense: true))
                .help(L("boss.toxoliath.touche.aide"))
                .disabled(sous != nil)
            Spacer(minLength: 0)
            PetitBouton(icone: "xmark", aide: L("boss.toxoliath.toxmose.annuler")) {
                aide.noter { session, _ in session.toxoliathTouche = nil }
            }
            .disabled(sous == nil)
        }
        if let tour = aide.tour {
            if tour < Toxoliath.premierPoisonVolatile {
                let reste = Toxoliath.premierPoisonVolatile - tour
                Consigne(texte: L("boss.toxoliath.avant", nombre: reste, reste), icone: "timer", urgente: reste <= 2, forte: true)
            } else if Toxoliath.poisonVolatile(au: tour) {
                Consigne(texte: L("boss.toxoliath.poison.maintenant"), icone: "exclamationmark.triangle.fill",
                         urgente: true, forte: true)
            } else {
                Consigne(texte: L("boss.toxoliath.poison.prochain", Toxoliath.prochainPoisonVolatile(depuis: tour)),
                         icone: "timer")
            }
            if let vague = Toxoliath.prochaineVague(apres: tour) {
                Consigne(texte: L("boss.toxoliath.vague", vague), icone: "person.3")
            }
        } else {
            Consigne(texte: L("boss.toxoliath.avantCombat"), icone: "timer")
        }
        if let sous {
            Consigne(texte: L("boss.toxoliath.toxmose", sous + Toxoliath.dureeToxmose - 1), icone: "drop.triangle", urgente: true)
        }
    }
}

// MARK: - Ilyzaelle

/// Les deux seuils de vie, ce que chaque phase demande, et « Vers les
/// ténèbres ».
struct IlyzaelleVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        let tour = aide.tour ?? 1
        let session = aide.session
        let phase = Ilyzaelle.phase(seuil75: session.ilyzaelle75, seuil50: session.ilyzaelle50, tour: tour)
        // Les gestes d'abord, sur une ligne qui ne bouge pas : le seuil attendu
        // s'allume quand une phase le demande.
        HStack(spacing: Jetons.Espace.un) {
            Button(session.ilyzaelle75 == nil ? L("boss.ilyzaelle.seuil75") : L("boss.ilyzaelle.seuil50")) {
                aide.noter { session, tour in
                    if session.ilyzaelle75 == nil { session.ilyzaelle75 = tour ?? 1 } else { session.ilyzaelle50 = tour ?? 1 }
                }
            }
            .buttonStyle(.bouton(.secondaire, dense: true))
            .disabled(phase != .premiere && phase != .seconde)
            Spacer(minLength: 0)
            PetitBouton(icone: "xmark", aide: L("boss.ilyzaelle.annuler")) {
                aide.noter { session, _ in
                    if session.ilyzaelle50 != nil { session.ilyzaelle50 = nil } else { session.ilyzaelle75 = nil }
                }
            }
            .disabled(session.ilyzaelle75 == nil)
        }
        switch phase {
        case .premiere:
            Consigne(texte: L("boss.ilyzaelle.objectif75"), icone: "target", forte: true)
        case .allieeA75(let depuis):
            Consigne(texte: L("boss.ilyzaelle.alliee75", depuis + Ilyzaelle.dureeAlliee - 1), icone: "shield.lefthalf.filled",
                     forte: true)
        case .seconde:
            Consigne(texte: L("boss.ilyzaelle.objectif50"), icone: "target", forte: true)
        case .allieeA50(let depuis):
            Consigne(texte: L("boss.ilyzaelle.alliee50", depuis + Ilyzaelle.dureeAlliee - 1), icone: "hourglass",
                     forte: true)
        case .gagnee:
            Consigne(texte: L("boss.ilyzaelle.gagnee"), icone: "checkmark.seal")
        }
        if Ilyzaelle.versLesTenebres(au: tour) {
            Consigne(texte: L("boss.ilyzaelle.tenebres.maintenant"), icone: "exclamationmark.triangle.fill", urgente: true)
        } else {
            Consigne(texte: L("boss.ilyzaelle.tenebres.prochain", Ilyzaelle.prochainVersLesTenebres(depuis: tour)),
                     icone: "arrow.down.right.and.arrow.up.left")
        }
    }
}

// MARK: - Tal Kasha

/// Les glyphes de monstres différents où Tal Kasha a commencé son tour, de I
/// à III — le jeu les montre au-dessus d'elle ; trois la rendent vulnérable.
struct TalKashaVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        let glyphes = aide.session.glyphesTalKasha
        HStack(spacing: Jetons.Espace.un) {
            Text(L("boss.talKasha.glyphes")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
            Spacer()
            ForEach(1...TalKasha.glyphesRequis, id: \.self) { rang in
                Text(String(repeating: "I", count: rang))
                    .font(Jetons.Typo.corpsFort.police)
                    .frame(width: Jetons.Espace.huit, height: Jetons.Taille.cibleMin)
                    .foregroundStyle(rang <= glyphes ? EtatVisuel.choisi.encre : Color.jeton(\.encreSecondaire))
                    .fondEtat(rang <= glyphes ? .choisi : .repos)
            }
            PetitBouton(icone: "minus", aide: L("boss.talKasha.moins")) {
                aide.noter { session, _ in session.glyphesTalKasha = max(session.glyphesTalKasha - 1, 0) }
            }
            .disabled(glyphes == 0)
            PetitBouton(icone: "plus", aide: L("boss.talKasha.plus")) {
                aide.noter { session, _ in session.glyphesTalKasha = min(session.glyphesTalKasha + 1, TalKasha.glyphesRequis) }
            }
            .disabled(glyphes == TalKasha.glyphesRequis)
        }
        if glyphes >= TalKasha.glyphesRequis {
            Consigne(texte: L("boss.talKasha.vulnerable"), icone: "checkmark.shield", forte: true)
        } else {
            let reste = TalKasha.glyphesRequis - glyphes
            Consigne(texte: L("boss.talKasha.reste", nombre: reste, reste), icone: "target", forte: true)
        }
    }
}
