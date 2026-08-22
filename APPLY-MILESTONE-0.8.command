#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
chmod +x Tools/verify-milestone-0.8.command Tools/test-zonecore.sh
./Tools/verify-milestone-0.8.command
print "Milestone 0.8 applied. Build native macOS with ./Tools/build-macos.command or Xcode: The Zone macOS > My Mac."
