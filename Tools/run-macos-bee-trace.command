#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

MODE="${1:-native}"
DYNAMICS="${2:-high}"
export ZONE_BEE_TRACE=1

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 0 trace session"
echo "============================================================"
echo "Bee gameplay behavior is UNCHANGED."
echo "Play normally through several waves, then quit normally."
echo

BEFORE="$(ls -1t build/perf-logs/zone-perf-*.log 2>/dev/null | head -n 1 || true)"
./Tools/run-macos-refresh.command "$MODE" "$DYNAMICS"
LATEST="$(ls -1t build/perf-logs/zone-perf-*.log 2>/dev/null | head -n 1 || true)"

if [[ -z "$LATEST" ]]; then
  echo "ERROR: no perf log was produced." >&2
  exit 1
fi
if [[ -n "$BEFORE" && "$LATEST" == "$BEFORE" ]]; then
  echo "ERROR: no new perf log was produced." >&2
  exit 1
fi

echo
echo "Bee trace source log: $LATEST"
python3 Tools/summarize-bee-trace.py "$LATEST"
