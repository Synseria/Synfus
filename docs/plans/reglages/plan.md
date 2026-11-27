# Plan : refonte des Réglages

La demande : « c'est tout dispersé, je me perds » ; ce qui n'est pas utile à un joueur lambda passe
sous un « Avancé » replié par défaut ; tout marche seul, en local. Propositions :
`propositions.json` (R01–R16) ; verdicts et notes mot pour mot : `verdicts-passe1.md`. Une note de
l'utilisateur prime sur le texte d'une proposition. Les maquettes sont approximatives : elles disent
où et quoi, jamais les pixels.

## Ce qui est validé

Toutes les propositions sauf R02 et R04 (refusées, avec une note chacune).

- **Structure** : R01 (onglets par intention, un « Avancé » replié par page) **et** R03 (les réglages
  d'une aide vont dans le menu « ⋯ » de son panneau), plus la note de R02 : « on garde les icônes en
  haut… et on met une liste à gauche par type ? Un mixte ». Les icônes du bandeau restent ; chaque
  onglet a une liste de ses sections à gauche.
- **Lecture** : R05 (une seule ligne d'autorisation), R06 (zones de lecture sous « Avancé »), R07 (une
  zone introuvable se retrouve seule), R08 (position et combat lus dès l'autorisation donnée).
- **Général et données** : R09 (Diagnostic sous « Avancé » de Général ; note : retravailler aussi
  l'affichage des éléments détectés), R10 (plus de « Mettre à jour » DofusDB par page), R11 (icônes des
  classes repliées), R12 (« Achever les clients gelés » sous « Avancé », **actif par défaut**).
- **Aides, lieux, trajets, raccourcis** : R13 (plus de boutons « Ouvrir » ; note : un interrupteur par
  boss aussi dans le panneau du boss), R14 (Données → Lieux, une liste à la fois, la liste des quêtes
  retirée : « je vais JAMAIS là »), R15 (Trajets : deux lignes, le reste sous « Avancé » ; gain minimal
  à 1, fait), R16 (Raccourcis : des touches seulement).

## Passe 2 (maquettes, avant le code de la structure)

1. Le mixte de R02 : bandeau d'icônes + liste des sections à gauche, sur la structure de R01 et R03
   (ce qu'il reste dans « En jeu » quand chaque aide se règle dans son panneau).
2. R04 reformulé : l'interrupteur « Vues des cartes » est aujourd'hui à trois endroits (Palette,
   Données, bloc des quêtes) ; la maquette ne l'a pas fait comprendre.
3. La note de R09 : l'affichage des éléments détectés dans le Diagnostic.

## Lots (un ouvrier à la fois sur cette machine)

| Lot | Propositions | Fichiers principaux |
|---|---|---|
| A — Structure | R01, R03, mixte R02 (après la passe 2) | `Interface/Reglages/SettingsView.swift`, `SettingsComponents.swift`, chaque page, menus « ⋯ » des panneaux |
| B — Lecture | R05, R06, R07, R08 | `LectureSettings.swift`, `CalibrationZonesView.swift`, `Lecture/AutoCalibrage.swift`, `LecteurEcran`, `Preferences` |
| C — Général et données | R09, R10, R11, R12 | `GeneralSettings.swift`, `DiagnosticSettings.swift`, `DonneesSettings.swift`, `ClassesSettings.swift`, `CharactersSettings.swift` |
| D — Aides, lieux, raccourcis | R13, R14, R15, R16 | `AidesSettings.swift`, `Boss/BossVue.swift`, `DonneesSettings.swift`, `ZaapsSettings.swift`, `ShortcutsSettings.swift` |

A touche toutes les pages : il passe en premier, B, C et D ensuite, l'un après l'autre. Un commit
par proposition, son test, captures avant / après regardées (`SYNFUS_CAPTURES=… SYNFUS_CAPTURES_TOUT=1
sh test.sh "reglages()"`).
