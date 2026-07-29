#!/usr/bin/env bash
#
# Télécharge les emblèmes des 19 classes dans le dossier d'icônes de Synfus.
#
# Synfus n'embarque et ne redistribue aucune image du jeu : les visuels de Dofus
# appartiennent à Ankama, et l'article 13.2 des CGU interdit de les distribuer
# sans accord écrit. Ce script ne fait donc que *nommer* des adresses — c'est
# toi, joueur lié par ces CGU, qui déclenches la copie, vers ton seul disque,
# pour ton usage personnel. Rien n'est reversé au dépôt.
#
#     Certaines illustrations sont la propriété d'Ankama Studio et de Dofus
#     — Tous droits réservés.
#
# La source est l'API communautaire DofusDB, non affiliée à Ankama : le CDN
# officiel d'Ankama refuse les accès directs (403). Elle est gracieusement
# offerte à la communauté — 19 fichiers, une fois, et on n'y revient pas : les
# icônes déjà présentes sont laissées telles quelles, sauf --force.
#
# Usage :
#   ./Tools/fetch-class-icons.sh            # ne télécharge que ce qui manque
#   ./Tools/fetch-class-icons.sh --force    # remplace les icônes existantes
#   ./Tools/fetch-class-icons.sh --list     # montre ce qui serait fait

set -euo pipefail

DESTINATION="${HOME}/Library/Application Support/Synfus/Classes"
BASE="https://api.dofusdb.fr/img/breeds"

# Clé de classe → identifiant DofusDB. Les clés sont celles de DofusClass.swift,
# sans accent : ce sont aussi les noms de fichiers que Synfus va relire.
# L'identifiant 19 n'existe pas — le Forgelance porte le 20.
CLASSES=(
  "feca:1"
  "osamodas:2"
  "enutrof:3"
  "sram:4"
  "xelor:5"
  "ecaflip:6"
  "eniripsa:7"
  "iop:8"
  "cra:9"
  "sadida:10"
  "sacrieur:11"
  "pandawa:12"
  "roublard:13"
  "zobal:14"
  "steamer:15"
  "eliotrope:16"
  "huppermage:17"
  "ouginak:18"
  "forgelance:20"
)

force=0
liste=0
for argument in "$@"; do
  case "$argument" in
    --force) force=1 ;;
    --list|-n) liste=1 ;;
    -h|--help) sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu : $argument" >&2; exit 2 ;;
  esac
done

echo "==> Destination : ${DESTINATION}"
[ "$liste" -eq 1 ] || mkdir -p "$DESTINATION"

telecharges=0
conserves=0
echecs=0

for entree in "${CLASSES[@]}"; do
  cle="${entree%%:*}"
  identifiant="${entree##*:}"
  cible="${DESTINATION}/${cle}.png"
  source="${BASE}/symbol_${identifiant}.png"

  if [ -f "$cible" ] && [ "$force" -eq 0 ]; then
    printf '    %-12s déjà présent\n' "$cle"
    conserves=$((conserves + 1))
    continue
  fi

  if [ "$liste" -eq 1 ]; then
    printf '    %-12s %s\n' "$cle" "$source"
    continue
  fi

  # Fichier temporaire : une coupure réseau ne doit pas laisser un PNG tronqué
  # à la place d'une icône valide.
  temporaire="${cible}.partiel"
  if curl --fail --silent --show-error --location \
          --max-time 30 --retry 2 \
          --output "$temporaire" "$source"; then
    # Un serveur qui répond une page d'erreur en 200 laisserait un fichier non
    # lisible par Synfus : on vérifie que c'est bien un PNG avant de le garder.
    if file --brief --mime-type "$temporaire" | grep -q '^image/png$'; then
      mv "$temporaire" "$cible"
      printf '    %-12s téléchargé\n' "$cle"
      telecharges=$((telecharges + 1))
    else
      rm -f "$temporaire"
      printf '    %-12s réponse inattendue (pas un PNG)\n' "$cle" >&2
      echecs=$((echecs + 1))
    fi
  else
    rm -f "$temporaire"
    printf '    %-12s échec du téléchargement\n' "$cle" >&2
    echecs=$((echecs + 1))
  fi
done

if [ "$liste" -eq 1 ]; then
  echo "==> Simulation seulement, rien n'a été écrit."
  exit 0
fi

echo "==> ${telecharges} téléchargée(s), ${conserves} conservée(s), ${echecs} échec(s)"
if [ "$telecharges" -gt 0 ]; then
  echo "    Dans Synfus : Réglages → Classes → « Recharger »."
fi
[ "$echecs" -eq 0 ]
