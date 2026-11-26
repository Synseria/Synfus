# Plan : assistant de forgemagie

Plan prêt à exécuter (« implémente le plan docs/plans/forgemagie.md »), lot par lot. La recherche
qui le fonde, sources et degré de confiance compris : `docs/plans/forgemagie-recherche.md` (désignée
ci-dessous « R§n »). Synfus lit l'écran et recommande ; il ne clique jamais, ne fusionne jamais une
rune, n'enchaîne rien (CGU).

## 0. Ce qui décide de tout

1. **Aucune formule de probabilité n'est publique** (R§1.3). L'assistant ne prétend pas la
   connaître : il **apprend** les probabilités des issues qu'il observe, sur ce Mac, à partir d'un a
   priori prudent. Ce qui est sûr se calcule ; ce qui ne l'est pas se dit.
2. **Ce qui retire l'erreur humaine est déterministe** (R§0) : poids de chaque rune, compte du
   puits, plafonds d'over et d'exo, palier de rune (~20 × sa puissance), ordre (exo en dernier).
   C'est le cœur de la V1, et il ne dépend d'aucune probabilité.
3. **Le puits n'est jamais affiché** par le jeu (R§1.4) : il se reconstruit à partir des
   différences entre deux lectures de la table des effets.
4. **L'interface de FM de Dofus 3 n'est décrite nulle part** (R§6) : rien ne se calibre avant une
   capture réelle (étape F0).
5. **Licence de DofusDB à trancher avant tout** (R§3.1) : `api.dofusdb.fr` est sous LPNC-IA 1.0,
   qui exclut les projets produits à plus de 50 % par IA et interdit de rendre les données
   disponibles à un agent IA. **Cela concerne tout Synfus** (quêtes, carte, classes, boss), pas
   seulement la FM. Question 1.

## 0 bis. Ce que montre l'interface de Dofus 3 (captures du 25/11/2026)

Deux captures de l'utilisateur (Forgemager, une arme à deux lignes ; Costumager, une coiffe à
quinze lignes) corrigent la recherche sur deux points décisifs :

- **Le reliquat est affiché** : « reliquat : 0 », en italique au-dessus de « Fusionner tout »
  (grisé tant qu'aucune rune n'est posée). La recherche (R§1.4, R§6) le disait caché depuis la
  2.29 : en Dofus 3 il **se lit** par OCR. Le compte du puits n'est plus qu'un contrôle croisé avec
  l'historique, plus une reconstruction.
- **Le stock de runes est affiché** : à droite de chaque ligne, trois pastilles (rune simple, Pa,
  Ra) portent le **nombre de runes possédées** (ex. Vitalité 550 / 192 / 169 ; Portée 15 en simple
  seulement ; Résistance Terre : la rune seule, sans nombre lu). L'assistant sait donc ce que le
  joueur peut poser, sans saisie.

Disposition (à mesurer en F0, deux tailles de fenêtre) :

