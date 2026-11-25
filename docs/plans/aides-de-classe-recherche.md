# Huppermage : combinaisons élémentaires, et mécaniques implicites des autres classes

Recherche du 25/11/2026. Source principale : **les données du client relayées par DofusDB**
(`api.dofusdb.fr`, interrogée en direct, donc la version publiée de Dofus 3). Les guides web
(Breakflip, Next-Stage, JOL, Millenium) décrivent surtout Dofus 2.x et donnent d'**autres valeurs**.

Confiance : **H** = lu dans les données DofusDB (effets ou description du sort) ; **M** = déduit
des données ou recoupé par une seule source ; **B** = souvenir de jeu ou supposition, à vérifier
en jeu.

---

## 1. Huppermage

### 1.1 Vocabulaire du jeu actuel (H)

| Notion | FR | EN | ES | Où dans DofusDB |
| --- | --- | --- | --- | --- |
| État posé sur la cible par un sort élémentaire | **État élémentaire** (états « Feu », « Eau », « Terre », « Air ») | Elemental State (Fire/Water/Earth/Air) | Estado elemental (Fuego/Agua/Tierra/Aire) | spell-states **290** Feu, **291** Eau, **292** Terre, **293** Air ; sort technique 32415 « État Élémentaire » (les retire tous) |
| Ce que produisent deux états différents | **Combinaison élémentaire** (« Combinaisons Élémentaires ») | Elemental Combination | Combinación elemental | sort explicatif **23876** ; résolveur **13671** ; une combinaison = un sort **13702–13707** |
| Glyphe au sol posé par chaque sort élémentaire | **Rune** (« Rune d'Air »…), dure **2 tours** | Rune | Runa | sorts 13685/13689 « Rune d'Air » (effet 2022 « Pose une rune », durée 2) ; états 296, 6969–6973 (rangs de rune) |
| Élément de la dernière rune posée (sur le lanceur) | « Dernière rune : Feu/Eau/Terre/Air » | Last Rune: … | Última Runa: … | spell-states **701–704** (non silencieux) |
| Passif / état de classe | « Manifestation » / « Manifestation Huppermage » | Huppermage Manifestation | Manifestación Hipermaga | spell-states 600, 3647 (silencieux = invisibles) |
| Compteur de combinaisons du lanceur | « Torrent Arcanique 1/6 … 6/6 » | Arcane Torrent 1/6… | Torrente Arcano 1/6… | spell-states **2011–2016** (icônes `stateTorrentArcaniqueI…VI`), sort 14342 |

Donc : **« état élémentaire »** pour ce que porte la cible, **« rune »** pour le sol,
**« combinaison élémentaire »** pour l'effet. « Manifestation » n'est pas un terme que le joueur
manipule (état caché).

### 1.2 Qui porte quoi (H)

- **L'état élémentaire est porté par la créature ciblée** (ennemi, et aussi allié : les masques
  de cible du résolveur sont `a,A`), pas par la cellule ni par le lanceur. Durée **infinie**
  (`duration -1`) jusqu'à consommation. Icônes `stateFire`/`stateWater`/`stateEarth`/`stateAir`,
  `iconVisibilityMask 3` : visible dans la liste d'états de la cible.
- **La rune est sur la cellule**, 2 tours ; c'est elle que Runification / Surcharge Runique
  déclenchent. Elle ne participe pas aux combinaisons.
- **Le lanceur** porte « Dernière rune : X » (utile à Cycle Élémentaire sur une cible vierge),
  le bonus de Puissance des combinaisons et le compteur Torrent Arcanique.
- Un sort élémentaire n'applique son état que si la cible **ne l'a pas déjà** (condition `e293`
  dans « État Air ») : même élément deux fois = **rien** (ni combinaison, ni cumul).
- Dès que la cible porte **deux états différents**, le résolveur lance la combinaison
  correspondante, qui **consomme tous les états élémentaires** de la cible. Une cible ne porte
  donc jamais plus d'un état « au repos ».
- **L'ordre ne compte pas** : chaque combinaison est testée sur la paire d'états (`E292,E290`
  pour Terre & Feu), et le texte du jeu écrit « Terre & Feu ». Terre puis Feu = Feu puis Terre.

