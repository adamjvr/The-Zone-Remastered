#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

./Tools/test-zonecore.sh

grep -q 'tz_player_impact_damage' ZoneCore/Recovered/src/collision.c
grep -q 'tz_player_base_impact_damage' ZoneCore/Recovered/src/collision.c
grep -q 'player_contact' ZoneCore/src/zone_core.c
grep -q 'world_contact_bits' ZoneCore/src/zone_core.c
grep -q '0x19DFC' Docs/MILESTONE-0.4.md

print "Milestone 0.4 collision-physics verification: PASS"
