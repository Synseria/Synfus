#!/bin/bash
# test.sh — suite de tests (Swift Testing), sortie filtrée.
#   sh test.sh                      → suite complète
#   sh test.sh PreferencesTests     → une suite, ou un test par son nom
#   sh test.sh Rotation Position    → plusieurs filtres (l'un ou l'autre)
#   sh test.sh -- --parallel        → options brutes passées à `swift test`
#   sh test.sh --help
#
# Les tests portent sur la logique pure : ni Accessibilité, ni écran, ni
# identité de signature. Le calibrage sur une vraie capture reste à part :
#   SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png sh test.sh RealCapture
[ -n "${BASH_VERSION:-}" ] || exec /bin/bash "$0" "$@"
case ":${SHELLOPTS:-}:" in *:posix:*) exec /bin/bash "$0" "$@" ;; esac
set -uo pipefail

cd "$(dirname "$0")"

FILTRES=(); BRUT=()
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --) shift; BRUT+=("$@"); break ;;
        *) FILTRES+=("$1") ;;
    esac
    shift
done
ARGS=()
if [ ${#FILTRES[@]} -gt 0 ]; then
    ARGS=(--filter "$(IFS='|'; echo "${FILTRES[*]}")")
fi

LOG="$(mktemp "${TMPDIR:-/tmp}/Synfus-test.XXXXXX")"
swift test ${ARGS[@]+"${ARGS[@]}"} ${BRUT[@]+"${BRUT[@]}"} >"$LOG" 2>&1
RC=$?
# Les échecs avec leur contexte, les erreurs de compilation, et le bilan.
grep -E "error:|✘|recorded an issue|↳" "$LOG" | grep -vE "Testing Library Version|Target Platform" | head -60
grep -E "^✔ Test run|^✘ Test run|Test run with" "$LOG" | tail -1
[ "$RC" = "0" ] || { grep -q "Test run" "$LOG" || tail -20 "$LOG"; }
rm -f "$LOG"
exit "$RC"
