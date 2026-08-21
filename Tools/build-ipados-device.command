#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
./Tools/verify-native-targets.command
xcodebuild \
  -project TheZoneRemastered.xcodeproj \
  -scheme "The Zone iPadOS" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData-iPadDevice \
  CODE_SIGNING_ALLOWED=NO \
  build