### 1.3 Table complète (H pour noms, cibles et valeurs ; M pour les durées marquées *)

Effets communs à toute combinaison : **lanceur +50 Puissance pendant 3 tours** ; « les effets
sont cumulables une fois par combinaison » (6 combinaisons distinctes → jusqu'à +300 Puissance) ;
le lanceur avance d'un cran de Torrent Arcanique. Les états élémentaires de la cible sont consommés.

| Cible porte → on applique | Combinaison FR / EN / ES | Effet sur la cible (valeur, durée) | Sort |
| --- | --- | --- | --- |
| Feu → Feu, Eau → Eau, etc. | (aucune) | Rien : l'état n'est pas réappliqué | — |
| Terre → Feu, ou Feu → Terre | **Éruption** / Eruption / Erupción | Dommages subis **×115 %** (+15 %), *1 tour | 13707 (lv 42517) |
| Terre → Eau, ou Eau → Terre | **Enlisement** / Bogged Down (nom du sort : « Stymation ») / Hundimiento | **−3 PM**, 1 tour | 13704 (lv 42514) |
| Feu → Air, ou Air → Feu | **Carbonisation** / Carbonisation / Carbonización | **−2 PA**, 1 tour | 13703 (lv 42513) |
| Eau → Feu, ou Feu → Eau | **Ébullition** / Boiling Point / Ebullición | **−60 Fuite**, 1 tour | 13702 (lv 42512) |
| Eau → Air, ou Air → Eau | **Cristallisation** / Crystallisation / Cristalización | **−15 % dommages finaux** infligés, 1 tour | 13706 (lv 42516) |
| Air → Terre, ou Terre → Air | **Assèchement** / Drying Out / Desecación | **Vol de 3 Portée**, 1 tour | 13705 (lv 42515) |

Notes :
- Les retraits PA/PM sont des effets 1079/1080 (« −#1 PA/PM »), **non esquivables** d'après le
  type d'effet (M) — Dofus 2 les donnait esquivables.
- Éruption est codée « Dommages subis x115 % » avec déclencheur `D` et durée 0 : la durée exacte
  (1 tour ou prochaine attaque) est à confirmer en jeu (M/B).
- Incohérence anglaise interne au jeu : le sort 13704 s'appelle « Stymation », la description
  de 23876 dit « Bogged Down » (H). Garder le nom du sort pour un libellé de sort.
- Chaque combinaison a un état « {{Combinaison}} inactif/inactive » non silencieux
  (spell-states **3746–3751**) ; même schéma que « Téléfrag inactif : Distorsion » (3719) chez
  Xélor. Probablement l'indicateur que le bonus de cette combinaison est déjà pris (B).

### 1.4 Sorts qui lisent ou changent l'état (H, descriptions DofusDB)

- **Cycle Élémentaire** (13722) : Terre → Eau → Feu → Air → Terre ; sur cible vierge, applique
  l'élément de la dernière rune ; PA remboursés au premier changement. Le seul moyen de
  « choisir » la combinaison sans frapper.
- **Polarité** (13696) : consomme l'état. Terre repousse, Feu échange, Eau attire, Air téléporte
  symétriquement.
- **Propagation** (13695) : propage l'état aux ennemis en zone. Terre −Résistances Poussée,
  Feu −Critiques, Eau −Fuite, Air −Tacle.
- **Contribution** (13701) : buff sur l'allié selon les états de *tous* les ennemis
  (Terre PM, Feu bouclier, Eau Puissance, Air PA), consomme tout.
- **Drain Élémentaire** (13672), **Traversée** (13683) : effet selon l'état de la cible.
- **Bouclier Élémentaire** (13682) : l'attaquant de l'allié protégé reçoit l'état de l'élément
  de son attaque, ce qui peut déclencher une combinaison sans action de l'Huppermage.

### 1.5 Ce que le jeu montre déjà

- **Icône d'état** sur la cible (liste d'états, timeline, infobulle au survol) : oui (H pour
  l'icône et son masque de visibilité ; M pour l'affichage exact dans l'interface Unity).
- **Prévisualisation de la combinaison** au survol d'un sort : rien dans les données ne la
  porte ; le jeu prévisualise les dommages, pas les effets déclenchés par un sort lancé en
  cascade (`1160` = « lance le sort X »). Très probablement **pas** de prévisualisation (B).
- **Journal de combat** : un état non silencieux posé ou retiré y est généralement écrit, et
  l'effet de la combinaison (−PA, −PM, vol de PO) y apparaît comme tout effet (M/B).

**Intérêt d'une aide** : faible à moyen pour un Huppermage expérimenté (la table tient en
6 lignes), réel pour un débutant ou un allié qui veut savoir « si je frappe Feu sur ce monstre
marqué Terre, il prend +15 % ». Le plus simple et le plus robuste : une **table statique** dans
l'app (aucune lecture d'écran), éventuellement « état lu → ce que donne chaque élément ».

