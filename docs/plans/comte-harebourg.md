# Plan : visée et vie autour du Comte Harebourg

Plan prêt à exécuter (« implémente le plan docs/plans/comte-harebourg.md »). Charger d'abord les
skills `aide-boss` et `lecture-ocr`. Synfus lit l'écran et affiche : aucun clic ni touche émis,
aucune lecture de la mémoire du jeu.

## Précisions de l'utilisateur (25/11/2026)

« Je vise cette position (centre du carré rouge) et si j'ai π, ½π, tu affiches la position qui
sera affectée par rapport au centre du personnage sur l'écran. » D'où, pour la question 6 : on
montre la case **d'arrivée** de la case visée, tournée autour du **centre du personnage à l'écran**.

Ce que montre sa capture de combat (mode tactique, damier bleu et clair) :
- la case visée est la **croix de visée** au centre d'une zone rouge (la portée du sort) — elle se
  repère sans le pointeur ;
- chaque combattant porte son **numéro** au-dessus de lui (1 à 7) et dans la timeline en bas,
  le perso actif encadré (n° 1 ici) : piste sérieuse pour le pivot automatique (V2) ;
- le **mode tactique** (cases unies, sans décor sur la grille) rend le damier très contrasté : le
  recalage automatique de la grille (A3) y est le plus sûr — à recommander en combat contre le Comte ;
- le cœur affiche les PV courants (« 4162 ») ; le panneau du combattant survolé, en bas à gauche,
  donne nom, « 4000 ♥ », PA, PM : c'est le cadre fixe de la question 2 (lecture fixe, option a).

## 0. Point de départ

### Code en place

- `Boss/Harebourg.swift` (pur) : `Confusion.caseVisee(cible:)` tourne **à rebours** dans le repère
  des cases (x ↘, y ↙ ; contre-horaire `(x, y) → (y, −x)`) ; `parVie(pourcentage:)` (tranche et
  voisine) ; `vie(_ lignes:)` lit le cœur (`57%`, `a / b`, points seuls) ; `dernierConstat` lit le
  canal combat.
- `Boss/SuiviConfusion.swift` (pur) : par perso `maxConnu`, `vieLue`, `vieDebutTour`, annonces,
  coups, choix à la main. `maxConnu` vit en mémoire et ne vient que d'un `a / b` lu au cœur.
- `Boss/HarebourgVue.swift` : `SchemaVisee` porte en **privé** la géométrie du losange
  (`point(x, y, a, centre)` = `(x−y)·a, (x+y)·a/2`, `cellule(de:)`). C'est la conversion
  pixel ↔ case de la visée : à extraire, une seule source.
- `Lecture/LecteurEcran.swift` : `GenreLecture` est la table des zones, `capturer` le seul chemin
  de capture, limité à la fenêtre du jeu (`SCContentFilter(desktopIndependentWindow:)`) — un calque
  posé sur le jeu n'apparaît jamais dans nos captures. `vie` et `tchat` se lisent chaque seconde en
  combat tant que `BossPanel` est montré.
- Géométrie : `ZoneEcran.contenu(fenetre:barreTitre:pleinEcran:)`, `GeometrieCapture.barreTitre`,
  `LayoutComputer.flipY(_:hauteurPrincipale:)`, `AccessibilityReader.frame(of:)`.
- Panneaux qui laissent passer les clics : `ImagesCarte`, `InfobulleBarre`, `AideHuppermage`
  (`ignoresMouseEvents = true`).
- `Donjons/FicheCombat.vie` : PV du boss au plus haut grade (monstre 3416), maximum **indicatif**.

### Captures de calibrage (`~/Library/Caches/Synfus/Calibrage/`, hors dépôt)

- `combat.png` (contenu 1767 × 1080) : plateau en **damier** de losanges bien contrasté (recalage
  automatique réaliste) ; combattants **numérotés** sur le plateau et dans la **timeline** (barre
  de vie rouge verticale par portrait) ; un **cadre fixe en haut à gauche** donne nom et niveau du
  combattant survolé ; le **cœur affiche « 3087 », sans maximum** — le cas que la partie B résout ;
  le canal combat écrit `Syl-Ami : -264PV`.
