# CLAUDE.md

Synfus : app AppKit `LSUIElement` (barre de menus, pas de Dock) qui montre les persos Dofus
connectés et bascule de l'un à l'autre. Cette page est la carte ; le détail de chaque domaine est
dans un skill de `.claude/skills/` (index en bas), à charger avant d'y toucher.

## Langue

Le dépôt est intégralement en français, accents compris : commentaires, clés et textes source de
l'interface, messages des scripts, documentation. L'interface est traduite en anglais et en
espagnol : aucun libellé en dur dans une vue, tout passe par `L("clé")` (skill `localisation`).

## Commandes

```sh
swift build                   # compilation debug rapide (pas de bundle)
sh test.sh                    # suite complète (Swift Testing), sortie filtrée
sh test.sh PreferencesTests   # une suite ou un test ; plusieurs filtres = l'un ou l'autre
sh run.sh [--start | --install [--start]]      # build Debug .build/dev/, ou Release dans /Applications
sh build.sh [--release [X.Y.Z] | --publish X.Y.Z]   # dist/Synfus.app, + DMG, ou tag → release.yml
```

Scripts, signature, version (dernier tag `vX.Y.Z`), lots et publication suivent la convention
commune : **skill `livraison`**. `--publish` (depuis `main` propre, refuse une version sans section
dans `CHANGELOG.md`) teste, pousse `main` et le tag, puis **publie depuis ce Mac**
(`PUBLICATION_PAR_CI=0`, le runner n'a pas Xcode 27) : `Tools/publier-release.sh` compile arm64 +
x86_64 en `DISTRIBUTION=1` (ad hoc, sans visuel du jeu), fait DMG, SHA256 et release GitHub, notes
tirées de `CHANGELOG.md`. `release.yml` ne fait que rejouer ce script.

Diagnostic en ligne de commande, **par le binaire installé** — l'autorisation Accessibilité est
liée à l'identité signée, celui de `.build/` ne l'a pas :

```sh
/Applications/Synfus.app/Contents/MacOS/Synfus --dump-dock dofus 30   # attributs AX du Dock
/Applications/Synfus.app/Contents/MacOS/Synfus --dump-windows         # fenêtres AX des clients
SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png sh test.sh RealCapture   # OCR sur une capture
```

## Contraintes dures

- **Toujours le Xcode et le Swift les plus récents** (Xcode 27, Swift 6.4) : `swift-tools-version`
  et runner de CI (`xcode-27`) suivent la dernière version. `BarView` appelle `glassEffect`
  (SDK ≥ 26) ; deployment target 14.0, repli `.ultraThinMaterial` par `if #available(macOS 26.0, *)`.
- **Swift 6, concurrence stricte, sans dérogation.** L'état vit sur main : toute classe à état est
  `@MainActor` (`Preferences` comprise) ; callbacks Timer et notification repassent par
  `MainActor.assumeIsolated` ; le callback C de `HotKeyManager` par `DispatchQueue.main.async`.
  Seules exceptions, des **acteurs sans état partagé** pour le travail bloquant, où n'entrent et
  ne sortent que des valeurs `Sendable` : `ClientInventoryEngine` (inventaire AX),
  `PreviewCaptureEngine` (captures), `MoteurOCR` (Vision).
- **Un seul foyer par logique.** Avant d'écrire une fonction, chercher celle qui existe ; quand une
  correction touche un chemin, vérifier que son jumeau en bénéficie. Foyers : lecture AX
  `AccessibilityReader` ; processus Dofus `DofusProcesses` ; titres `WindowTitle` ; fermeture
  `ClientTerminator` ; presse-papiers `PressePapiers` ; API DofusDB `DofusDB` ; effectif `republierEffectif` ; classes
  `DofusClass` ; marque `SynfusMark` ; libellés `L()`.
- Les constantes `extern CFStringRef` de l'Accessibilité (`kAXTrustedCheckOptionPrompt`,
  `"AXFullScreen"`…) sont refusées par la concurrence stricte : citer leur valeur littérale.
- **Synfus n'émet, ne rejoue ni ne duplique aucun évènement.** Il change la fenêtre devant, pose
  position et taille, écrit le presse-papiers, termine des processus — jamais un clic ni une
  touche synthétisés, jamais de `CGEventTap`, aucun délai randomisé. Rejouer une action sur
  plusieurs clients serait un multiplicateur, interdit par les CGU de Dofus.
- **Aucun visuel du jeu dans le dépôt** (CGU Dofus, art. 13.2) : seulement des URL, copie faite
  par l'utilisateur (skill `marque-assets`).
- **Identité TCC** : `signature.sh` choisit Developer ID, puis Apple Development de l'équipe
  `339WUY8TXY`, puis tout autre Apple Development, puis « Synfus Dev »
  (`Tools/make-signing-identity.sh`), puis ad hoc (CI). Changer d'identité ou de `BUNDLE_ID`
  (`fr.synseria.Synfus`) fait réautoriser Accessibilité et enregistrement de l'écran ; le
  `BUNDLE_ID` nomme aussi le fichier de préférences.
- **Tests sur la logique pure** : chaque décision testable a son fichier pur (`WindowTitle`,
  `ClientMemory`, `LayoutComputer`, `BounceDetector`, `FreezeStrikes`…). AX, Dock et AppKit se
  vérifient par un lancement réel (`sh run.sh --install --start`) et l'onglet Diagnostic.
  Préférences : `Preferences.forTesting(store:)`, **jamais** `UserDefaults(suiteName:)` — un
  domaine persistant survit à `removePersistentDomain` (`cfprefsd` le réécrit) et chaque
  exécution sèmerait un plist dans `~/Library/Preferences`.