### 1.6 Dofus 2.x : différences (M, Next-Stage du 04/06/2025, guides 2.x)

Même structure (6 paires réciproques, état indéfini sur la cible, rune 2 tours), **valeurs
différentes** : Feu+Terre +20 % dommages subis ; Feu+Eau −50 Fuite ; Feu+Air −3 PA esquivables ;
Terre+Eau −2 PM esquivables ; Terre+Air vol de 3 PO ; Eau+Air −25 % dommages infligés. Les noms
Éruption, Enlisement… n'apparaissent dans aucun guide 2.x trouvé : ils semblent propres à
Dofus 3. Torrent Arcanique, Cycle Élémentaire, Propagation, Contribution existaient en 2.x sous
d'autres formes (B).

### 1.7 Endpoints DofusDB utiles

- `GET https://api.dofusdb.fr/spell-states/{290|291|292|293}` : états élémentaires (noms fr/en/es, icône).
- `GET https://api.dofusdb.fr/spells/23876` : texte officiel de la table, fr/en/es (meilleure source
  pour les libellés de l'app ; contient des balises `<sprite name="feu">` à remplacer).
- `GET https://api.dofusdb.fr/spells/{13702..13707}` + `spell-levels/{42512..42517}` : chaque
  combinaison et ses valeurs. `spells/13671` : la table paire → combinaison.
- `GET https://api.dofusdb.fr/breeds?id=17` : sorts de l'Huppermage (`breedSpellsId`).
- `GET https://api.dofusdb.fr/effects/{id}` : gabarit texte d'un effet (`#1`, `#3`).
- Filtre utile : `spell-states?name.fr[$regex]=Huppermage` (curl avec `-g`).

---

## 2. Autres classes : mécaniques implicites

Contrainte rappelée : l'app ne peut que **lire l'écran** (OCR des états, de la timeline, du
canal combat). Elle ne voit pas les glyphes/pièges des autres, ni les cellules, sauf par
reconnaissance d'image.

| Classe | Mécanique implicite | Le jeu montre | Intérêt d'une aide | Déductible par l'écran seul ? |
| --- | --- | --- | --- | --- |
| **Roublard** | Bombes (invocations) reliées en murs, combo qui monte (« Combo I…XII », 2484–2493/2529–2530), explosion en chaîne (Kaboom) dont les dégâts dépendent du combo et des murs | Les bombes, leurs murs, une icône de combo sur la bombe | **Élevé** : les dégâts d'une explosion en chaîne ne sont pas prévisualisés (M/B) | Partiellement : le niveau de combo est un état à icône (lisible au survol) ; la géométrie des murs, non |
| **Xélor** | Téléfrag (échange de place entre deux entités d'une même action) qui déclenche des effets bonus, une fois par tour par sort (états « Téléfrag inactif : … », p. ex. 3719) ; Synchro qui accumule les téléfrags (état « Synchronisé » 306) | État « inactif » après usage ; la Synchro et ses charges | **Moyen-élevé** : savoir quels bonus de téléfrag restent ce tour | Oui en grande partie : états non silencieux sur le Xélor, lisibles en OCR de sa liste d'états (M) |
| **Ouginak** | Proie I–IV (1813–1816) marquée sur un ennemi, Rage (513) et formes Rage Feu/Eau/Air/Terre (2726–2729) | Icônes d'état | Moyen : compte des charges de Proie et de la Rage restante | Oui : états visibles et numérotés (H pour les états, M pour l'OCR) |
| **Zobal** | Masques (Pleutre 2395, Intrépide 2396, Psychopathe 2397) changeant les effets des sorts ; bonus quand on change de masque | État du masque | Faible : un seul état, déjà clair | Oui, mais peu utile |
| **Forgelance** | Lance lancée puis à récupérer ; « Lance en rechargement » (3657) | La lance au sol, l'état | Moyen : quand la lance redevient utilisable, quels sorts sont bloqués | Partiellement : l'état oui, la position de la lance non |
| **Eliotrope** | Portails (état « Portail » 248) : un sort traversant des portails gagne des dommages selon le nombre et la distance ; ordre de passage | Le jeu **trace** déjà le chemin entre portails au survol (B : vrai en 2.x) | Faible si le tracé existe | Non sans lire la carte |
| **Sram** | Pièges invisibles des ennemis, combo de pièges (déclenchement en chaîne, poussée vers un autre piège) | Les pièges pour le Sram et ses alliés | Moyen : enchaînements | Non : demande la géométrie |
| **Steamer** | Tourelles (Bonus Tourelle 2428), évolution et bonus selon les alliés/ennemis adjacents | Les tourelles, quelques états | Moyen | Partiellement |
| **Osamodas** (refonte 3.x) | Invocations et états du lanceur selon l'invocation (Tofu, Bouftou, Crapaud, Dragonnet…) qui modifient les sorts suivants | Icônes d'état sur le lanceur | Moyen pour les débutants | Oui si états non silencieux (B) |
| **Pandawa** | Saoul (2416) qui change l'effet des sorts, porter/jeter, ivresse des alliés | État Saoul, l'entité portée | Faible | Oui |

**Ce qui marche le mieux pour une app externe**, par ordre d'effort :
1. **Fiches statiques** (comme la table Huppermage) tirées de DofusDB (`spells/{id}`,
   `spell-states/{id}`), affichées à la demande : aucune lecture, traduites fr/en/es par les
   données mêmes. Huppermage, Xélor (bonus de téléfrag par sort), Roublard (palier de combo).
2. **OCR d'icônes/états du perso joué** (sa propre liste d'états) : Torrent Arcanique, Proie,
   Rage, Téléfrag inactif, Combo. Faisable mais l'icône sans texte demande une reconnaissance
   d'image ; le texte n'apparaît qu'au survol (qu'on ne provoque pas : pas d'évènement émis).