| Zone | Contenu |
|---|---|
| En-tête gauche | perso, métier (FORGEMAGE, COSTUMAGE…), niveau du métier |
| En-tête centre | « reliquat : N », trois cases (objet, rune, signature), « FUSIONNER TOUT », « FUSIONNER » |
| Colonne gauche | **Historique**, le plus récent **en bas** : icône de rune, puis « Échec », ou « +N Carac » en vert, ou « −N Carac » en rouge ; « Il n'y a pas d'historique actuellement. » quand vide ; « VIDER L'HISTORIQUE » en pied |
| Table centrale | colonnes Min, Max, Effets / Carac. (icône d'élément, valeur et nom : « 224 Vitalité », la ligne choisie encadrée), Modif. (dernière variation en pastille verte « +3 » ou rouge), Pa, Ra (stock de runes) ; une ligne d'arme « 9 à 11 dommages Eau » sur fond plein (non modifiable) |

Conséquences sur le plan :
- `fmEntete` (reliquat), `fmTable` (min, max, actuel, modif, stocks) et `fmHistorique` (dernières
  entrées, le bas d'abord) sont trois genres de lecture.
- Un gain s'écrit **sans « + »** dans l'historique (« 3 Chance » en vert), une perte « -10 Chance ».
- L'issue d'une fusion se déduit de la **variation de la table** (colonne Modif. comprise) et se
  recoupe avec la nouvelle entrée de l'historique et le reliquat lu.
- Le conseil s'appuie sur le stock lu : jamais une rune que le joueur n'a pas, ou l'achat à
  prévoir s'il en manque (« il te faut 3 Ra Vi de plus »).
- Le but se dit **par ligne** (« je veux 250 Vitalité, 60 Intelligence, 1 Portée ») et
  l'assistant donne l'étape suivante : « Pa Vi », « Ra Age », « attendre : le reliquat ne couvre
  pas cette rune ».

## 1. Modèle (pur, testable)

Nouveau domaine `Sources/Synfus/Forgemagie/` (ligne à ajouter au tableau d'`AGENTS.md`).

**`Forgemagie/Effets.swift` (pur)** — le poids par point de chaque caractéristique, une seule
source : `effectPowerRate` de DofusDB (`GET /effects`, vérifié sur 9 effets, R§3.2), gardé en
cache disque versionné comme les autres données (`DonneesDuJeu`) ; repli intégré sur la table de
R§1.1 si les données manquent. Plafond over+exo par ligne (R§1.1, dernière colonne).

**`Forgemagie/Rune.swift` (pur)** — une rune : caractéristique, rang (simple, Pa ×3, Ra ×10),
puissance, poids = puissance × poids par point. Liste tirée de `items?typeId=78` (105 runes) ;
fusion 3 → 1 du rang suivant.

**`Forgemagie/ObjetFM.swift` (pur)** — l'état : lignes (caractéristique, valeur, min, max naturels,
malus, over, exo), poids total, poids max (somme des `to × poids`), puits (réel ≥ 0, avec un drapeau
`incertain` quand la session a commencé avant l'observation, ou après équipement, échange, HDV).

**`Forgemagie/Issue.swift` (pur)** — déduit l'issue d'une fusion de deux lectures de la table
(R§5.2) : ligne visée montée seule → SC ; montée et d'autres baissées (ou « − reliquat ») → SN ;
pas montée → EC ; ajoute la ligne d'exo → exo. Met à jour le puits :
`puits += perte − poids de la rune` (jamais < 0, décimales gardées). **L'ordre des pertes reste
ouvert** (R§1.4, sources en désaccord) : il ne se code pas en dur, il se **constate** (quelle ligne a
baissé), et l'assistant le note.

**`Forgemagie/Probabilites.swift` (pur)** — P(SC, SN, EC | case) par comptage bayésien (Dirichlet)
sur des cases discrétisées : rapport jet/max (< 80 %, 80–100 %, over, exo), poids de la rune (léger,
moyen, lourd ≥ 30), poids total / poids max, niveau de l'objet par tranche. A priori : chiffres de
la 1.27 (R§1.3, faible poids) et bornes (SC ≥ 1 %, SN ≤ 50 %, exo lourde ~1 %). Comptes gardés sur
le Mac (`~/Library/Application Support/Synfus/forgemagie.json`), jamais envoyés.

**`Forgemagie/Conseil.swift` (pur)** — la décision, en V1 **heuristique explicable** (R§5.4) :
1. La cible du joueur : lignes voulues et minimum acceptable de chacune.
2. Ordre : lignes lourdes et précieuses, puis légères, over, **exo toujours en dernier**.
3. Rune du bon palier : simple tant que la ligne reste sous ~20 × sa puissance, Pa jusqu'à ~60,
   Ra au-delà (Vitalité : Pa vers 60, Ra vers 190–200).
4. Alertes : plafond over+exo de la ligne (et, selon la question 3, de l'objet) ; « ce SN risque de
   toucher la ligne X » quand le puits ne couvre pas le poids de la rune ; transcendance interdite
   avec over ou exo.
5. Chaque conseil dit **pourquoi** (« Pa Vi : la ligne est à 140, sous le palier Ra ») et ce qui est
   incertain.

V2 : décision par **espérance de coût** (processus de décision markovien sur états discrétisés) dès
que les probabilités apprises ont assez de comptes par case ; la V1 reste le repli.

**`Forgemagie/CoutSession.swift` (pur)** — coût d'une session en **nombre de runes** par rang
(toujours exact) et, si des prix sont connus, en kamas ; arbitrage de fusion (Pa = 3 simples,
Ra = 3 Pa) au prix de chaque rang. **Exo PA/PM/PO** : espérance géométrique à p ≈ 1 % (100 essais,
~300 pour 95 %), plus les runes de remontée après chaque échec, plus le puits à reconstituer ;
intervalle affiché, jamais un chiffre sec. Critère d'arrêt (R§5.5) : coût espéré pour finir > valeur
de l'objet fini, ou > objet neuf + FM depuis zéro.

## 2. Lecture de l'écran

- **F0. Captures** (geste de l'utilisateur, aucun code) : deux sont faites (§0 bis). Manquent :
  avant et après une fusion de chaque issue (SC, SN, EC) avec du reliquat non nul, une rune survolée
  (densité dans l'infobulle), un over et une exo, deux tailles de fenêtre. Elles décident les zones.
- Nouveaux genres de lecture (table `GenreLecture`, skill `lecture-ocr`) : `fmTable` (nom, min-max,
  actuel de chaque ligne) et `fmHistorique` (dernière entrée : issue, gains, pertes, reliquat).
  Lus **à la demande** tant que le panneau de FM est montré, jamais en continu, comme la chasse.
- Appariement texte → effet par les gabarits `description.fr/en/es` des effets (R§3.2), à une faute
  près (`Ressemblance`).
- Signal de l'issue le plus robuste : **la différence entre deux lectures de la table**, pas la
  couleur de l'historique (R§6).

## 3. Interface

- `Forgemagie/ForgemagiePanel.swift` : un `PanneauDeJeu` (cadre commun, pliage, redimensionnement)
  posé à côté de l'interface de FM du jeu, ouvert par la palette ou un bouton de la barre.
- Contenu : la rune conseillée en grand (nom, rang, pourquoi), le puits estimé (« ≈ 27, incertain »
  quand il l'est), les lignes avec cible / actuel / max et la prochaine alerte, le coût de la
  session (runes, kamas si prix connus). Une ligne copie le nom de la rune pour la chercher.
- La cible se règle dans le panneau (minimum voulu par ligne), gardée par objet.
- Aucune phrase d'explication sous les contrôles : le détail va en infobulle (`grille-ui`).

## 4. Lots

| Lot | Contenu | Fin |
|---|---|---|
| F0 | Captures de l'interface Dofus 3 (utilisateur) | Zones connues, notées dans un skill `forgemagie` |
| F1 (fait) | `CatalogueFM` (effets, runes), `ObjetFM`, `FusionFM` (issue, puits), `TexteFM` (historique, reliquat) + tests ; téléchargement et cache de DofusDB avec leur appelant (F3) | Puits recompté juste sur des historiques écrits à la main |
| F2 (fait) | `AtelierFM` : l'atelier retrouvé par l'en-tête de sa table (pas de zone calibrée ni de genre), fixtures textuelles de quatre captures | Table lue sur les captures F0 à l'identique |
| F3a (fait, à éprouver en jeu) | `ForgemagiePanel` : reliquat, issue de chaque fusion et compte de la séance, lignes et poids over/exo sur le plafond | Issues justes en jeu |
| F3b | `Conseil` heuristique : rune conseillée | En jeu : rune conseillée |
| F4 | `CoutSession` (runes, exo PA/PM/PO), prix estimé lu au survol d'une rune (OCR de l'infobulle) | Coût affiché avec son intervalle |
| F5 | `Probabilites` apprises + affichage des taux observés | Comptes persistés, a priori respecté sans données |
| F6 (V2) | Décision par espérance de coût  ; Dracorunes (3.8) | Sur mesures |

Tests (Swift Testing, logique pure) : poids d'une rune par rang ; puits sur des séquences SC/SN/EC
écrites à la main (jamais < 0, décimales) ; issue déduite de deux tables ; palier de rune ; plafonds ;
ordre « exo en dernier » ; coût géométrique de l'exo ; mise à jour bayésienne et bornes de l'a priori.

Skills : nouveau skill `forgemagie` (`user-invocable: false` : modèle, pièges, contradictions
ouvertes, zones) ; `lecture-ocr` (deux genres) ; `AGENTS.md` (domaine `Forgemagie/`, foyers poids
`Effets`, puits `Issue`, conseil `Conseil`).

## 5. Questions à trancher par l'utilisateur

1. **Licence DofusDB (LPNC-IA 1.0)** : continuer à s'en servir pour tout Synfus, demander une
   autorisation à DofusDB, ou passer à d'autres données (fichiers du client, saisie) ? C'est le
   préalable de tout le reste.
2. ~~Prix des runes~~ : tranché (26/11/2026) — le **prix estimé** que le jeu affiche dans
   l'infobulle d'un objet survolé, lu par OCR ; il suffit. Ni saisie ni HDV.
3. **Plafond de 101** : par ligne ou par objet ? Les sources se contredisent (R§1.5) : à vérifier
   en jeu (une exo PM + un over sur un même objet).
4. **Ordre des pertes** et cas où le puits se perd (HDV, échange, équipement) : à constater en jeu,
   ou à demander à la communauté ?
5. **Exo PA/PM/PO** : objectif prioritaire de la V1, ou après les jets ordinaires ?
6. **Dracorunes (3.8)** : à suivre dès leur sortie, ou à part ?
