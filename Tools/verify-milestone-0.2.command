#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

fail() { print -u2 "ERROR: $*"; exit 1; }

[[ -f Docs/images/TheZoneRemastered-Ship.png ]] || fail "documentation hero image missing"
[[ -f macOS/Assets.xcassets/AppIcon.appiconset/Contents.json ]] || fail "AppIcon Contents.json missing"

for f in \
  AppIcon-16.png AppIcon-16@2x.png \
  AppIcon-32.png AppIcon-32@2x.png \
  AppIcon-128.png AppIcon-128@2x.png \
  AppIcon-256.png AppIcon-256@2x.png \
  AppIcon-512.png AppIcon-512@2x.png; do
  [[ -f "macOS/Assets.xcassets/AppIcon.appiconset/$f" ]] || fail "missing icon asset $f"
done

grep -q 'Assets.xcassets in Resources' TheZoneRemastered.xcodeproj/project.pbxproj || fail "Xcode project does not compile Assets.xcassets"
grep -q 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon' TheZoneRemastered.xcodeproj/project.pbxproj || fail "Mac target AppIcon build setting missing"
grep -q 'Docs/images/TheZoneRemastered-Ship.png' README.md || fail "README hero image reference missing"

grep -q 'tz_apply_player_thrust' ZoneCore/src/zone_core.c || fail "recovered player thrust helper not integrated"
grep -q 'g_neg_sin_360' ZoneCore/src/zone_core.c || fail "recovered -sin/cos direction basis not integrated"

./Tools/test-zonecore.sh
./Tools/verify-native-targets.command

print "Milestone 0.2 verification: PASS"