3. **Canal combat** : les états posés/retirés et les effets (−PA, vol de PO) y sont écrits en
   texte (M/B), seule voie textuelle fiable pour suivre l'état d'**une cible ennemie**. Coût :
   associer le nom de la cible au monstre visé.
4. Tout ce qui demande la géométrie (murs de bombes, portails, pièges) : hors de portée.

---

## Sources

- DofusDB, API publique (lue le 25/11/2026) : `https://api.dofusdb.fr/spells/23876`,
  `/spells/13671`, `/spells/13702`…`13707`, `/spell-levels/42512`…`42517`,
  `/spell-states/290`…`293`, `/spell-states?name.fr[$regex]=Huppermage`, `/spells/13722`,
  `/spells/13696`, `/spells/13695`, `/spells/13701`, `/spells/14342`, `/breeds?id=17` (H).
- Next-Stage, table des combinaisons (Dofus 2.x, 04/06/2025) : https://www.next-stage.fr/?p=223058 (M).
- Breakflip, guide des sorts de l'Huppermage (2.x) :
  https://www.breakflip.com/fr/dofus/guide/dofus-guide-des-sorts-et-variantes-de-l-huppermage-2273 (M).
- JOL, « La rune de l'Huppermage » : https://dofus.jeuxonline.info/article/14143/rune-huppermage (M).
- Gamosaurus, équilibrages 2.70 : https://www.gamosaurus.com/?p=201759 (M).
- Guidactik, Huppermage sur Dofus Unity :
  https://guidactik.com/dofus/les-meilleurs-stuff-et-guide-huppermage-sur-dofus-unity/ (M).
- Dofus pour les noobs et l'encyclopédie Ankama n'ont pas été lus : les données DofusDB, issues
  du client, les rendent redondantes pour les valeurs.
