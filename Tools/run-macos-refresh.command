#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-native}"
case "$MODE" in
  native)
    unset ZONE_PRESENTATION_HZ || true
    echo "Presentation target: native display maximum"
    ;;
  ''|*[!0-9]*)
    echo "usage: $0 [native|60|120|144|165|240|<positive Hz>]"
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

./Tools/run-macos-perf.command
