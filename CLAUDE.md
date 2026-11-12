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
x86_64 en `DISTRIBUTION=1` (ad hoc), fait DMG, SHA256 et release GitHub, notes
tirées de `CHANGELOG.md`. `release.yml` ne fait que rejouer ce script.

Diagnostic en ligne de commande, **par le binaire installé** — l'autorisation Accessibilité est
liée à l'identité signée, celui de `.build/` ne l'a pas :

```sh
/Applications/Synfus.app/Contents/MacOS/Synfus --dump-dock dofus 30   # attributs AX du Dock
/Applications/Synfus.app/Contents/MacOS/Synfus --dump-windows         # fenêtres AX des clients
# Coût capture par zone / entière, relevé dans $TMPDIR/synfus-banc-captures.txt. Par `open` :
# l'autorisation d'enregistrer l'écran est celle du processus responsable, pas du terminal.
open -n -W -a /Applications/Synfus.app --args --banc-captures Code 30
SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png sh test.sh RealCapture   # OCR sur une capture
```

## Contraintes dures

- **Toujours le Xcode et le Swift les plus récents** (Xcode 27, Swift 6.4) : `swift-tools-version`
  et runner de CI (`xcode-27`) suivent la dernière version. `BarControls` appelle `glassEffect`
  (SDK ≥ 26) ; deployment target 14.0, repli `.ultraThinMaterial` par `if #available(macOS 26.0, *)`.
