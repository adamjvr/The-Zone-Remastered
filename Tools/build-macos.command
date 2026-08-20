#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
xcodebuild -project TheZoneRemastered.xcodeproj -scheme "The Zone macOS" -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
