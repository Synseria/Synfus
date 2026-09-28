#!/bin/bash
# run.sh — build de développement de Synfus, sortie filtrée.
#   sh run.sh                     → build Debug signé : .build/dev/Synfus.app
#   sh run.sh --start             → build puis lance cette app (l'instance en
#                                   cours est quittée : une seule à la fois)
#   sh run.sh --install [--start] → build Release (build.sh) puis installe
#                                   dans /Applications ; --start la relance
#   sh run.sh --help
#
# Le build de développement est signé avec la même identité que la release
# (signature.sh) : l'autorisation Accessibilité, liée à l'identité, tient
# d'un build à l'autre.
[ -n "${BASH_VERSION:-}" ] || exec /bin/bash "$0" "$@"
case ":${SHELLOPTS:-}:" in *:posix:*) exec /bin/bash "$0" "$@" ;; esac
set -uo pipefail

cd "$(dirname "$0")"
NAME="Synfus"
BUNDLE_ID="fr.synseria.Synfus"

aide() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

INSTALL=0; START=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --start) START=1 ;;
        -h|--help) aide; exit 0 ;;
        *) echo "run.sh : option inconnue « $arg »" >&2; aide >&2; exit 2 ;;
    esac
done

# Quitte proprement l'instance en cours — Apple Event d'abord, pour que la
# position de la barre soit écrite (`flushPendingOrigin`) —, puis s'assure
# qu'elle est bien partie.
quitter() {
    pgrep -x "$NAME" >/dev/null || return 0
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x "$NAME" >/dev/null || return 0; sleep 0.3; done
    pkill -x "$NAME" 2>/dev/null || true
    sleep 0.5
}

if [ "$INSTALL" = "1" ]; then
    ARGS=()
    MODE_BUILD=""
else
    ARGS=(--debug)
    MODE_BUILD="Debug"
fi

LOG="$(mktemp "${TMPDIR:-/tmp}/Synfus-run.XXXXXX")"
bash ./build.sh ${ARGS[@]+"${ARGS[@]}"} >"$LOG" 2>&1
RC=$?
# Le détail utile seulement : erreurs, avertissements du code, étapes.
grep -E "error:|warning: |^==> |^\[signature\]" "$LOG" | grep -v "unhandled; explicitly declare" | awk '!vu[$0]++' | head -80
if [ "$RC" = "0" ]; then
    echo "** BUILD SUCCEEDED **${MODE_BUILD:+ ($MODE_BUILD)}"
else
    tail -20 "$LOG"
    echo "** BUILD FAILED **"
    rm -f "$LOG"
    exit "$RC"
fi
rm -f "$LOG"

if [ "$INSTALL" = "1" ]; then
    quitter
    rm -rf "/Applications/$NAME.app"
    cp -R "dist/$NAME.app" /Applications/
    echo "==> Installé : /Applications/$NAME.app"
    # Le plugin Stream Deck n'est pas installé ici : c'est optionnel, et
    # Synfus le propose (Réglages → Stream Deck → « Installer le plugin »).
    APP="/Applications/$NAME.app"
else
    APP=".build/dev/$NAME.app"
fi

if [ "$START" = "1" ]; then
    [ "$INSTALL" = "1" ] || quitter
    open -n "$APP"
    echo "==> Lancé : $APP"
fi
