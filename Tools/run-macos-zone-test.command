#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

if (( $# < 1 || $# > 3 )); then
  echo "usage: $0 <zone 1-18> [native|60|120|144|165|240|<Hz>] [auto|classic|high]" >&2
  exit 2
fi

ZONE="$1"
MODE="${2:-native}"
DYNAMICS="${3:-high}"

case "$ZONE" in
  ''|*[!0-9]*)
    echo "ERROR: zone must be an integer from 1 through 18." >&2
    exit 2
    ;;
esac
if (( ZONE < 1 || ZONE > 18 )); then
  echo "ERROR: zone must be from 1 through 18." >&2
  exit 2
fi

export ZONE_TEST_MODE=1
export ZONE_TEST_START_ZONE="$ZONE"

echo "============================================================"
echo "The Zone Remastered — forensic Zone jump"
echo "============================================================"
echo "Starting fixed Zone: $ZONE"
echo "Test mode: enabled"
echo "Presentation: $MODE"
echo "Dynamics: $DYNAMICS"
if [[ "${ZONE_BEE_TRACE:-0}" != "0" ]]; then
  echo "Bee request trace: enabled"
fi
if [[ "${ZONE_BEE_FIRE_TRACE:-0}" != "0" ]]; then
  echo "Bee fire trace: enabled"
fi
echo
echo "NOTE: fixed-wave composition is correct for this Zone, but a direct jump"
echo "does not recreate the RNG history of naturally playing every earlier Zone."
echo

./Tools/run-macos-refresh.command "$MODE" "$DYNAMICS"
