# Forgemagie (FM) de Dofus : recherche pour un assistant de forgemagie

Recherche faite le 25/11/2026, sur la version 3.7 en ligne ; la 3.8 (Dracorunes) est annoncée pour début décembre 2026.
But : préparer un assistant qui lit l'écran, recommande la rune suivante et n'agit jamais à la place du joueur.

## Légende de confiance

- **[OFF]** : officiel (Ankama, devblog, notes de mise à jour) ou donnée du client exposée par DofusDB.
- **[COM+]** : consensus communautaire stable, repris par plusieurs guides indépendants.
- **[COM-]** : une seule source communautaire, ou sources en désaccord.
- **[HIST]** : chiffre ancien (Dofus 1.27, 2009), jamais confirmé en Dofus 2 ou 3.
- **[SUP]** : supposition ou inférence de ma part.

**Limite de méthode.** Les pages ont été lues au travers d'un résumé automatique, pas recopiées. Les tableaux ci-dessous sont donc « rapportés par » la source citée. Les seules données relevées à la main sont les champs DofusDB (§3).

---

## 0. Ce qui compte pour l'algorithme

1. **Aucune formule de probabilité n'est publique.** Ankama ne l'a jamais publiée, et les simulateurs (Dofus Fashionista, ForgeMagix) le disent eux-mêmes. Les seuls chiffres sourcés datent de la 1.27 (2009). Un assistant fiable doit donc **estimer les probabilités à partir des issues qu'il observe**, au lieu de s'appuyer sur une formule.
2. **La partie déterministe est connue et suffit à retirer l'erreur humaine** : poids par caractéristique (lisible dans DofusDB, `effectPowerRate`), comptabilité du puits, plafonds d'over et d'exo, palier de rune « ~20 × la puissance ». L'erreur humaine en FM, c'est surtout un puits mal compté, une rune trop lourde ou trop légère, et l'oubli des plafonds. Tout cela se calcule.
3. **Le puits n'est jamais affiché**, par choix d'Ankama (2.29). Il se reconstruit à partir de l'historique de l'interface, ce que l'OCR permet.
4. **L'interface de FM de Dofus 3 (Unity) n'est décrite nulle part** : aucune capture ni description trouvée. Il faut faire une capture réelle avant de calibrer l'OCR.
5. **La licence de DofusDB (LPNC-IA 1.0) pose un problème à trancher par l'utilisateur** (§3.1).

---

## 1. Mécanique

### 1.1 Puissance et poids (densité)

- Chaque caractéristique a un **poids par point**. Le poids d'une rune vaut sa puissance multipliée par le poids par point de la caractéristique. **[COM+]** Sources : [JOL](https://dofus.jeuxonline.info/article/3736/forgemagie), [Gamosaurus](https://www.gamosaurus.com/?p=118767), [Fashionista D3](https://dofusfashionista.gg/fr/forgemagie/).
- Depuis la 2.58, l'infobulle d'une rune affiche sa **« Densité »**, c'est-à-dire son poids. **[OFF]** Sources : [JOL 2.58](https://dofus.jeuxonline.info/actualite/58753/dofus-258-amelioration-confort-forgemages), [Gamosaurus](https://www.gamosaurus.com/?p=118767).
- Il y a trois rangs de rune : la rune simple, la **Pa** (×3) et la **Ra** (×10). Trois runes d'un rang se fusionnent en une rune du rang suivant. **[COM+]**

Le tableau suivant croise trois sources : Fashionista, qui dit couvrir Dofus 3 jusqu'à la 3.7.14.18, l'article JOL et DofusDB (champ `effectPowerRate`, relevé à la main, ✔ dans le tableau).