- Manquent (étape A0) : mode visée (portée affichée), survol du Comte, caméra zoomée, deux tailles
  de fenêtre.

### Bug à corriger d'emblée

`Harebourg.vie(["950", "4200"])` joint les lignes par une espace : l'expression des milliers lit
« 950 420 » comme un seul nombre. Une vie sur deux lignes (courant puis max) se lit donc mal.

## 1. Faisabilité de la visée

| Brique | Faisabilité | Comment |
|---|---|---|
| Position du pointeur | Sûre | `NSEvent.mouseLocation` (passif), ramenée au contenu de la fenêtre par `AccessibilityReader.frame`, `flipY`, `ZoneEcran.contenu`, `barreTitre`. Aucune capture. |
| Pixel → case | Bonne, caméra fixe | Grille 2:1 : origine et demi-largeur `a` en fractions du contenu, calibrées une fois ; valables tant que rapport et zoom ne changent pas. |
| Recalage automatique | Probable | Damier net : bords à pente ±½ → période `a` et phase par projection. Pur, peu coûteux, à valider sur capture. |
| Case du perso (pivot) | Point dur | V1 : un raccourci marque la case sous le pointeur. V2 : détection (numéro du combattant actif, ou centre de la portée bleue). |
| Case d'arrivée | Sûre une fois le reste posé | `Confusion.caseAtteinte(visee:)` en cases, jamais en pixels ; voisine dessinée si `estimation.voisine`. |
| Mode visée | V2 | V1 : calque actif pendant le tour du perso devant, pivot marqué, modificateur en option. |
| Affichage | Sûr | `NSPanel` sans bord, non activable, `ignoresMouseEvents`, à la taille du contenu de Dofus. Repli possible : indication textuelle seule. |

Risque principal de la V1 : zoom ou déplacement de caméra, rapport de fenêtre changé, pivot périmé
(perso déplacé, poussé, téléporté). **Toujours montrer le pivot retenu**, masquer le calque dès que
la grille ne vaut plus pour le rapport courant.

Coûts : V1 sans capture de plus (pointeur à 30 Hz sur main, redessin au changement de case, cadre
AX relu à 2 Hz). V2 : une capture du contenu entier coûte 43 ms de mur, 11 ms de CPU à 1080 px
(`--banc-captures`) ; à 2 Hz, pendant le seul tour, à demi-échelle : moins de 3 % d'un cœur.

## 2. Partie A : la visée

### 2.1 Fichiers

**`Lecture/GrilleIso.swift` (nouveau, pur)** — seul foyer de la géométrie des cases :

```swift
struct GrilleIso: Codable, Equatable, Sendable {
    struct Case: Hashable, Sendable { var x: Int; var y: Int }   // repère de Harebourg
    var origine: CGPoint        // centre d'une case de référence, en fractions du contenu
    var demiLargeur: Double     // en fraction de la HAUTEUR du contenu (demi-hauteur = a/2)
    var rapport: Double         // largeur/hauteur au calibrage : un autre rapport (±1 %) l'invalide
    static func projeter(_ c: Case, a: CGFloat, centre: CGPoint) -> CGPoint
    static func caseSous(_ p: CGPoint, a: CGFloat, centre: CGPoint) -> Case
    static func losange(_ c: Case, a: CGFloat, centre: CGPoint) -> [CGPoint]
    func caseSous(fraction p: CGPoint, contenu: CGSize) -> Case
    func centre(_ c: Case, contenu: CGSize) -> CGPoint
    func valable(pour contenu: CGSize) -> Bool
    static func depuis(centreA: CGPoint, centreB: CGPoint, ecart: Case, contenu: CGSize) -> GrilleIso?
}
```

`SchemaVisee` appelle `GrilleIso.projeter`, `caseSous`, `losange` à la place de ses fonctions
privées, à comportement identique.

