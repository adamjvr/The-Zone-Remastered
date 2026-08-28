#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
MODE="${1:-native}"
DYNAMICS="${2:-high}"
export ZONE_BEE_TRACE=1
export ZONE_BEE_FIRE_TRACE=1

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 3A firing trace"
echo "============================================================"
echo "Gameplay rules are unchanged."
echo "Play normally through Zones 2-4 if practical, then quit normally."
echo
BEFORE="$(ls -1t build/perf-logs/zone-perf-*.log 2>/dev/null | head -n1 || true)"
./Tools/run-macos-refresh.command "$MODE" "$DYNAMICS"
LATEST="$(ls -1t build/perf-logs/zone-perf-*.log 2>/dev/null | head -n1 || true)"
[[ -n "$LATEST" ]] || { echo "ERROR: no perf log produced" >&2; exit 1; }
[[ -z "$BEFORE" || "$LATEST" != "$BEFORE" ]] || { echo "ERROR: no new perf log produced" >&2; exit 1; }
echo
python3 Tools/summarize-bee-fire-trace.py "$LATEST"
