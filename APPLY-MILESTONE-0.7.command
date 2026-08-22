#!/bin/sh
set -eu
cd "$(dirname "$0")"
chmod +x Tools/test-zonecore.sh Tools/verify-milestone-0.7.command
./Tools/verify-milestone-0.7.command
printf '%s\n' 'Milestone 0.7 applied. Build native macOS with ./Tools/build-macos.command or Xcode: The Zone macOS > My Mac.'
