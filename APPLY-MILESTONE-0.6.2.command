#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
chmod +x Tools/test-zonecore.sh Tools/verify-milestone-0.6.2.command
./Tools/verify-milestone-0.6.2.command
print "Milestone 0.6.2 consistency repair applied. Now build native macOS with ./Tools/build-macos.command or Xcode: The Zone macOS > My Mac."
