#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
xcodebuild -project TheZoneRemastered.xcodeproj -scheme "The Zone iPadOS" -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
