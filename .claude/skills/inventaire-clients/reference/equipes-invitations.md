# Équipes (modèle) et invitations

La vue des équipes (seconde rangée de la barre, glisser-déposer) est dans le skill
`interface-barre`.

## Équipes — `Sources/Synfus/Clients/Equipes.swift` (pur, `EquipesTests`)

- Une équipe est une **appartenance, pas un ordre** : une liste de noms ⊆ `characterOrder` ;
  l'effectif garde l'ordre de la barre. Au plus `Equipes.maximum`. Ni nom ni couleur.
- Un seul foyer de calcul de `effectif` : `republierEffectif` (`WindowManager+Effectif.swift`),
  appelé à chaque publication de `clients` et par un `CombineLatest` sur les préférences — qui
  lit les valeurs **émises**, car `@Published` publie avant d'affecter. Rien n'est republié
  sans changement.
- `equipeActive` est un état de session, jamais persisté : Synfus démarre sur « Tous ». Un
  index orphelin ramène à « Tous » (`activeValide`).
- Les compositions vivent dans `Preferences.equipes`, gardées ⊆ `characterOrder` par
  `forget` et `purgeOrder`. Les noms non persistables n'ont jamais d'équipe.
- Perso au premier plan hors de l'équipe : pas de `currentIndex`, `cycle` va au premier de
  l'effectif. ⌘1 = premier de l'équipe.
- Pas de bascule « équipes » : la fonction n'existe que par ses équipes. Le raccourci
  « Équipe suivante » est sans défaut et n'apparaît qu'avec une équipe.

## Invitations — `Sources/Synfus/Invitations/`

- Synfus **compose** `/invite Nom` dans le presse-papiers, le joueur colle (⌘V ↩) : envoyer au
  tchat serait une saisie synthétisée. `App/PressePapiers.swift` est l'unique écriture dans
  `NSPasteboard`.
- `InvitationComposer` (pur, `InvitationComposerTests`) : l'effectif sans le **chef** (le
  perso devant, par pid) ; noms tirés du titre (`characterName(fromTitle:)`, jamais
  « Nom (2) ») ; dédoublonnés ; clients au login exclus, dormants inclus.
- Le chef est **fixé au premier appui** et le reste jusqu'au dernier invité (`tourTermine`)
  ou s'il quitte l'effectif : avec le passage automatique, Synfus bascule sur l'invité qui
  rebondit, et le tour réinviterait sinon le chef.
- Raccourci `inviteHotKey` (⌘:, keycode 47 — choix de l'utilisateur malgré le conflit avec
  « Orthographe et grammaire » des apps de texte). Le clic droit d'une pastille copie
  l'invitation de ce perso sans toucher au tour.
- `inviteFormat` (`/invite %nom`) est un réglage texte : si la commande du jeu change, on ne
  recompile pas.