| Caractéristique | Poids/point | Runes (puissance) | Plafond over+exo de la ligne |
|---|---|---|---|
| Force, Intelligence, Chance, Agilité | 1 ✔ | 1 / 3 / 10 | +101 |
| Vitalité | 0,2 ✔ | 5 / 15 / 50 | +505 |
| Initiative | 0,1 ✔ | 10 / 30 / 100 | +1010 |
| Pods | 0,25 ✔ | 10 / 30 / 100 | +404 (Millenium : 400) |
| Sagesse | 3 ✔ | 1 / 3 / 10 | +33 |
| Prospection | 3 | 1 / 3 | +33 |
| Puissance | 2 | 1 / 3 / 10 | +50 |
| Dommages élémentaires, Dommages critiques, Dommages de poussée | 5 | 1 / 3 | +20 |
| Dommages fixes (« Do ») | 20 ✔ | 1 | +5 |
| Résistance fixe élémentaire, Résistance aux critiques, Résistance à la poussée | 2 | 1 (/3) | +50 |
| Résistance élémentaire en % | 6 | 1 | +16 |
| Tacle, Fuite | 4 | 1 / 3 | +25 |
| Retrait PA/PM, Esquive PA/PM | 7 | 1 / 3 | +14 |
| Coups critiques en %, Soins | 10 | 1 | +10 |
| Dommages et résistances en % (mêlée, distance, sorts, armes) | 15 | 1 | +14 (Millenium) |
| Invocations | 30 | 1 | +3 |
| Portée (PO) | 51 ✔ | 1 | +1 |
| PM (rune Ga Pme) | 90 ✔ | 1 | +1 |
| PA (rune Ga Pa) | 100 ✔ | 1 | +1 |

Écarts entre sources :