**`Boss/Harebourg.swift`** : `func caseAtteinte(visee:) -> (x: Int, y: Int)`, `quarts` quarts
horaires `(x, y) → (−y, x)`, inverse exact de `caseVisee`. Exemple : un quart, visée (0, −2) en
haut à droite → arrivée (2, 0) en bas à droite.

**`Lecture/ZoneEcran.swift`** :
- `static func fraction(pointEcran:fenetreAX:hauteurPrincipale:barreTitre:pleinEcran:) -> CGPoint?`
  (point `NSEvent` → fraction du contenu, `nil` hors du contenu) ;
- `static func cadreAppKit(fenetreAX:hauteurPrincipale:barreTitre:pleinEcran:) -> CGRect` (pour
  poser le calque).

**`Boss/ViseeHarebourg.swift` (nouveau, pur)** — la décision :

```swift
struct ViseeHarebourg: Equatable, Sendable {
    private var lanceurs: [String: (case: GrilleIso.Case, le: Date)]
    mutating func marquer(_ c: GrilleIso.Case, perso: String, le: Date)
    mutating func oublier(perso: String)          // au placement
    func lanceur(_ perso: String) -> GrilleIso.Case?
    struct Arrivee: Equatable, Sendable { let case_: GrilleIso.Case; let principale: Bool }
    static func arrivees(survolee: GrilleIso.Case, lanceur: GrilleIso.Case,
                         estimation: SuiviConfusion.Estimation) -> [Arrivee]
    enum Inactive: Equatable, Sendable { case reglage, pasHarebourg, panneauCache, pasSonTour,
        grilleAbsente, grilleInvalide, sansLanceur, sansConfusion, horsDuJeu, modificateur }
    static func active(_ e: Entrees) -> Result<Void, Inactive>
}
```

**`Boss/ViseePanel.swift` (nouveau, `@MainActor`)** : `NSPanel` `.borderless, .nonactivatingPanel`,
`ignoresMouseEvents`, fond clair, sans ombre, `.canJoinAllSpaces, .fullScreenAuxiliary`, niveau
`.floating` (sous les `PanneauDeJeu` en `.statusBar`) — **exception à documenter** : ce n'est pas un
`PanneauDeJeu`. Timer à 30 Hz seulement calque actif (`MainActor.assumeIsolated`), publication au
seul changement de case, cadre AX relu toutes les 0,5 s. `revoirVisibilite(force:)` ajouté à
`PanneauxJeu.revoir`. `ViseeVue` (`Canvas`, jetons) : losange d'arrivée en `accent` translucide,
voisine en pointillés `avertissement`, pivot cerclé `encre2`, case survolée en filet fin ; au plus
un libellé `L("boss.visee.tombeIci")`.

**`Boss/AideBoss.swift`** : `@Published private(set) var visee = ViseeHarebourg()` ;
`marquerLanceur()` (raccourci : pointeur + grille + `persoDevant`) ; `visee.oublier` au placement.

