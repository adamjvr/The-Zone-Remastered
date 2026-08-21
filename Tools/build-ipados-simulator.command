#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
./Tools/verify-native-targets.command
xcodebuild \
  -project TheZoneRemastered.xcodeproj \
  -scheme "The Zone iPadOS" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