- **Vitalité** : 0,25 chez [jeuxend](https://www.jeuxend.com/blog/dofus-3-7-forgemagie-potions-100-armes-soin-gemmes), 0,2 partout ailleurs, DofusDB compris. **Retenir 0,2.** **[OFF]**
- **Rune Ra Puissance** : JOL donne un poids de 30 pour une puissance de 10, sans doute une coquille (on attendrait 20). **[COM-]**
- **Dommages fixes** : poids 20 dans DofusDB et chez JOL. **[OFF]**

### 1.2 Les trois issues d'une rune

| Issue | Couleur dans l'historique (2.x) | Effet |
|---|---|---|
| Succès critique (SC) | vert | La rune s'applique et **rien n'est perdu**. Le puits ne bouge pas. |
| Succès neutre (SN) | jaune | La rune s'applique, et l'objet perd environ **le poids de la rune** ailleurs (dans le puits d'abord, voir §1.4). |
| Échec critique (EC) | rouge | La rune ne s'applique pas, et l'objet perd environ le poids de la rune. |

- **[COM+]** Sources : [JOL](https://dofus.jeuxonline.info/article/3736/forgemagie), [Gamosaurus](https://www.gamosaurus.com/?p=118767), [Millenium](https://www.millenium.org/guide/282643.html), [Tofus](https://www.tofus.fr/fiches/forgemagie).
- Si aucune ligne n'a un poids équivalent, **la perte peut dépasser** le poids de la rune. **[COM-]** Source : Gamosaurus.
- Les guides décrivent aussi un « SN où rien n'est ajouté ni perdu » (variante d'EC sans perte). **[COM-]** Source : JOL.
- Une ligne en **malus** ne coûte que la moitié du poids de la rune, sauf pour le passage de −1 à 0. **[COM-]** Source : Gamosaurus.
- Un malus peut être annulé mais ne devient jamais un bonus. **[HIST]** et **[COM+]**

### 1.3 Probabilités : ce qui est connu

**Aucune formule officielle.** Ankama a refusé d'afficher les probabilités (2.29) pour garder la place de l'expertise du joueur. **[OFF]** Source : [JOL 2.29](https://dofus.jeuxonline.info/actualite/48173/mise-jour-229-refonte-interface-forgemagie). Dofus Fashionista écrit qu'Ankama « n'a jamais publié la formule exacte ».

Facteurs cités par la communauté, sans pondération connue **[COM+]** :

- le poids de la rune (plus il est lourd, plus l'échec est probable) ;
- l'écart entre le jet actuel de la ligne et son maximum naturel ;
- le **poids total de l'objet comparé à son poids maximal** (la somme des jets max) ;
- le niveau de l'objet (cité par Tofus, **[COM-]**).

Sources : [Tofus](https://www.tofus.fr/fiches/forgemagie), [Gamosaurus](https://www.gamosaurus.com/?p=118767), [forum JOL, sujet sur l'algorithme](https://forums.jeuxonline.info/sujet/1388548/question-sur-l-algorithme-de-la-forgemagie) (page en 402, lue par extrait de recherche : la question y reste ouverte).

**Chiffres historiques [HIST]** : tests de la 1.27 (2009) pour un maître forgemage, rapportés par le [blog de la guilde Yin-Yang](https://yin-yang.over-blog.com/article-29549211.html) qui cite le devblog de l'époque.

| Situation | SC | SN | EC |
|---|---|---|---|
| Remonter un effet simple (objet ordinaire) | 66 % | 34 % | 0 % |
| Bonus simples, vers le jet parfait | 34 % | 50 % | 16 % |
| Remonter des bonus max sur un objet complexe | 15 % | 50 % | 35 % |
| Créer un effet avec du puits | 1 % | 22 % | 77 % |
| Créer un effet sans puits | 1 % | 0 % | 99 % |

Règles qui accompagnent ces chiffres **[HIST]** :

- La difficulté est constante sous **80 % du jet max naturel**, puis augmente jusqu'à 100 %, et très fort au-delà (over et exo).
- Le **SN plafonne à environ 50 %**.
- Le **SC vaut au moins 1 %**, sauf quand l'opération est impossible.
- Le « power-rate » de l'effet et de l'objet entre dans le calcul.

Règles empiriques actuelles :

- **Palier de rune** : une rune passe bien tant que la ligne reste sous environ **20 × la puissance de la rune**. On utilise donc la rune simple jusqu'à ~20, la Pa jusqu'à ~60, puis la Ra. **[COM+]** Sources : Tofus, Fashionista, Gamosaurus.
- **Le « 1 % seul »** : une ligne qui dépasserait son jet de **30 de poids ou plus** ne passe qu'en SC, à environ 1 %. C'est le cas des exos PA, PM, PO et Invocation. **[COM-]** Source : [Fashionista](https://dofusfashionista.gg/fr/forgemagie/). Next-stage donne un seuil de **plus de 20** de densité sur une stat absente ([next-stage](https://www.next-stage.fr/2026/03/runes-transcendance-dofus-comment-elles-fonctionnent-comment-utiliser.html)). **Contradiction ouverte.**
- **Exo à 1 %** : chiffre cité par toutes les sources. **[COM+]**

**Conclusion pour le modèle** : les probabilités de SC, SN et EC sont une fonction inconnue de plusieurs variables : (jet/max de la ligne, poids de la rune, poids total/poids max de l'objet, over ou exo, niveau). Les seules valeurs connues sont les bornes : SC ≥ 1 %, SN ≤ 50 %, exo lourde à environ 1 %.

### 1.4 Puits (reliquat)

- **Définition** : quand une perte retire plus de poids que la rune n'en pèse, la différence est mise en réserve. Formule : **puits += poids perdu − poids de la rune** (ex. une rune de 3 qui fait perdre une ligne de 30 laisse 27). **[COM+]**
- Il **s'additionne**, et les pertes suivantes le consomment jusqu'à 0. Il ne descend jamais sous 0 : au-delà, la perte retombe sur les lignes. Les décimales sont gardées. **[COM+]** Sources : Tofus, Millenium, Gamosaurus.
- Un **SC ne touche pas** le puits. Un SN ou un EC le consomme. **[COM+]**
- Le puits sert aussi à **payer l'over et l'exo** : dépasser un jet ou ajouter une ligne puise dans le puits au lieu d'arracher d'autres lignes. **[COM+]** Source : Fashionista.
- **Quand il est perdu** : ça dépend de la source. **[COM-]**
  - Mise en HDV : toutes les sources.
  - Échange : Gamosaurus.
  - Objet équipé : Tofus, Fashionista.
  - Inventaire de monture : Gamosaurus.
  - Il survit à la déconnexion : Tofus, Gamosaurus.
- Un **orbe régénérant** réinitialise l'objet (jets refaits, puits effacé). **[COM+]** Sources : Millenium, Fashionista.
- **Ordre des pertes** : les sources ne sont pas d'accord. **[COM-]** Contradiction à garder ouverte dans le modèle.
  - JOL : puits d'abord, puis over et exo, puis les lignes de même poids que la rune.
  - Tofus et une source synthétisée par la recherche : **exo, puis over, puis puits, puis les autres lignes**, si la ligne de l'échec n'est pas elle-même l'over ou l'exo.
  - Conséquence pratique, sur laquelle tout le monde s'accorde : **on pose l'exo en dernier**.
- L'historique affiche « − reliquat » quand une rune a consommé du puits. **[COM-]** Source : Millenium. « + reliquat » serait le symétrique **[SUP]**.

### 1.5 Over, exo, plafonds

- **Over** : une ligne au-dessus de son jet max naturel. **Exo** : une ligne absente de l'objet. **[COM+]**
- **Plafond de poids par ligne** : la somme over + exo d'une ligne ne dépasse pas **101** de poids, sauf si le jet naturel est déjà au-dessus. **[COM+]** Sources : Tofus, Fashionista, Gamosaurus (« 101 × l'effet de la rune »). Next-stage écrit aussi 100 à un autre endroit (incohérent).
- **Plafond de 101 par objet** : Tofus écrit que **la somme des exos et overs de l'objet** ne dépasse pas 101. Il en déduit qu'on ne peut pas avoir deux PA (100 + 100), mais qu'un PM (90) laisse 11 de poids d'over. **[COM-]** Fashionista parle d'un plafond **par ligne**. **Ces deux lectures sont incompatibles** et changent la planification : à vérifier en jeu.
- **« Une seule exo PA/PM/PO » par personnage** (porté), pas par objet. **[COM-]** Source : Gamosaurus. C'est une règle d'équipement, distincte du plafond de poids.
- **Un over est perdu en premier** en cas de SN ou d'EC. **[COM+]**
- **Transcendance** : la rune passe à 100 % mais **verrouille l'objet**. Elle est interdite si l'objet a un over ou une exo, et le poids de la ligne plus la rune doit rester ≤ 101. Depuis la **3.7**, un orbe régénérant retire la transcendance en réinitialisant l'objet ; la rune est perdue. **[OFF]** pour la 3.7 (relayé par [DPLN](https://www.dofuspourlesnoobs.com/mise-a-jour-307.html) et jeuxend, devblog non consulté). Le reste est **[COM+]**. Sources : [next-stage](https://www.next-stage.fr/2026/03/runes-transcendance-dofus-comment-elles-fonctionnent-comment-utiliser.html), Gamosaurus.

---

## 2. Exo PA / PM / PO

- **Probabilité** : environ **1 % par essai, SC seulement**. **[COM+]** **[HIST]** (1 % de SC en 1.27).
- Selon la 1.27, le puits ne change pas le SC (1 %) mais permet des SN : 22 % avec puits contre 0 % sans. **[HIST]**
- **Ce que le puits apporte aujourd'hui** **[COM+]** : chaque essai raté (Ga Pa = 100 de poids, Ga Pme = 90, Po = 51) **arrache son poids**. Avec du puits, c'est lui qui paie, et l'objet garde ses jets. Gamosaurus écrit que les exos lourdes « n'ont pas besoin de puits » : le SC ne coûte rien, mais sans puits chaque échec abîme l'objet.
- **Méthode classique** (Gelano exo PM, Gamosaurus) **[COM+]** :
  1. Créer un gros puits en faisant tomber une ligne lourde (perdre le PA d'origine donne environ 100 de puits).
  2. Remonter ou poser ce qu'on veut.
  3. Lancer les runes d'exo **en dernier**.
  4. Quand le puits est épuisé, remonter les lignes, ce qui peut recréer du puits, puis recommencer.
- **Coût** : à 1 %, l'espérance est de **100 essais** (géométrique ; 95 % de chance de réussir en environ 300 essais). Il faut ajouter les runes de remontée après chaque perte. Les guides insistent sur une réserve de kamas. **[SUP]** pour le calcul, **[COM+]** pour la mise en garde.

---

## 3. Données disponibles par API (DofusDB)

### 3.1 Licence : à trancher par l'utilisateur

`https://api.dofusdb.fr/` renvoie la **« LPNC-IA 1.0 »** (2026). Extraits du texte :

- usage **non commercial** seulement ;
- attribution obligatoire : « Données issues de DofusDB. Utilisation soumise à la LPNC-IA 1.0. » ;
- partage aux mêmes conditions ;
- §4.2 : sont **exclus du champ de la licence** les projets « dont la structure, le code, le contenu ou la logique a été produit en majorité (plus de 50 %) par des outils d'IA » ;
- §4.2 : il est **interdit** de « rendre les données disponibles à tout système d'IA, agent autonome ou bot d'apprentissage automatique » ;
- le titulaire peut **révoquer** la licence.

Cela concerne Synfus dans son ensemble, pas seulement l'assistant de FM. C'est un arbitrage pour l'utilisateur. Pour la même raison, cette recherche s'est arrêtée après quelques requêtes de relevé.

### 3.2 Champs relevés (requêtes manuelles, 25/11/2026)

- **`GET /effects?id=<effectId>`** : le champ **`effectPowerRate` est le poids par point**. Vérifié sur 9 effets : 118 Force = 1 ; 125 Vitalité = 0,2 ; 111 PA = 100 ; 128 PM = 90 ; 117 Portée = 51 ; 124 Sagesse = 3 ; 112 Dommages = 20 ; 158 Pods = 0,25 ; 174 Initiative = 0,1. **[OFF]** sur ces 9 effets. Pour les autres, c'est **très probable, mais non vérifié**.
  - Autres champs utiles : `characteristic` (identifiant de caractéristique), `bonusType`, `effectPriority` (ordre d'affichage), `oppositeId`, `description.fr` (gabarit du libellé, ex. `#1{{~1~2 à }}#2 Force`, utile pour apparier le texte lu par l'OCR).
- **`GET /items?typeId=78`** : les **runes de forgemagie** (105 objets). Exemple : id 1519, « Rune Fo », `effects:[{from:1, characteristic:10, effectId:118}]`. **Pas de champ poids** : le poids se déduit de `from` × `effectPowerRate`. Il n'existe **pas d'endpoint `/runes`** (404).
- **`GET /items?id=<id>`** : un équipement porte `effects[]` avec `from`, `to`, `effectId`, `characteristic`. Pour un équipement, `from` = min et `to` = max du jet **[SUP]** (convention connue, mais observée seulement sur une rune ici). Autres champs : `level`, `typeId`, `itemSetId`.
- **`GET /characteristics`** : 123 caractéristiques (`keyword`, `name`, `categoryId`).
- **Ce qui n'est nulle part** :
  - le **prix des runes en HDV** : aucune API officielle ni communautaire trouvée ;
  - le **poids maximal de l'objet** : il se calcule comme la somme des `to × effectPowerRate`, en tenant compte des malus **[SUP]** ;
  - toute **probabilité**.

---

## 4. Stratégies reconnues et coût

- **Ordre des runes** **[COM+]** :
  1. D'abord les lignes lourdes et précieuses.
  2. Puis les lignes légères, avec la rune du bon palier (~20 × la puissance).
  3. Over ensuite.
  4. **Exo toujours en dernier**, parce qu'elle part la première aux pertes.
- **Simple, Pa ou Ra** : passer au rang supérieur vers 20 × la puissance de la rune courante (Vitalité : Pa vers 60, Ra vers 190-200). Une rune trop lourde sur une ligne basse multiplie les pertes. Une rune trop légère multiplie les essais. **[COM+]** Sources : Tofus, Gamosaurus.
- **Garder le poids total sous le poids max** pour améliorer le SC. **[COM+]** Source : Gamosaurus.
- **Lignes sacrifiables** (Prospection, Pods, Initiative) : elles servent à absorber les pertes, ou de puits si elles sont lourdes. **[COM+]**
- **Recompter le puits à partir de l'historique** en cas de doute. **[COM+]** Source : Gamosaurus.
- **Orbe régénérant** pour repartir de zéro (jets refaits, puits effacé, transcendance retirée depuis la 3.7). Il y en a quatre paliers : ≤60, ≤120, ≤180, ≤200. **[OFF]** et **[COM+]**
- **Runes de chasse** : exo « arme de chasse » sur une arme. Une exo de chasse n'empêche pas la transcendance. **[COM-]** Source : Gamosaurus.
- **Rien de nouveau en 3.7 pour les runes de statistiques.** Les nouveautés touchent les potions et éclats de conversion (100 % ou 10 %), les gemmes régénérantes, l'orbe contre la transcendance et un bouton « tout transférer » en coopérative. **[OFF]**, relayé par [DPLN](https://www.dofuspourlesnoobs.com/mise-a-jour-307.html) et [jeuxend](https://www.jeuxend.com/blog/dofus-3-7-forgemagie-potions-100-armes-soin-gemmes).
- **Dracorunes (3.8, début décembre 2026)**. Connues seulement par l'extrait de recherche du [devblog](https://www.dofus.com/en/mmorpg/news/devblog/tickets/1772847-update-3-8-equipment-dracorunes), qui renvoie 403 en lecture directe. Elles **convertissent une caractéristique en une autre**, efficaces à 100 %, **une seule par objet**, et ne tombent que du Titan Zuhul. **[COM-]** Leur interaction avec le puits, l'over et l'exo est **inconnue**. Le modèle doit les traiter comme une issue à part.
- **Coût d'une session** :
  - Les prix sont **propres à chaque serveur** et volatils. **[COM+]**
  - Aucune source de prix exploitable n'a été trouvée.
  - Options : relevé manuel par le joueur, lecture OCR de l'HDV des runes quand il l'ouvre **[SUP]**, ou coût exprimé **en nombre de runes** plutôt qu'en kamas.
  - Arbitrage de fusion : une Pa vaut 3 simples, une Ra vaut 3 Pa. On compare au prix HDV de chaque rang.

---

## 5. Ce qu'un algorithme solide devrait modéliser

### 5.1 État

- **Les lignes** : pour chacune, la caractéristique, la valeur actuelle, le min et le max naturels (DofusDB), le poids/point, et si c'est un malus, un over ou une exo.
- **Le puits** : un réel ≥ 0, reconstruit à partir de l'historique. Il est **incertain** si la session a commencé avant que l'assistant observe l'objet, ou après un équipement, un échange ou une mise en HDV.
- **Le poids total** de l'objet et son **poids max**.
- **La cible** du joueur : les lignes voulues, avec un minimum acceptable pour chacune.
- **Le stock et le prix des runes**, si connus.

### 5.2 Transition (sur une rune r)

- On **déduit d'abord l'issue** (SC, SN ou EC) de ce que l'OCR a vu changer :
  - la ligne visée a monté et rien d'autre n'a bougé : SC ;
  - la ligne visée a monté et d'autres ont baissé, ou « − reliquat » apparaît : SN ;
  - la ligne visée n'a pas monté : EC.
- On applique ensuite la règle de perte (poids de r, prélevé dans le puits, puis sur les lignes). L'ordre exact des pertes reste **ouvert** (§1.4). Le mieux est de l'**inférer de l'observation** plutôt que de le coder en dur.

### 5.3 Probabilités apprises

- On estime P(SC, SN, EC | variables) par **comptage bayésien** (par exemple un a priori de Dirichlet sur chaque case de variables discrétisées).
- Variables : rapport jet/max de la ligne, poids de la rune, poids total/poids max, over ou exo oui/non, niveau de l'objet.
- A priori : les chiffres de la 1.27 et les bornes (SC ≥ 1 %, SN ≤ 50 %, exo lourde à environ 1 %).
- Les comptes s'accumulent sur le Mac de l'utilisateur, à chaque issue observée.
- **[SUP]** : c'est la seule façon honnête de faire, faute de formule.

### 5.4 Décision

- On cherche la rune qui **minimise l'espérance de coût** (en kamas ou en runes) pour atteindre la cible. Formellement, c'est un processus de décision markovien, sur des états discrétisés autour des valeurs utiles.
- En pratique, une **heuristique gloutonne** suffit probablement **[SUP]** :
  - le palier de rune selon la règle des ~20 × la puissance ;
  - les lignes dans l'ordre (lourdes avant légères, exo en dernier) ;
  - une alerte sur les plafonds (101, plafonds par ligne) ;
  - l'avertissement « ce SN risque de toucher la ligne X » quand le puits ne couvre pas le poids de la rune.

### 5.5 Critère d'arrêt

- La cible est atteinte.
- Le coût espéré pour finir dépasse la valeur de l'objet fini, ou le prix d'un objet neuf additionné du coût de FM depuis zéro.
- Le puits est épuisé avant une exo : on conseille de remonter le puits ou de passer l'orbe.

### 5.6 Limites

- Pas de formule : l'apprentissage demande des centaines d'issues par case, et les exos à 1 % sont très peu mesurables.
- La source des pertes (quelle ligne baisse) est aléatoire et sans règle connue, au-delà du « même poids d'abord » de JOL.
- Le puits est incertain dès que l'historique est incomplet.
- La version Unity est peut-être différente : rien n'indique de changement de mécanique en Dofus 3, mais rien ne l'exclut non plus.
- Les Dracorunes (3.8) sont nouvelles.
- **Contrainte CGU** : l'assistant recommande et affiche. Il ne clique jamais et n'enchaîne jamais de fusion.

---

## 6. Ce que l'interface de FM affiche (pour l'OCR)

**Aucune description ni capture de l'interface Unity (Dofus 3) n'a été trouvée.** Ce qui suit vaut pour la **2.x**, d'après la 2.29 ([JOL](https://dofus.jeuxonline.info/actualite/48173/mise-jour-229-refonte-interface-forgemagie)), la 2.58 ([JOL](https://dofus.jeuxonline.info/actualite/58753/dofus-258-amelioration-confort-forgemages)) et [Gamosaurus](https://www.gamosaurus.com/?p=118767). C'est une **hypothèse à vérifier sur une capture réelle avant tout calibrage**.

- **En haut** : trois cases (objet, rune, signature), avec les boutons « Fusionner » et « Fusionner tout ». En **mode avancé** (2.58), un clic sur une rune la fusionne directement. **[OFF]** 2.x
- **Au centre** : une ligne par effet (19 visibles au plus), avec le **jet théorique min-max** à gauche, le **jet actuel**, une **colonne de variation** de la dernière fusion (effets touchés mis en valeur) et les **runes compatibles** en face de chaque ligne. Une icône œil masque une ligne, qui passe en grisé en fin de liste. Une stat à 0 est grisée ; un over a une autre couleur (infobulle, 2.58). **[OFF]** 2.x
- **À gauche** : l'**historique** de la session (depuis la connexion, à travers les ateliers). Chaque entrée porte l'icône de la rune, les gains et pertes, et le reliquat. Les couleurs distinguent les issues (vert SC, jaune SN, rouge EC), et la 2.58 ajoute une couleur pour le succès exotique. **[OFF]** et **[COM+]**
- **Non affichés** : le **puits** et les **probabilités**, par choix d'Ankama en 2.29. **[OFF]**
- **Densité d'une rune** : seulement dans son infobulle. **[OFF]**

Pour l'OCR **[SUP]** :

- **Zones utiles** : la table centrale (nom, min-max, actuel) et la dernière entrée de l'historique (issue et pertes).
- **Libellés** : les gabarits `description.fr` de DofusDB permettent d'apparier le texte lu à un `effectId`.
- **Signal le plus robuste pour l'issue** : la **différence entre deux lectures de la table** (avant et après fusion). Il vaut mieux que la couleur de l'historique.
- **Prérequis** : faire une capture de l'interface Unity pour fixer les zones.

---

## 7. Sources

- JOL, guide de la forgemagie : https://dofus.jeuxonline.info/article/3736/forgemagie
- JOL, 2.29, refonte de l'interface : https://dofus.jeuxonline.info/actualite/48173/mise-jour-229-refonte-interface-forgemagie
- JOL, 2.58 : https://dofus.jeuxonline.info/actualite/58753/dofus-258-amelioration-confort-forgemages
- Gamosaurus, guide complet (2022-2023) : https://www.gamosaurus.com/?p=118767
- Millenium, guide FM (2018), plafonds et orbes : https://www.millenium.org/guide/282643.html
- Tofus, fiche forgemagie : https://www.tofus.fr/fiches/forgemagie
- Dofus Fashionista, simulateur Dofus 3 (3.7.14.18) : https://dofusfashionista.gg/fr/forgemagie/ (version Dofus 2 : https://dofusfashionista.gg/fr/dofus2/forgemagie/)
- next-stage, transcendance (03/2026) : https://www.next-stage.fr/2026/03/runes-transcendance-dofus-comment-elles-fonctionnent-comment-utiliser.html
- Blog de la guilde Yin-Yang, tests de la 1.27 : https://yin-yang.over-blog.com/article-29549211.html
- Forum JOL, algorithme de la FM (402, lu par extrait) : https://forums.jeuxonline.info/sujet/1388548/question-sur-l-algorithme-de-la-forgemagie
- Dofus pour les noobs, 3.7 : https://www.dofuspourlesnoobs.com/mise-a-jour-307.html
- jeuxend, FM en 3.7 (10-11/2026) : https://www.jeuxend.com/blog/dofus-3-7-forgemagie-potions-100-armes-soin-gemmes
- Devblog 3.8, Dracorunes (403, lu par extrait) : https://www.dofus.com/en/mmorpg/news/devblog/tickets/1772847-update-3-8-equipment-dracorunes
- ForgeMagix, simulateur (aucun modèle publié) : https://lightcroft.itch.io/forgemagiedofus
- DofusDB, API et licence : https://api.dofusdb.fr/ (`/effects`, `/items?typeId=78`, `/characteristics`)
