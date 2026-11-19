# Journal des versions

Une section par version, `## X.Y.Z — AAAA-MM-JJ` : la release GitHub de `vX.Y.Z` en reprend le
contenu (`Tools/notes-de-version.sh`), et `sh build.sh --publish` refuse une version absente d'ici.

## 0.15.0-rc.1 — 2026-11-19

Préversion : elle ne se propose pas d'elle-même, elle s'installe par son DMG.

### Nouveautés

- **macOS 26 minimum.** Une version qui exige un macOS plus récent que celui du Mac se dit
  (« nécessite macOS N ») sans se proposer ni s'installer.
- **Nouvelle apparence**, commune aux apps Synseria : thème **Lagon** par défaut, thème × nuance
  dans Réglages → Thème (les réglages d'avant sont repris).
- **Barre à une rangée** : une pilule d'équipe et son menu, les outils en boutons-icônes.
- **Palette** : une seule rangée de puces qui ne bouge plus, avec ou sans texte tapé ; zaaps en
  cartes d'une même hauteur sur l'image de la carte du jeu, agrandie au survol de sa loupe.
- **Panneau Recette** épinglable à côté du jeu ; un clic copie le nom d'un ingrédient.
- **Aides des boss** repliées sous leur consigne, à déplier.

### Améliorations

- **Réglages** en onglets, page posée sur une plaque, hauteur bornée à l'écran.
- Les panneaux de jeu (Recette, boss) gardent leur haut quand leur contenu change.
- **Statistiques d'utilisation** : la télémétrie commune aux apps Synseria (des compteurs, jamais
  de contenu).

## 0.14.0 — 2026-11-17

### Nouveautés

- **Nouvelle apparence** : barre, palette, panneaux et réglages partagent un même dessin — une
  couleur de l'app, une teinte des fonds, des états qui se lisent pareil partout. Réglages → Thème
  les choisit sur un aperçu de la barre et de la palette, et « Apparence » fixe clair ou sombre
  sans suivre macOS.
- **Palette en vues** : au repos, une rangée Accueil, Zaaps, Almanax, Donjons, Quêtes, PNJ ; dès
  qu'on tape, les mêmes deviennent des filtres de la recherche (« Tout » en tête).
  - **Zaaps** : la grille entière ; **Almanax** : aujourd'hui et les six jours suivants en cartes,
    aussi en bouton dans la barre.
  - **PNJ** : une carte par PNJ, favoris et habitudes d'abord, puis les plus proches ; ↵ ou →
    déplie ses positions en cartes, et un PNJ se trouve par le lieu de chacune.
  - **Fautes de frappe tolérées**, tri « Auto » par pertinence et par tes habitudes (gardées sur
    le Mac) ; ⌘T change de tri là où il range.
  - Des **coordonnées tapées seules** donnent « Aller en [x,y] » avec leur trajet ; le **nom d'un
    perso** le met devant.
  - Les variables (`%`) montrent leur valeur du moment, le pied le texte exact que ↵ va copier.
- **Quêtes** : la liste prend la place de la fiche, une quête choisie remplace celle montrée.
  Avancement de l'étape à côté de son titre, un clic sur « Étape n / N » ouvre la liste des étapes,
  ressources cochables (« Tout copier » ne prend que le reste), « Tout épingler », un signe dans
  l'en-tête quand une quête commence sur ta case.
- **Menu de la barre de menus** : chaque personnage dit son état (à son tour, t'appelle, en
  combat, autre bureau), « Passage automatique » s'y coche, « Zaaps favoris » en sous-menu, la
  disposition en cours cochée, le raccourci de chaque geste au bout de sa ligne.
- **Mises à jour** : une notification le jour où une version est trouvée, une feuille « Nouveautés
  · Installer et relancer », « Nouveautés de la X.Y.Z » dans le menu au premier lancement qui suit,
  et une fenêtre « À propos de Synfus » avec « Rechercher une mise à jour ».
- **Raccourcis d'origine pour les panneaux** : ⌥⌘Q quêtes, ⌥⌘C chasse, ⌥⌘B boss. Ceux des
  panneaux, du zaap et de l'invitation se règlent sur la page Raccourcis.

### Améliorations

- **Réglages** : dix pages sous quatre titres dans une barre latérale. Au premier lancement ils
  s'ouvrent sur Général, autorisations en tête ; Général gagne un bloc « Mises à jour » (version
  installée, dernière vérification).
