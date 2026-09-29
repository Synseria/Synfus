# Rangement des fenêtres — `Sources/Synfus/Rangement/`

- `WindowArranger` pose `kAXPosition`/`kAXSize`, rien d'autre. Le calcul des cadres est dans
  `LayoutComputer` (pur : zone + nombre → cadres, repère AX y vers le bas), testé dans
  `LayoutComputerTests`, conversion Cocoa → AX (`zoneAX`) et multi-écrans compris.
- Quatre dispositions : côte à côte, mosaïque, un grand + vignettes, empilés plein cadre
  (`.empilee`, seule où les cadres se recouvrent ; la barre fait tourner la pile).
- Exclusions décidées et rapportées (`Rapport`, affiché au Diagnostic) : perso dormant (élément
  AX périmé) et fenêtre en plein écran — on ne sort jamais personne du plein écran d'autorité.
- Tout va sur **un** écran, celui du perso au premier plan. Pose **taille → position →
  taille** : certains clients plafonnent la taille tant que la fenêtre chevauche son ancien
  écran.
- Hors `LayoutComputer` : « tout en plein écran » (un espace par perso, `"AXFullScreen"` posé
  y compris sur les dormants, via l'objet fenêtre — hypothèse rapportée au Diagnostic) et son
  inverse.
- Opère sur l'`effectif` (le rapport nomme l'équipe) et attend `WindowManager.refreshed()`.
- Points d'entrée : bouton de la barre (`ArrangeMenuButton`, zone des modes), sous-menu de la
  barre de menus, clic droit, raccourci optionnel **sans défaut** qui rejoue
  `Preferences.lastArrangement`.
- « Lancer la session » (`WindowManager.lancerSession`) : ranger selon la dernière
  disposition, puis basculer sur le perso 1 ; raccourci sans défaut (`sessionHotKey`).
