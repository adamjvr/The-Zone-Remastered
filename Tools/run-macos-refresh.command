#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-native}"
DYNAMICS="${2:-auto}"
case "$MODE" in
  native)
    unset ZONE_PRESENTATION_HZ || true
    echo "Presentation target: native display maximum"
    ;;
  ''|*[!0-9]*)
    echo "usage: $0 [native|60|120|144|165|240|<positive Hz>] [auto|classic|high]"
    exit 2
    ;;
  *)
    if (( MODE <= 0 )); then
      echo "presentation Hz must be positive"
      exit 2
    fi
    export ZONE_PRESENTATION_HZ="$MODE"
    echo "Presentation target: ${MODE} Hz (clamped to display maximum)"
    ;;
esac

case "$DYNAMICS" in
  auto)
    if [[ "$MODE" == "native" ]]; then
      export ZONE_HIGH_RATE_DYNAMICS=1
    elif (( MODE > 60 )); then
      export ZONE_HIGH_RATE_DYNAMICS=1
    else
      export ZONE_HIGH_RATE_DYNAMICS=0
    fi
    ;;
  classic)
    export ZONE_HIGH_RATE_DYNAMICS=0
    ;;
  high)
    export ZONE_HIGH_RATE_DYNAMICS=1
    ;;
  *)
    echo "dynamics mode must be auto, classic, or high"
    exit 2
    ;;
esac

if [[ "$ZONE_HIGH_RATE_DYNAMICS" == "1" ]]; then
  echo "Dynamics: 720-Hz real motion / 60-Hz Classic decisions+collision"
else
  echo "Dynamics: accepted 1.4 Classic 60-Hz step path"
fi

./Tools/run-macos-perf.command