- **Barre** : clic droit sur une pastille pour l'équipe et « Déplacer à gauche / à droite »,
  « Réduire les personnages inactifs » (emblème et touche seuls), le contour bat dans les cinq
  dernières secondes d'un tour, un symbole par outil, infobulles avec la touche.
- **Rangement** : le grand emplacement suit le perso que Synfus amène devant.
- **Aide aux boss** : « Tour — » tant que le tour est inconnu, « Nouveau combat » dans le menu du
  titre, résistances en cinq colonnes, hauteur stable d'un tour à l'autre, la mécanique à la main
  reste là sans autorisation ; le Comte dit la règle du tour en deux mots.
- **Chasse au trésor** : revenir à l'étape précédente, indices lus jamais tronqués, chargement dit
  dans l'en-tête.
- **Panneaux** : « Recentrer la barre et les panneaux » ramène un panneau perdu hors de l'écran,
  chacun se ferme de son en-tête ou de son menu, « Copié » se signale partout par la même coche.
- **Autorisations** : deux libellés partout, « Autoriser l'accessibilité » et « Autoriser la
  lecture de l'écran » ; une lecture manquante se dit au même endroit dans la chasse, les boss, les
  quêtes et le menu.
- La palette dit pourquoi elle est vide (carte en chargement, indisponible, « N résultats dans
  Tout ») et « position inconnue » devient un geste selon sa cause.

### Changements

- La palette s'ouvre toujours sur l'Accueil, sans l'almanax ni les dernières copies : l'almanax a
  sa vue, les copies se retrouvent en tapant. « / » et « % » ne sont plus des filtres, l'invite du
  champ les rappelle.

### Corrections

- « +400 % » d'Ilyzaelle s'affichait « +400 0e ».
- Un panneau poussé à moitié hors de l'écran ne saute plus.
- Quêtes : un objectif fait n'est plus tronqué, plus de saut au clic sur un objectif.

## 0.13.0 — 2026-11-11

### Nouveautés

- **Nouvelle icône** : l'Œuf ajouré, un Dofus en treillis blanc bleuté posé sur un feuillage,
  sans fond ; la barre de menus en reprend la silhouette. Réglages → Général, « Icône de l'app » :
  l'Œuf ou la Couvée (l'ancien logo), sans fond ou sur fond bleu nuit, forêt ou aube.

- **Fiche d'un donjon** dans la palette, la même qu'on cherche le donjon ou l'un de ses boss :
  niveau conseillé, trajet jusqu'à l'entrée, guide Dofus pour les noobs, clef (et où la trouver),
  boss et monstres avec niveau, PV, PA, PM et résistances, succès.
- **Combat des persos derrière** (Réglages → Lecture de l'écran, sous « Lire le combat ») : leur
  pastille montre le décompte de leur tour même quand tu ne les regardes pas, Dofus en
  arrière-plan compris. En fenêtré seulement.
- **Almanax en deux temps** : « Nom » copie l'offrande pour l'hôtel de vente, « Sanctuaire » le
  trajet pour la rendre.
- **Statistiques** (Réglages → Usage) : ce que tu utilises dans Synfus, sur 7 jours,
  30 jours ou depuis le début. Elles sont partagées une fois par jour, anonymes, pour savoir ce qui
  sert et ce qui peut partir : « Voir les données » montre le JSON exact envoyé, un interrupteur
  coupe l'envoi. Rien du jeu n'en fait partie, ni le nom de tes persos.

### Améliorations

- **Aide aux boss pour tous les boss de donjon** : fiche (PV, PA, PM, résistances), éléments à
  frapper et à éviter, conseils de Dofus pour les noobs, guide et tour du combat. « Aide au
  combat : X » dans la palette, « Autre boss… » au titre du panneau ; entrer dans un donjon
  choisit son boss. Les cinq boss à mécanique gardent leur aide propre, conseils en plus.
- Une pastille en combat, sans que ce soit son tour, prend un cadre rose discret.
- **Boutons de la barre au choix** (Réglages → Barre) : quêtes, boss, chasse, rangement, palette et
  passage automatique s'affichent ou se masquent un par un, et un clic droit sur l'un d'eux propose
  « Masquer ce bouton ».
- Les **rappels du combat d'un boss** se copient d'un clic pour le tchat ; l'icône de leur titre
  les copie tous à la suite.
- **Palette** : rouverte, elle reprend où on l'a laissée — recherche toute sélectionnée (une
  lettre la remplace), filtre, ligne et fiche dépliée. Le perso d'où partent les trajets passe à
  côté du champ, lisible en entier.
