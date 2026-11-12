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
        .font(.synfus(forte ? .corps : .petit, gras: forte))
        .foregroundStyle(urgente ? Couleurs.safranTexte : forte ? Color.primary : Color.secondary)
    }
}

// MARK: - Kimbo

/// Le couple d'éléments qui a frappé Kimbo — lu au canal combat, ou choisi
/// ici — dit où se tenir par rapport au Disciple et dans quels éléments
/// frapper.
struct KimboVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        Text(L("boss.kimbo.question")).font(.synfus(.petit)).foregroundStyle(.secondary)
        ChoixBoss(choix: [(Kimbo.Etat.impair, L("boss.kimbo.terreEau")), (.pair, L("boss.kimbo.airFeu"))],
                  actuel: aide.session.kimbo) { etat in aide.noter { session, _ in session.kimbo = etat } }
        if let etat = aide.session.kimbo {
            Consigne(texte: etat.glyphesImpairs ? L("boss.kimbo.reste.pair") : L("boss.kimbo.reste.impair"),
                     icone: "figure.stand", forte: true)
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
        let touche = aide.session.toxoliathTouche
        if let tour = aide.tour, Toxoliath.toxmose(toucheAu: touche, tour: tour), let touche {
            HStack(alignment: .top) {
                Consigne(texte: L("boss.toxoliath.toxmose", touche + Toxoliath.dureeToxmose - 1),
                         icone: "drop.triangle", urgente: true)
                Spacer(minLength: 4)
                PetitBouton(icone: "xmark", aide: L("boss.toxoliath.toxmose.annuler")) {
                    aide.noter { session, _ in session.toxoliathTouche = nil }
                }
            }
        } else {
            Button(L("boss.toxoliath.touche")) { aide.noter { session, tour in session.toxoliathTouche = tour ?? 1 } }
                .controlSize(.small)
                .help(L("boss.toxoliath.touche.aide"))
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
        switch Ilyzaelle.phase(seuil75: session.ilyzaelle75, seuil50: session.ilyzaelle50, tour: tour) {
        case .premiere:
            Consigne(texte: L("boss.ilyzaelle.objectif75"), icone: "target", forte: true)
            seuil(L("boss.ilyzaelle.seuil75")) { $0.ilyzaelle75 = $1 }
        case .allieeA75(let depuis):
            Consigne(texte: L("boss.ilyzaelle.alliee75", depuis + Ilyzaelle.dureeAlliee - 1), icone: "shield.lefthalf.filled",
                     forte: true)
        case .seconde:
            Consigne(texte: L("boss.ilyzaelle.objectif50"), icone: "target", forte: true)
            seuil(L("boss.ilyzaelle.seuil50")) { $0.ilyzaelle50 = $1 }
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
        if session.ilyzaelle75 != nil {
            Button(L("boss.ilyzaelle.annuler")) {
                aide.noter { session, _ in
                    if session.ilyzaelle50 != nil { session.ilyzaelle50 = nil } else { session.ilyzaelle75 = nil }
                }
            }
            .controlSize(.small)
        }
    }

    private func seuil(_ titre: String, noter: @escaping (inout SessionBoss, Int) -> Void) -> some View {
        Button(titre) { aide.noter { session, tour in noter(&session, tour ?? 1) } }
            .controlSize(.small)
    }
}

// MARK: - Tal Kasha

/// Les glyphes de monstres différents où Tal Kasha a commencé son tour, de I
/// à III — le jeu les montre au-dessus d'elle ; trois la rendent vulnérable.
struct TalKashaVue: View {
    @ObservedObject private var aide = AideBoss.shared

    var body: some View {
        let glyphes = aide.session.glyphesTalKasha
        HStack(spacing: 6) {
            Text(L("boss.talKasha.glyphes")).font(.synfus(.petit)).foregroundStyle(.secondary)
            Spacer()
            ForEach(1...TalKasha.glyphesRequis, id: \.self) { rang in
                Text(String(repeating: "I", count: rang))
                    .font(.synfus(.note, gras: true, design: .serif))
                    .frame(width: 30, height: 22)
                    .foregroundStyle(rang <= glyphes ? Couleurs.encreSurPrimaire : Color.secondary)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(rang <= glyphes ? Couleurs.primaire : Color.primary.opacity(0.08)))
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
