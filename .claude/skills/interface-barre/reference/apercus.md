# Aperçus des fenêtres — `Sources/Synfus/Apercus/`

- Capture par **ScreenCaptureKit** (`WindowPreviewService`) ; `CGWindowListCreateImage` est
  déprécié. Seconde autorisation TCC (`NSScreenCaptureUsageDescription`, Info.plist de
  `build.sh`) : les deux réglages d'aperçu sont éteints par défaut, une mise à jour ne fait
  surgir aucune demande.
- Aucune API ne relie un `AXUIElement` à une fenêtre capturable : appariement sur
  `(pid, titre)`, repli sur le pid quand le processus n'a qu'une fenêtre (le titre change à la
  reconnexion). Hypothèse testée (`WindowPreviewMatchTests`) et exposée au Diagnostic.
- Les candidats plus petits que le seuil d'`AccessibilityReader.isGameWindow(subrole:size:)` — le même
  des deux côtés — sont écartés
  (info-bulles et panneaux hors écran du même processus). Deux vraies fenêtres de jeu dans un
  processus : on renonce — mieux vaut aucun aperçu que celui du mauvais perso.
- `PreviewCaptureEngine` (actor) garde l'inventaire `SCShareableContent`, bien plus coûteux
  que la capture ; il ne le refait que s'il est vieux de plus de 3 s ou si un perso n'y trouve
  pas sa fenêtre, et une fois par rafraîchissement pour tous. N'en sort que du **PNG** : ni
  `SCWindow` ni `CGImage` ne franchissent la frontière. Captures séquentielles, faute de
  pouvoir passer un `SCWindow` à une tâche fille.
- Le survol **préchauffe** : `BarView.hover` lance `refresh` dès l'entrée si aucune vignette
  n'est connue et si l'autorisation est déjà accordée — `refresh` ne la demande jamais.
- Vignette de **taille fixe**, hauteur comprise : le panneau ne dépend pas de l'instant où la
  capture arrive.
- `PreviewPanelController` : `NSPanel` **distinct** de la barre (qui se dimensionne sur son
  contenu et se recentre), `ignoresMouseEvents`. Mode `.etiquette` sans capture pour la
  lecture de position (skill `lecture-ocr`).
- Limite documentée dans les réglages : une fenêtre d'un espace inactif est capturable mais
  macOS ne la redessine pas, l'image peut dater.