- **Fiche d'un donjon au clavier** : ↵ la déplie, le clavier sur « Position » (↵ encore : trajet
  copié) ; ←/→ passe d'une carte à l'autre, sur une ligne (guide, conseils, monstres, succès, clef), ↑ revient à
  la ligne, ↵ y replie. Les **conseils tactiques** de Dofus pour les noobs se déplient dans la
  fiche, et chaque boss ou monstre dit les éléments à frapper et à éviter d'après ses résistances.

### Corrections

- Les zaaps d'une autre carte du monde (Incarnam, la Canopée, Harebourg, Crocuzko) reviennent
  décochés par défaut : le jeu refuse leur `/zaap` (la Canopée du Kimbo copiait un trajet mort).

## 0.12.0 — 2026-11-10

![La fiche de quête](https://raw.githubusercontent.com/Synseria/Synfus/v0.12.0/docs/screenshots/quete.png)

### Nouveautés

- **Mise à jour depuis Synfus** : chaque jour, Synfus regarde s'il existe une nouvelle version sur
  GitHub et la propose dans son menu et dans Réglages → Général. Un clic : téléchargement, contrôle,
  remplacement et relance, sans commande `xattr` à taper. Les autorisations Accessibilité et
  Enregistrement de l'écran sont à redonner à chaque version (l'app n'est pas signée par un
  certificat Apple payant) : Synfus le dit, et dit pourquoi. Désactivable (Réglages → Général).
  Cette version-ci s'installe encore à la main ; les suivantes, d'elles-mêmes.
- **Commandes entre `/zaap` et `/travel`** (Réglages → Trajets, `/a` par défaut) : le jeu ignorait
  parfois le `/travel` lancé avant que la carte du zaap ait chargé. `/zaap -1,24 ; /a ; /travel -4,29`
  lui laisse le temps.
- **Aide aux boss** : un panneau posé sur le jeu pour le Comte Harebourg (confusion des sorts lue
  à la vie et au canal combat), Kimbo, Toxoliath, Ilyzaelle et Tal Kasha, avec le tour du combat
  compté. Entrer dans la salle d'un boss le choisit ; sa fiche DofusDB (niveau, PV, PA, PM,
  résistances) et un lien vers le guide du donjon sur Dofus pour les noobs. Un bouton dans la
  barre.
- **Quêtes** :
  - le suivi du jeu relu tant que le panneau est montré, **perso par perso** : objectifs faits
    cochés, objectif en cours surligné, « Tu y es — fait ? » sur la carte de l'objectif ;
  - **où trouver** le monstre ou l'objet d'un objectif ;
  - **quêtes d'ici** : celles qui commencent et les PNJ sur la case du perso ;
  - les objectifs ouverts ensemble numérotés dans l'ordre le plus court ;
  - un panneau compact.
- **Palette** : l'almanax du jour en tête, sections Monstres et Objets (Entrée déplie où les
  trouver), PNJ en favori, une ligne de trajet dit le zaap retenu (« via Coin des Bouftous · 6
  cartes »).
- **Zones de lecture retrouvées seules** sur une capture du jeu.

### Améliorations

- Données du jeu (carte, quêtes, classes) revues chaque jour, plus seulement au lancement.
- Réglages sans phrase à l'écran : le détail passe au ⓘ, un clic mène à l'onglet cité, un
  raccourci refusé par macOS se signale.
- Palette à trois colonnes, Échap efface avant de fermer, filtres au clic.
- VoiceOver et « Réduire les animations » respectés.
- Barre et menu rangés dans le même ordre : quêtes, boss, chasse, puis rangement des fenêtres ; la
  palette au menu.
- Lecture de l'écran plus légère : une capture entière découpée dès deux zones, combat lu toutes
  les 3 s hors combat.

### Corrections

- ⌘C, ⌘V, ⌘A, ⌘Z marchent dans tous les champs ; « Fermer tous » ne se valide plus avec Entrée.
- Un PNJ ou un objectif hors du Monde des Douze se rejoint par son `/travel` seul.
- **Zaaps** : le zaap que le jeu rattache à la zone visée n'est plus remplacé par un zaap plus
  proche derrière des falaises (Mériana : Koalak, plus la Montagne des Craqueleurs) ; un PNJ, un
  lieu ou un objectif est situé par sa sous-zone, pas seulement sa case (l'Assistante d'Otomaï :
  le zaap de la Canopée, plus celui de la plage). Les zaaps de la Canopée, de Harebourg et de
  Crocuzko sont actifs par défaut.