## Architecture

Point d'entrée `SynfusMain` (`App/App.swift`). Composants : singletons `@MainActor` (`.shared`),
la plupart `ObservableObject`. `applicationDidFinishLaunching` démarre, dans l'ordre :
`WindowManager` → `FreezeWatcher` → `HotKeyManager.rebind()` → `MenuBarController` →
`AttentionWatcher` → `ClickAdvanceWatcher` → `FloatingBarController` → `LecteurEcran` →
`CarteStore` → `ZaapClipboard`.

`Sources/Synfus/` est rangé par domaine (SwiftPM compile les sous-dossiers sans déclaration). Un
nouveau fichier va dans le dossier de son domaine ; un fichier sans domaine en annonce un nouveau.

| Dossier | Contenu |
| --- | --- |
| `App/` | Point d'entrée et `--dump-*`, intégrité du bundle, démarrage automatique, `PressePapiers`, `DofusDB` (client de l'API) |
| `Accessibilite/` | `AccessibilityReader` (lecture AX, `DofusProcesses`), `--dump-windows`, `CrossSpaceTitles` |
| `Clients/` | `DofusClient`, `WindowTitle`, `ClientMemory`, `Equipes`, `Rotation` (purs) ; `WindowManager` (+`PremierPlan`, `+Effectif`, `+Focus`, `+Fermeture`), `ClientInventoryEngine`, `ClientTerminator`, `FreezeWatcher` |
| `Invitations/` | `/invite Nom` : `InvitationComposer` (pur), `InvitationClipboard` |
| `Carte/` | Tous les repères du jeu (zaaps, banques, ateliers, donjons…) et les sous-zones du Monde des Douze : `Lieu`, `Carte`, `ReseauSousZones` (purs), `CarteDofusDB` (téléchargement, cache disque, `--exporter-carte` → `Resources/Carte.json`), `CarteStore` |
| `Zaaps/` | `/zaap x,y ; /travel a,b` : `Zaap` (tiré de la carte), `CatalogueZaaps`, `ItineraireZaap` (purs : le zaap de la sous-zone visée, sinon par les voisines), `ZaapClipboard` (raccourci, bouton, veille du presse-papiers) |
| `Palette/` | La palette (⌘:) : `RecherchePalette`, `CommandesJeu` (purs) — zaaps, lieux, `/` commandes, `%` variables, quêtes, PNJ, gestes, dernières copies ; `PaletteModele`, `PalettePanel` (panneau key sans activer Synfus), `PaletteVue` |
| `Quetes/` | Quêtes et PNJ situés : `Quete` (pur : renvois, ressources), `QuetesDofusDB` (téléchargement à la première palette, cache disque, 30 jours), `QuetesStore`, `QuetePanel`/`QueteVue` (panneau transparent, jamais key) |
| `Chasse/` | Chasse au trésor : `IndicesChasse`, `EtapeChasse` (purs), `ChasseDofusDB` (indices en cache disque, étape à la demande), `ChasseModele`, `ChassePanel` (panneau key sans activer Synfus), `ChasseVue` |
| `Attention/` | Rebond du Dock : `BounceDetector`, `DockPairing` (purs), `DockInspector`, `DockGeometryReader`, `AttentionWatcher`, `AttentionProbe` |
| `Raccourcis/` | Raccourcis Carbon, enregistreur, conflits, enchaînement au clic |
| `Rangement/` | `LayoutComputer` (pur), `WindowArranger` |
| `Apercus/` | Captures ScreenCaptureKit, panneau d'aperçu |
| `Lecture/` | OCR position et combat : `ZoneEcran`, `PositionCarte`, `LectureCombat`, `LumaBitmap` (purs), `LecteurEcran` (+ `DiagnosticLecture`, `MoteurOCR`) |
| `Preferences/` | `Preferences`, protocole `PreferencesStore` |
| `Classes/` | `DofusClass`, icônes utilisateur, visuels Ankama locaux |
| `Marque/` | La Couvée : `SynfusMark` (CoreGraphics pur), `SynfusGlyph` |
| `Localisation/` | `L()`, choix de langue ; tables dans `Resources/Localisation/` |
| `Interface/` | `MenuBarController`, `ConfirmationFermeture` ; `Barre/` (barre flottante) ; `Reglages/` (une vue par onglet) |

## Skills de domaine

| Skill | Charger avant de toucher |
| --- | --- |
| `inventaire-clients` | découverte des persos, inventaire AX, dormants, ordre et slots, équipes (modèle), invitations |
| `attention-dock` | détection du rebond, appariement Dock ↔ persos |
| `raccourcis` | raccourcis globaux, défauts, enregistreur, fn-clic, signal de bascule, rotation |
| `lecture-ocr` | lecture de la position et du combat |
| `fermeture-gel` | fermeture des clients, abattage des gelés |
| `interface-barre` | barre flottante, réglages, menu, aperçus, rangement des fenêtres |
| `localisation` | tout libellé visible, tables JSON |
| `preferences` | ajouter ou changer un réglage, un défaut |
| `marque-assets` | classes, icônes, visuels Ankama, marque et icône de l'app |
