#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
chmod +x Tools/test-zonecore.sh Tools/verify-milestone-0.6.1.command
./Tools/verify-milestone-0.6.1.command
if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi
print "Milestone 0.6.1 hotfix applied. Build native macOS with ./Tools/build-macos.command or Xcode: The Zone macOS > My Mac."