- Un client revenu à l'écran de connexion oublie son perso.

## 0.11.0 — 2026-10-08

![La barre](https://raw.githubusercontent.com/Synseria/Synfus/v0.11.0/docs/screenshots/barre.png)

### Nouveautés

- **Panneaux seulement devant Dofus** (Réglages → Barre, allumé) : les panneaux des quêtes et de la
  chasse se cachent quand une autre app passe devant, et reviennent avec le jeu sans lui prendre
  le clavier.
- **Un README vitrine** : chaque fonction de Synfus en une capture, à partager d'un lien.

### Améliorations

- Les cases de zaap de la palette ont, elles aussi, la vue de leur carte en fond.
- Quêtes et chasse au même dessin : même en-tête, même bouton « − » pour cacher le panneau.

## 0.10.1 — 2026-10-08

### Nouveautés

- **Le zaap qui mène vraiment quelque part** : un `/travel` passe par le zaap que le jeu rattache à
  la zone visée — `/travel -20,9` part du zaap des Koalaks, plus de celui de Sidimote derrière la
  montagne. Éteint (Trajets → « Zaap désigné par le jeu »), le plus proche par les zones voisines.
- **Panneau des quêtes** :
  - un bouton dans la barre ;
  - un en-tête d'une ligne, avec un menu des quêtes épinglées et du **suivi lu à l'écran** ;
  - la consigne de chaque étape, les récompenses, la vue de la carte de chaque objectif, en grand
    au survol ;
  - une coche verte sur l'objectif dont on a copié le trajet ;
  - ce que la quête exige (classe, niveau, métier, alignement) ;
  - les quêtes qui suivent ;
  - un lien vers Dofus pour les noobs.

  Il ne se montre que devant Dofus.
- **Lire le suivi de quêtes** : les quêtes suivies en jeu sont reconnues et s'épinglent d'un clic, à
  leur étape.
- **Calibrer chaque lecture de l'écran** sur sa propre capture (position, combat, chasse, suivi de
  quêtes), avec un essai de lecture en direct.
- **Vues des cartes** à droite des lieux, des PNJ et des zaaps, dans la palette et les réglages,
  et en fond des cartes de zaap ; le pictogramme du jeu pour chaque lieu. Un seul interrupteur les
  masque toutes.
- **Classes tirées de DofusDB** : noms et emblèmes téléchargés par l'app ; ton icône garde la
  priorité.
- **Masquer les objets de quête** dans les ressources à réunir.

### Améliorations

- Toute position s'affiche **`[x,y]`**, comme le jeu l'écrit.
- Les onglets Zaaps, Lieux, Quêtes et PNJ des réglages s'ouvrent sans attendre.
- Raccourcis : plus de « nombre d'emplacements » — un raccourci par perso connecté, et ⌘6 reste aux
  autres apps tant qu'il n'y a pas de sixième perso.
- Chasse au trésor : une seule colonne étroite, l'indice sous la boussole.
- Pluriels justes : « 1 étape », « 1 carte ».

### Corrections

- Panneau des quêtes : la première ligne répond au clic, un double-clic ne l'agrandit plus en
  plein écran, et la croix se clique sans viser.

## 0.10.0 — 2026-10-08

![La palette](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/palette-zaaps.png)

### Nouveautés

- **La palette (⌘:)** : un champ de recherche au-dessus du jeu, qui prend le clavier sans passer
  devant Dofus. Tu tapes, Entrée copie, ⌘V colle dans le tchat — Synfus n'envoie toujours rien.
  Rien de tapé : les zaaps en cartes, favoris d'abord puis du plus proche, et tes dernières copies.
- **`/zaap bonta`** : un zaap par son nom, sa **zone** (Cœur immaculé → Bonta) ou ton
  **étiquette** libre (« Fri 1 », « Bouftou »), posée d'un ⌘E ; ⌘D pour un favori.
- **`/travel banque bonta`** : les **834 lieux** du jeu — banques, hôtels de vente, ateliers,
  temples, donjons, transports — avec les surnoms des joueurs (`fm`, `hdv conso`, `bijou`…). Le
  plus proche de toi passe devant, et le trajet est copié en `/zaap x,y ; /travel a,b` quand le
  zaap fait gagner du chemin.

  ![/travel banque bonta](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/palette-travel.png)

