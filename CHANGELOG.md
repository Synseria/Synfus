# Journal des versions

Une section par version, `## X.Y.Z — AAAA-MM-JJ` : la release GitHub de `vX.Y.Z` en reprend le
contenu (`Tools/notes-de-version.sh`), et `sh build.sh --publish` refuse une version absente d'ici.

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
  faut, puis l'étape en cours, parcourue aux flèches ‹ › et retenue, dont un clic copie le trajet. Téléchargées depuis DofusDB à la première ouverture
  de la palette (quelques secondes), puis tous les 30 jours.

  ![Une quête ouverte](https://raw.githubusercontent.com/Synseria/Synfus/v0.10.0/docs/screenshots/quete.png)

- **`/pnj nom`** : les PNJ que les quêtes situent (plus de 2 000), le plus proche devant, leur
  trajet copié.
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
  pas).

## 0.9.0 — 2026-10-07

### Nouveautés

- **Aide aux chasses au trésor** (bouton de la barre, raccourci ou menu) : départ lu à l'écran,
  direction aux flèches, indice saisi ou lu par OCR ; la carte vient de DofusDB et son `/travel`
  est copié — par un zaap si c'est plus court. La zone lue se calibre dans l'onglet Diagnostic.
- **Zaaps** : un `/travel` copié devient `/zaap x,y ; /travel a,b` quand un zaap épargne assez de
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
