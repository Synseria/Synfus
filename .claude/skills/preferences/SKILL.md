---
name: preferences
description: Persistance des réglages de Synfus — Preferences (JSON sous une clé, table `reglages`), compatibilité des sauvegardes, générations de défauts, stockage en mémoire pour les tests. Charger avant d'ajouter, renommer ou changer le défaut d'un réglage, de toucher Preferences/ ou PreferencesTests.
user-invocable: false
---

# Préférences — `Sources/Synfus/Preferences/Preferences.swift`

## Stockage

- Tout est sérialisé en JSON sous une clé unique, `fr.synseria.synfus.preferences`, dans le
  `PreferencesStore` fourni (`UserDefaults.standard` en production). Tests :
  `Preferences.forTesting(store:)` (règle dans `CLAUDE.md`).
- Aucune migration depuis les anciens identifiants (`fr.dofusyn.DofuSyn`, `fr.synfus.Synfus`) :
  choix assumé. Le fichier de préférences est nommé d'après le `BUNDLE_ID`.
- Chaque `@Published` appelle `save()` dans son `didSet` ; `loading` bloque les écritures
  pendant le chargement. Un geste qui change plusieurs réglages (coche, lecture du suivi) passe
  par `enUneEcriture` : une seule écriture, imbriquée ou non.

## Ajouter un réglage

- Deux endroits : la propriété (valeur initiale = défaut) et **une ligne** de la table
  `reglages`, qui donne la clé JSON et en dérive écriture et lecture.
- Un nouveau réglage entre en `.facultatif` (ou `.optionnel` si `nil` est permis) : absente
  d'une ancienne sauvegarde, la clé laisse le défaut. Seules les clés d'origine sont `.requis`.
- Un choix écrit en texte (`.enTexte`, `.enTexteOptionnel`) : une valeur illisible — un préréglage retiré
  comme `violet` — laisse le défaut au lieu de rendre la sauvegarde illisible. `nil` est le choix « Auto »
  (`fondsDeLApp`) : il n'est pas écrit, et revenir à Auto l'efface.
- **Une clé ne se renomme jamais** : les tests d'empreinte de `PreferencesTests` figent le JSON
  écrit, et « une sauvegarde amputée des clés récentes se relit » garde la compatibilité.
- Plusieurs clés remplacées par une seule : la nouvelle clé prime ; tant qu'une sauvegarde ne
  l'a pas, les anciennes sont relues pour la composer (`Reglage.boutonsMasques`, qui reprend
  `quetesBouton`, `bossBouton`…). Un type sauvegardé qui s'élargit garde sa forme d'avant
  (`CibleBoss` s'écrit en chaîne, comme `Boss`).
- Les conformances `Codable` de `Ecriture`/`Lecture` sont `@MainActor`, ce qui laisse les
  closures toucher `Preferences`.
- `nil` peut valoir « le défaut courant » (zones de lecture) : le défaut suit alors ses
  corrections futures.

## Changer un défaut

Les préférences existantes ne repassent jamais par le premier lancement. Incrémenter
`defaultsVersion` et compléter `adoptDefaults(from:)`, qui ne réécrit que les valeurs **encore
égales à l'ancien défaut** — une valeur personnalisée est un choix. La génération inscrite dans
la sauvegarde distingue aussi « jamais eu ce réglage » de « effacé exprès ».

## Pièges

- Favoris : `estFavori`/`basculerFavori` répartissent par préfixe — `lieu:` → `lieuxFavoris`,
  `pnj:` → `pnjsFavoris`, sinon `zaapsFavoris`.

- `hotKeys` a toujours dix emplacements (`completerHotKeys` au chargement) ; combien servent
  dépend de l'effectif (skill `raccourcis`), aucun réglage ne le fixe.
- `characterOrder` ne reçoit que des noms persistables ; `purgeOrder` et `forget` gardent
  `equipes` ⊆ `characterOrder` (skill `inventaire-clients`).