- **Swift 6, concurrence stricte, sans dérogation.** L'état vit sur main : toute classe à état est
  `@MainActor` (`Preferences` comprise) ; tout rappel livré sur main (Timer, notification, sink
  Combine, moniteur `NSEvent`) repasse par `MainActor.assumeIsolated` ; le callback C de `HotKeyManager` par `DispatchQueue.main.async`.
  Seules exceptions, des **acteurs sans état partagé** pour le travail bloquant, où n'entrent et
  ne sortent que des valeurs `Sendable` : `ClientInventoryEngine` (inventaire AX),
  `DockGeometryReader` (relevé AX du Dock), `PreviewCaptureEngine` (captures), `MoteurOCR` (Vision),
  `InstallateurMiseAJour` (téléchargement et contrôle d'une release).
- **Un seul foyer par logique.** Avant d'écrire une fonction, chercher celle qui existe ; quand une
  correction touche un chemin, vérifier que son jumeau en bénéficie. Foyers : lecture AX
  `AccessibilityReader` ; processus Dofus `DofusProcesses` ; titres `WindowTitle` ; fermeture
  `ClientTerminator` ; presse-papiers `PressePapiers` ; API DofusDB `DofusDB` (lots d'identifiants : `parIdentifiants`) ; images du jeu `ImagesDofusDB` (vues de carte : `VueCarte`, toujours réduites) ; effectif `republierEffectif` ; coût d'un trajet depuis le perso `ZaapClipboard` (`cout(depuis:)`, `tournee`) ; zaaps actifs indexés `ZaapClipboard.zaapsSitues` ; classes
  `ClassesStore.catalogue` ; marque `SynfusMark` (ses variantes `IconeApp`, posées par `IconeAppliquee`) ; couleurs et tailles `Jetons` (engendré par Synseria-Design, jamais retouché) via `Couleurs` ; polices `Font.synfus` ; libellés `L()` ; touche de raccourci `ToucheRaccourci`, voix d'état `EtatVisuel` (`fondEtat`, `StyleEtat`), rangs de bouton `StyleBouton`, cartes `carte()`, ce qui flotte `surfaceFlottante()` (`Interface/Composants.swift`) ; texte lu comparé à des noms `Ressemblance` ;
  zones de lecture `GenreLecture` ; coches, décoches, objectif en cours et étape des quêtes `Preferences.cocher` / `appliquer` (`CochesQuete`) ; coût d'un trajet `ItineraireZaap.cartes` ; distance à pied `ItineraireZaap.aPied` ; case hors du Monde des Douze `ReseauSousZones.horsDesDouze` (une entrée de palette vers une case : `versCase`) ;
  geste compté pour les statistiques `UsageStore.compter` ; plusieurs réglages d'un geste, une écriture `Preferences.enUneEcriture` ; résultat redemandé à chaque rendu
  `DernierCalcul` (sous la clé de ses entrées ; réglages des trajets et carte : `ZaapClipboard.revisionTrajets`).
- Les constantes `extern CFStringRef` de l'Accessibilité (`kAXTrustedCheckOptionPrompt`,
  `"AXFullScreen"`…) sont refusées par la concurrence stricte : citer leur valeur littérale.
- **Synfus n'émet, ne rejoue ni ne duplique aucun évènement.** Il change la fenêtre devant, pose
  position et taille, écrit le presse-papiers, termine des processus — jamais un clic ni une
  touche synthétisés, jamais de `CGEventTap`, aucun délai randomisé. Rejouer une action sur
  plusieurs clients serait un multiplicateur, interdit par les CGU de Dofus.
- **Aucun visuel du jeu dans le dépôt ni le bundle** (CGU Dofus, art. 13.2) : seulement des URL
  de DofusDB, téléchargées par l'app dans les caches de l'utilisateur (skill `marque-assets`).
  Les captures de `docs/screenshots` (`SYNFUS_CAPTURES=$PWD/docs/screenshots sh test.sh
  CapturesTests`, à part, écran allumé) s'en passent d'office : `Ressources.visuelsDuJeu`.
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
`CarteStore` → `ClassesStore` → `QuetesStore.preparer()` → `DonneesDuJeu` → `PaletteModele` → `ZaapClipboard` → `MiseAJour` → `UsageStore` → `IconeAppliquee`.

`Sources/Synfus/` est rangé par domaine (SwiftPM compile les sous-dossiers sans déclaration). Un
nouveau fichier va dans le dossier de son domaine ; un fichier sans domaine en annonce un nouveau.

| Dossier | Contenu |
| --- | --- |
| `App/` | Point d'entrée et `--dump-*`, intégrité du bundle, démarrage automatique, `PressePapiers`, `DofusDB` (client de l'API), `ImagesDofusDB`, `Ressources` (bundle, dossier de l'utilisateur), `IconeAppliquee` (icône choisie posée sur le bundle), `DernierCalcul` (pur), `DonneesDuJeu` (données DofusDB revues chaque jour) |
| `Accessibilite/` | `AccessibilityReader` (lecture AX, `DofusProcesses`), `--dump-windows`, `CrossSpaceTitles` |
| `Clients/` | `DofusClient`, `WindowTitle`, `ClientMemory`, `Equipes`, `Rotation` (purs) ; `WindowManager` (+`PremierPlan`, `+Effectif`, `+Focus`, `+Fermeture`), `ClientInventoryEngine`, `ClientTerminator`, `FreezeWatcher` |
| `Invitations/` | `/invite Nom` : `InvitationComposer` (pur), `InvitationClipboard` |
| `Carte/` | Tous les repères du jeu (zaaps, banques, ateliers, donjons…) et les sous-zones du Monde des Douze : `Lieu`, `Carte`, `ReseauSousZones`, `ReperesCarte` (purs), `CarteDofusDB` (téléchargement, cache disque, `--exporter-carte` → `Resources/Carte.json`), `CarteStore` (lue et indexée hors main) |
| `Zaaps/` | `/zaap x,y ; /travel a,b` : `Zaap` (tiré de la carte), `CatalogueZaaps`, `ItineraireZaap` (purs : le zaap de la sous-zone visée — connue d'un PNJ ou d'un lieu, sinon celle de la case —, sauf s'il est d'une autre région et que celui des voisines, dans la région, épargne `ecartZaapDuJeu` cartes), `ZaapsSitues` (pur : zaaps actifs indexés par sous-zone et par carte), `Tournee` (pur : ordre le plus court de plusieurs cases), `ZaapClipboard` (raccourci, bouton, veille du presse-papiers) |
| `Palette/` | La palette (⌘:) : `RecherchePalette`, `CommandesJeu` (purs) — zaaps, lieux, `/` commandes, `%` variables, quêtes, PNJ, gestes, dernières copies ; `PaletteModele`, `PalettePanel` (panneau key sans activer Synfus), `PaletteVue` |
| `Quetes/` | Quêtes et PNJ situés : `Quete` (pur : renvois, ressources, récompenses, suivantes), `QuetesDofusDB` (cache disque versionné relu au lancement, téléchargé s'il manque ou a 30 jours), `QuetesStore` (lu et indexé hors main), `QuetesEnVigueur` (pur : index et fiches gardées du jeu publié), `QuetePanel`/`QueteVue` (panneau transparent, jamais key, montré devant Dofus seulement), `SuiviQuetes`, `SuiviObjectifs` (purs : suivi du jeu lu par OCR, objectifs à faire et faits), `HistoriqueSuivi` (pur : lectures par perso, quêtes sorties du suivi), `QuetesIci` (pur : quêtes qui commencent et PNJ sur la case du perso — menu de l'en-tête, filtre « Ici » de la palette), `LectureSuivi`, `DofusPourLesNoobs` (adresses candidates du guide) |
| `OuTrouver/` | Où trouver un monstre ou un objet : `OuTrouver` (pur : la case de chaque repaire — sous-zone par l'index inverse de la carte, donjon par son repère —, l'ordre des repaires et des lâcheurs), `OuTrouverDofusDB` (monstre, butins et recette à la demande, cache disque versionné, 30 jours), `OuTrouverStore`, `OuTrouverVue` (dépliée sous une ressource ou un objectif) |
| `Donjons/` | Fiche d'un donjon, la même cherchée par lui ou par un boss : `Donjon`, `Donjons`, `DetailDonjon`, `FicheCombat` (purs : niveau, PV, PA, PM, résistances au plus haut grade, aussi pour le panneau des boss), `DonjonsStore` (liste à la première palette, détail à l'ouverture), `FicheDonjonVue`, `FicheCombatVue` |
| `MiseAJour/` | Mises à jour depuis les releases GitHub : `VersionPubliee` (pur : réponse de l'API, comparaison de versions, `SHA256SUMS.txt`), `InstallateurMiseAJour` (DMG téléchargé, empreinte, app extraite et contrôlée), `MiseAJour` (vérification quotidienne, proposition, remplacement par un script détaché, autorisations TCC effacées : les releases sont ad hoc) |
| `Usage/` | Statistiques d'utilisation : `EvenementUsage`, `HistoriqueUsage` (purs : liste fermée des compteurs, jours gardés sur le Mac), `RapportUsage` (pur : OTLP JSON, identifiant d'installation haché), `DiagnosticsUsage` (plantages et blocages remis par MetricKit), `UsageStore` (compte, `usage.json`, envoi quotidien au collecteur de Flux-Domus si `partagerStatistiques` et si la publication a inscrit adresse et jeton) |
| `Almanax/` | L'almanax du jour en tête de la palette : `Almanax` (pur : jour de Paris, réponse de DofusDB, cache disque du jour), `AlmanaxStore`, `AlmanaxVue` |
| `Boss/` | Aide aux boss : `Boss` (pur : Kimbo, Toxoliath, Ilyzaelle, Tal Kasha, `SessionBoss`), `Harebourg`, `SuiviConfusion` (purs : confusion du Comte, vie et canal combat lus), `ToursCombat` (pur : tour du combat), `AideBoss`, `BossPanel` (panneau jamais key, montré devant Dofus), `BossVue` (+ `HarebourgVue`, `VuesBoss`) |
| `Chasse/` | Chasse au trésor : `IndicesChasse`, `EtapeChasse` (purs), `ChasseDofusDB` (indices en cache disque, étape à la demande), `ChasseModele`, `ChassePanel` (panneau key sans activer Synfus), `ChasseVue` |
| `Attention/` | Rebond du Dock : `BounceDetector`, `DockPairing` (purs), `DockInspector`, `DockGeometryReader`, `AttentionWatcher`, `AttentionProbe` |
| `Raccourcis/` | Raccourcis Carbon, enregistreur, conflits, enchaînement au clic |
| `Rangement/` | `LayoutComputer` (pur), `WindowArranger` |
| `Apercus/` | Captures ScreenCaptureKit, panneau d'aperçu |
| `Lecture/` | OCR position, combat, suivis de chasse et de quêtes, vie et tchat : `ZoneEcran`, `PositionCarte`, `LectureCombat`, `LumaBitmap`, `Ressemblance`, `DetectionZones` (purs), `LecteurEcran` (+ `GenreLecture`, `DiagnosticLecture`, `MoteurOCR`), `CapturesCalibrage`, `AutoCalibrage` (zones retrouvées sur une capture) |
| `Preferences/` | `Preferences`, protocole `PreferencesStore` |
| `Classes/` | `DofusClass` (table intégrée, `Catalogue`, purs), `ClassesDofusDB` (liste `breeds`, cache disque, fusion), `ClassesStore` (emblèmes DofusDB ou icône de l'utilisateur) |
| `Marque/` | L'Œuf ajouré : `SynfusMark` (CoreGraphics pur, icône et glyphe), `Couvee` (l'autre motif), `IconeApp` (pur : motif × fond), `SynfusGlyph` (barre de menus) |
| `Localisation/` | `L()`, choix de langue ; tables dans `Resources/Localisation/` |
| `Interface/` | `Jetons` (engendré), `Couleurs` (thème courant), `Typographie`, `MenuBarController`, `ConfirmationFermeture`, `Composants` (états, cartes, surface flottante, touche, boutons), `ImagesCarte` (vignette de carte, vue agrandie au survol, pictogramme d'un lieu) ; `Barre/` (barre flottante) ; `Reglages/` (une vue par onglet) |

## Skills de domaine

| Skill | Charger avant de toucher |
| --- | --- |
| `inventaire-clients` | découverte des persos, inventaire AX, dormants, ordre et slots, équipes (modèle), invitations |
| `attention-dock` | détection du rebond, appariement Dock ↔ persos |
| `raccourcis` | raccourcis globaux, défauts, enregistreur, fn-clic, signal de bascule, rotation |
| `lecture-ocr` | lecture de la position et du combat |
| `aide-boss` | aide aux boss (Comte Harebourg), lecture de la vie et du canal combat |
| `fermeture-gel` | fermeture des clients, abattage des gelés |
| `interface-barre` | barre flottante, réglages, menu, aperçus, rangement des fenêtres ; ses exceptions à la grille UI (skill global `grille-ui`) |
| `localisation` | tout libellé visible, tables JSON |
| `preferences` | ajouter ou changer un réglage, un défaut |
| `mise-a-jour` | mise à jour depuis GitHub, assets d'une release, rafraîchissement des données DofusDB |
| `marque-assets` | classes et leurs emblèmes, visuels du jeu, marque et icône de l'app |
