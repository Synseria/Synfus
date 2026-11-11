#!/bin/bash
# symboliser.sh <diagnostic.json> — traduit en fonctions les adresses d'un
# rapport MetricKit de Synfus (diagnostic.contenu, copié depuis Grafana).
# Les symboles viennent de l'asset Synfus-X.Y.Z-dSYM.zip de la release de la
# version du rapport, téléchargé une fois dans ~/Library/Caches/Synfus-dSYM.
set -euo pipefail
RAPPORT="$(cd "$(dirname "${1:?usage : symboliser.sh <diagnostic.json>}")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")/.."

VERSION="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["diagnosticMetaData"]["appVersion"])' "$RAPPORT")"
ARCH="$(/usr/bin/python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["diagnosticMetaData"].get("platformArchitecture","arm64"); print("x86_64" if "x86" in a else "arm64")' "$RAPPORT")"
CACHE="$HOME/Library/Caches/Synfus-dSYM/$VERSION"
if [ ! -d "$CACHE/Synfus-$VERSION-$ARCH.dSYM" ]; then
    mkdir -p "$CACHE"
    gh release download "v$VERSION" --pattern "Synfus-$VERSION-dSYM.zip" --dir "$CACHE" --clobber
    ( cd "$CACHE" && unzip -qo "Synfus-$VERSION-dSYM.zip" )
fi
DWARF="$CACHE/Synfus-$VERSION-$ARCH.dSYM/Contents/Resources/DWARF/Synfus"

# Chaque cadre de Synfus : adresse et décalage dans son segment de texte
# donnent l'adresse de chargement que demande atos. Les autres binaires
# (système) restent tels quels.
/usr/bin/python3 - "$RAPPORT" "$DWARF" "$ARCH" <<'PY'
import json, subprocess, sys
rapport, dwarf, arch = sys.argv[1:4]
donnees = json.load(open(rapport))

def cadres(noeud, profondeur=0):
    yield noeud, profondeur
    for enfant in noeud.get("subFrames", []):
        yield from cadres(enfant, profondeur + 1)

arbre = donnees.get("callStackTree", {})
for pile in arbre.get("callStacks", []):
    print("— fil" + (" (en faute)" if pile.get("threadAttributed") else ""))
    for racine in pile.get("callStackRootFrames", []):
        for cadre, profondeur in cadres(racine):
            nom = cadre.get("binaryName", "?")
            adresse = cadre["address"]
            texte = f"{nom} 0x{adresse:x}"
            if nom == "Synfus":
                chargement = adresse - cadre["offsetIntoBinaryTextSegment"]
                texte = subprocess.run(["atos", "-o", dwarf, "-arch", arch, "-l", hex(chargement), hex(adresse)],
                                       capture_output=True, text=True).stdout.strip() or texte
            print("  " * profondeur + texte)
PY
