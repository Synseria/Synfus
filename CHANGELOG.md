# Journal des versions

Une section par version, `## X.Y.Z — AAAA-MM-JJ` : la release GitHub de `vX.Y.Z` en reprend le
contenu (`Tools/notes-de-version.sh`), et `sh build.sh --publish` refuse une version absente d'ici.

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