**Raccourci** : action « Marquer ma case (Comte Harebourg) », `marquerLanceurHotKey: HotKey?`,
**sans défaut** (raccourci Carbon : rien n'est synthétisé).

**Calibrage** (`LectureSettings` + `Interface/Reglages/CalibrationGrilleView.swift`) : ligne
« Grille de combat » ; feuille sur une capture `grille.png` (compte à rebours de 5 s comme
`CalibrationZonesView`) : clic au centre d'une case A, d'une case B, pas « B est à N cases sur la
diagonale ↘ » ; grille dessinée par-dessus, réglage fin (décalage, `a`) ; « Détecter » au lot A3.
`CapturesCalibrage.fichier(nom:)` généralisé ; note `<nom>.json` avec la position du pointeur.

### 2.2 Étapes (V1)

- **A0. Captures** (geste de l'utilisateur) : en combat, son tour, sort préparé, pointeur sur une
  case, en fenêtré 1728 × 1084 ; la même en plein écran ; caméra zoomée ; option « grille » du jeu
  allumée et éteinte. Mesures (`a`, origine) notées dans `aide-boss`.
- **A1 (fait).** `GrilleIso` (projection, case sous un point, losange), `SchemaVisee` branché
  dessus. Le reste de la struct (origine, rapport, `depuis`) et `caseAtteinte` arrivent avec leur
  appelant, en A2.
- **A2. Pointeur, `ViseeHarebourg`, raccourci, réglages, `ViseePanel`, calibrage à deux clics.**
  Fin en combat réel : pivot marqué, losange qui suit le pointeur, clics qui passent, calque masqué
  hors du tour, hors du contenu ou au changement de rapport ; raison d'inactivité au Diagnostic.
- **A3. « Détecter » la grille** — `Lecture/AjustementGrille.swift` (pur, sur `LumaBitmap`) :
  énergie de bord projetée sur `y − x/2` et `y + x/2`, autocorrélation → période `a`, phases →
  origine ; score, refus sous un seuil. Fin : banc synthétique vert ; `RealCaptureTests` retrouve
  la grille de `combat.png` à 2 % de la mesure manuelle.

### 2.3 V2 (après la V1 éprouvée)

1. Grille suivie : `AjustementGrille` rejoué à 0,5 Hz pendant le tour sur capture à demi-échelle,
   genre `GenreLecture.plateau` sans OCR, routé vers un **acteur sans état** `AnalysePlateau`.
   Une période qui change = zoom : recaler ou masquer.
2. Pivot automatique, à départager sur les captures A0 : numéro du portrait actif de la timeline
   relu sur le plateau (pied à décalage fixe sous l'étiquette), ou centre L1 des cases teintées
   de la portée (vote, faussé par bords et obstacles) — qui détecte aussi le mode visée.
3. Calque montré seulement portée affichée.
4. Budget : ≤ 3 % d'un cœur pendant le tour (`--banc-captures` étendu à `plateau`), rien hors du tour.

### 2.4 Tests (Swift Testing, logique pure)

- `GrilleIsoTests` : `projeter` puis `caseSous` rend la case sur −7…7² ; intérieur d'un losange ;
  `depuis(…)` retrouve `a` et l'origine ; `valable` refuse un autre rapport ; l'ancienne
  `SchemaVisee.cellule` égale `caseSous`.
- `HarebourgTests` : `caseAtteinte(caseVisee(c)) == c` et l'inverse, quatre `quarts`, −5…5² ;
  l'exemple horaire.
- `ZoneEcranTests` : `fraction(pointEcran:…)` fenêtré (barre de 28 pt), plein écran, écran à x
  négatif, écran au-dessus du principal, hors du contenu.
- `ViseeHarebourgTests` : une ou deux arrivées, pivot immobile, chaque cause d'`Inactive`, oubli au
  placement.
- `AjustementGrilleTests` : damiers synthétiques (`a` de 20 à 60 px, phase quelconque, bruit,
  sprites, bandes d'interface) : `a` à ±2 %, origine à ±0,1 case, refus sans damier.
- `RealCaptureTests` : `SYNFUS_GRILLE_ATTENDUE="a,ox,oy"`, `SYNFUS_SOURIS="x,y"`. Aucun visuel du
  jeu dans le dépôt : fixtures synthétiques.

## 3. Partie B : vie du Comte et PV max des persos

### 3.1 Fichiers

**`Boss/VieLue.swift` (nouveau, pur)**, dont `Harebourg.vie` devient le simple appelant :

```swift
struct VieLue: Equatable, Sendable {
    var nom: String?; var actuels: Int?; var max: Int?; var pourcentage: Double?
    static func depuis(_ lignes: [String]) -> VieLue?
}
```

Ligne par ligne (les milliers ne se cherchent que dans une ligne), dans l'ordre : un `%` ; `a / b`
sur une ligne ou à cheval (`a /` puis `b`) ; **deux lignes de nombres consécutives** (courant puis
max, gardées si courant ≤ max) ; un nombre seul (courant) ; une ligne sans chiffres (`nom`).

**PV max des persos : pour le combat seulement** (arbitrage du 26/11/2026). Fait au lot B1, dans
`SuiviConfusion` (`maxConnu`) : rien de persisté, pas de « ≈ ».

- Le **dernier max écrit par le jeu fait foi**, pas le plus grand vu.
- Un max qui s'écarte de plus de 30 % du connu doit être lu **deux fois de suite**.
- `actuels > max connu` : max périmé, oublié.
- Pas de borne basse. Max et vie s'oublient à la sortie du combat et au placement.
- Deux lignes de nombres = courant puis max, seulement si le max vaut ≥ 100 : sous le cœur, les PA
  et les PM (« 12 », « 5 ») ne sont pas un max.

**`Boss/SuiviConfusion.swift`** : le Comte, gardé **une seule fois** :

```swift
struct VieComte: Equatable, Sendable {
    let actuels: Int?; let max: Int?; let pourcentage: Double?
    enum Source: Equatable, Sendable { case survol, timeline, maxDofusDB }
    let source: Source; let le: Date
}
mutating func vieComte(_ lue: VieLue, maxIndicatif: Int?, le: Date)
```

`maxIndicatif` (`FicheCombat.vie`) ne sert qu'à défaut de max lu, et se dit.

**Nouveau genre `.survol`** — à trancher sur la capture A0 du survol :
- (a) le cadre fixe en haut à gauche porte les PV : zone fixe ordinaire, la plus sûre ;
- (b) sinon une infobulle au-dessus du combattant : zone **relative au pointeur**
  (`ZoneEcran.autour(pointeur:decalage:)`, pur), lue pointeur immobile depuis 0,4 s.

Points de raccord : `GenreLecture` (case, `ZoneEcran.survolParDefaut`, `\.zoneSurvol`, 1 s,
`.lignes`) ; `Preferences.zoneSurvol` + ligne `.optionnel` ; empreinte de `PreferencesTests` ; la
liste `zones` de `LecteurEcran.start()` ; le `switch` de `lire` (`AideBoss.recevoirSurvol`) ;
`Boss.harebourg.lectures` → `[.vie, .tchat, .survol]` ; `DetectionZones` ;
`CalibrationZonesView.comprendre` ; `LectureSettings` ; le nom du genre en `L()`. En (b),
`capturer` reçoit la zone calculée au moment de la capture (`genre.zone(pointeur:)`).

**`Boss/AideBoss.swift`** : `recevoirSurvol(_:perso:)` → `VieLue.depuis` ; nom proche du Comte
(noms fr/en/es du monstre 3416, `Ressemblance`) → `vieComte` ; perso connu → son max du combat,
même derrière.

**`Boss/HarebourgVue.swift`** : ligne « Comte : 62 % · 2 604 / 4 200 », grisée et datée au-delà de
10 s, sa source dite (« au survol », « max DofusDB ») ;
`boss.vie.sansMax` seulement si aucun max n'a été lu pour ce perso dans ce combat.

### 3.2 Étapes

- **B1 (fait).** Bug des deux lignes, max du combat. Le cœur
  « 3087 » donne un pourcentage dès qu'un max a été lu dans le combat.
- **B2.** Captures A0 du survol (Comte, son perso, un portrait de la timeline) → (a) ou (b),
  `survolParDefaut` mesuré.
- **B3.** Genre `.survol` de bout en bout + calibrage. Fin : `RealCaptureTests`
  (`SYNFUS_SOURIS`, `SYNFUS_VIE_ATTENDUE="2604/4200"`, `SYNFUS_NOM_ATTENDU="Harebourg"`) vert ;
  vie du Comte affichée au survol en jeu.
- **B4 (V2).** Barre de la timeline : `Lecture/BarreVie.swift` (pur, RGBA), part rouge → « ~ % »,
  genre `.timeline` sans OCR ; portrait du Comte désigné au calibrage ou par son cadre de boss.
- **B5 (option).** Canal combat : `Harebourg.degats(ligne)` lit `Nom : -264PV` / `+120PV` pour tenir
  le courant entre deux survols — fragile, pour recouper seulement.

### 3.3 Tests

- `VieLueTests` : `["950", "4200"]` → 950/4200 (le bug) ; `["3 450 / 4 200"]` ;
  `["3450 /", "4200"]` ; `["Comte Harebourg", "2604", "4200"]` ; `["57 %"]` ; `["3087"]` ;
  `["4200", "950"]` refusé en paire ; bruit OCR, `\u{202F}` ; nom fr/en/es.
- `HarebourgTests` : le Comte hors des persos ; `maxIndicatif`
  seulement à défaut.
- `PreferencesTests` : nouvelles clés.

## 4. Réglages, libellés, skills

| Clé | Type, défaut | Partie |
|---|---|---|
| `harebourgVisee` | `Bool`, `false` | A |
| `harebourgViseeModificateur` | `.enTexte` (`aucun`/`option`/`maj`), `aucun` | A |
| `grilleCombat` | `GrilleIso?`, `nil` | A |
| `marquerLanceurHotKey` | `HotKey?`, `nil` | A |
| `zoneSurvol` | `ZoneEcran?`, `nil` | B |

Libellés (fr/en/es) : `boss.visee.*`, `lecture.grille*`, `lecture.genre.survol`, `boss.comte.vie*`,
`raccourcis.marquerLanceur`.

Skills : `aide-boss` (visée, vie du Comte, mémoire des PV, mesures de grille), `lecture-ocr`
(genres `survol`, `plateau`, `timeline`, coûts, note du pointeur, variables de `RealCaptureTests`),
`raccourcis` (nouvelle action sans défaut), `interface-barre` (calibrage de la grille, calque qui
laisse passer les clics). `AGENTS.md` : foyers `GrilleIso`, `VieLue`, `ViseePanel`.

Avant de dire un lot fini : `swift build`, `sh test.sh`, skill `analyse-swift`, skill `grille-ui`,
lancement réel en combat.

## 5. Ordre de livraison

| Lot | Contenu | Risque |
|---|---|---|
| 1 | B1 : bug des deux lignes, max du combat (fait) | Faible, gain immédiat |
| 2 | A0/B2 : captures (utilisateur) + note du pointeur | Aucun |
| 3 | A1 : `GrilleIso`, extraction, `caseAtteinte` | Faible |
| 4 | A2 : visée V1 | Moyen (caméra, pivot périmé) |
| 5 | B3 : `.survol`, vie du Comte | Moyen |
| 6 | A3 : « Détecter » la grille | Moyen |
| 7 | V2 : grille suivie, pivot auto, mode visée, timeline, canal combat | Élevé, sur mesures |

## 6. Questions à trancher par l'utilisateur

1. La confusion se déduit de **ta** vie (code et libellés actuels). La vie du Comte n'est-elle
   qu'une information, ou des phases dépendent-elles de **sa** vie ?
2. Les « deux lignes » courant / max : cadre fixe en haut à gauche, infobulle au-dessus du
   combattant, ou survol d'un portrait de la timeline ?
3. ~~PV max par perso~~ : tranché, pour le combat seulement. L'érosion baisse-t-elle le max
   affiché ?
4. Un calque qui ne dessine qu'un losange et laisse passer les clics te convient-il au regard des
   CGU, ou seulement l'indication dans le panneau (« tombe 2 cases ↘ ») ?
5. Pivot en V1 par raccourci « marquer ma case » : quelle combinaison ? L'oublier à chaque tour ou
   au placement seulement ?
6. Montrer la case **d'arrivée** de la case survolée, la case **à viser** pour toucher la case
   survolée, ou les deux au choix ?
7. Calque actif tout le tour, ou modificateur maintenu (⌥ / ⇧) ?
8. Utilises-tu le zoom de caméra en combat ? Sinon la V1 suffit.
9. Timeline (V2) : portrait du Comte désigné à la main, ou reconnu par son cadre de boss ?