- **`/`** : les commandes du jeu (`/w`, `/g`, `/p`, `/whois`, `/away`…), une commande à argument
  se complète. **`%`** : les variables du tchat (`%pos%`, `%zone%`, `%souszone%`…).

  ![Les commandes](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/palette-commandes.png)

- **Tout Synfus au clavier** : « ranger », « session », « équipe suivante », « chasse »… et Entrée.
- **`/invite`** : toute l'équipe en une ligne, ou un perso.
- **`/quete wogew`** : les **1 976 quêtes** du jeu, **épinglées** dans un **panneau transparent**
  (un onglet par quête, redimensionnable) qui reste au-dessus du jeu sans lui prendre le clavier —
  les **ressources à réunir** avec leur catégorie (ressource, consommable, objet de quête… ; un clic
  copie le nom pour l'hôtel de vente, ou toute la liste), « en groupe » ou « donjon » quand il le
  faut, puis l'étape en cours, parcourue aux flèches ‹ › et retenue, dont un clic copie le trajet.
  Téléchargées depuis DofusDB au lancement (quelques secondes), puis tous les 30 jours.

  ![Une quête ouverte](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/quete.png)

- **`/pnj nom`** : les PNJ que les quêtes situent (plus de 2 000), le plus proche devant, leur
  trajet copié ; chaque case dit sa zone et combien de quêtes l'y placent — la plus citée est
  « habituelle ».
- **Filtres et tris** : les zaaps passent toujours devant ; Tab fait défiler Tout, Zaaps, Lieux,
  Quêtes, PNJ, et ⌘T trie le reste par proximité, par ordre alphabétique ou par type.

### Améliorations

- **Réglages refaits** : une seule grille (libellé à gauche, réglage à droite), des libellés
  harmonisés, et **plus d'onglets, moins chargés**, rangés par sujet — Clavier (raccourcis,
  attention, enchaîner, invitations), En jeu (palette, trajets, chasse), **Données du jeu**
  (zaaps, lieux, quêtes, PNJ, chacun à chercher et mettre à jour), Persos, Avancé (lecture de
  l'écran, diagnostic).

  ![L'onglet Zaaps](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/reglages-zaaps.png)

- **Une seule carte du jeu** : zaaps et lieux viennent d'une même liste DofusDB, intégrée à
  Synfus et rafraîchie tous les 30 jours.
- Le bouton Zaap de la barre ouvre la palette.
- **Chasse au trésor** : un panneau transparent, au style des quêtes, et une **boussole** — les
  quatre directions autour de « Lire », l'indice lu à l'écran.
- **Plus rapide** : la palette prépare sa recherche en fond, les zaaps et les quêtes sont indexés
  une fois.

### Changé

- **⌘: ouvre la palette** ; l'invitation passe à **⇧⌘:** (si tu l'avais changée, elle ne bouge
  pas). Le clic droit d'une pastille dit « Inviter Brok ».
- `/zaap x,y ; /travel a,b` : une espace avant le `;`, que le jeu lit mieux.

## 0.9.0 — 2026-10-07

### Nouveautés

- **Aide aux chasses au trésor** (bouton de la barre, raccourci ou menu) : départ lu à l'écran,
  direction aux flèches, indice saisi ou lu par OCR ; la carte vient de DofusDB et son `/travel`
  est copié — par un zaap si c'est plus court. La zone lue se calibre dans l'onglet Diagnostic.
- **Zaaps** : un `/travel` copié devient `/zaap x,y; /travel a,b` quand un zaap épargne assez de
  cartes — au raccourci, au bouton de la barre, ou tout seul à chaque copie.
- **Onglet Zaap** : tous les zaaps du jeu, activables un à un, ajouts à la main, liste tenue à jour
  depuis DofusDB (d'elle-même tous les 30 jours).
- **Zaaps favoris** : étoilés dans l'onglet Zaap, proposés au clic droit du bouton Zaap du plus
  proche au plus loin ; un clic copie le `/zaap`.
- **Rejoindre un perso** : clic droit sur sa pastille, son `/travel` est copié.
- **Invitations** : toutes les invitations de l'équipe d'un coup, en une ligne.

### Améliorations

- Barre plus économe : le diagnostic ne la redessine plus, la sonde d'attention est bornée.
- Compilée avec Xcode 27 et Swift 6.4.

### Retiré

- L'intégration Stream Deck.
