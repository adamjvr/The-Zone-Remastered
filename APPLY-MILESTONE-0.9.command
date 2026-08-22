#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

BASE_COMMIT="b7e4bdcbc38f266fa460249c26566a3506f123db"

if [[ ! -d .git ]]; then
  print -u2 "ERROR: extract this update into the The-Zone-Remastered repository root before running it."
  exit 2
fi

if ! git cat-file -e "${BASE_COMMIT}^{commit}" 2>/dev/null; then
  print -u2 "ERROR: required Milestone 0.8 base commit ${BASE_COMMIT[1,8]} is not present locally."
  exit 3
fi

if ! git merge-base --is-ancestor "$BASE_COMMIT" HEAD; then
  print -u2 "ERROR: HEAD does not descend from the committed Milestone 0.8 checkpoint ${BASE_COMMIT[1,8]}."
  exit 4
fi

if [[ -f FILES.sha256 ]]; then
  shasum -a 256 -c FILES.sha256
fi

chmod +x Tools/verify-milestone-0.9.command Tools/test-zonecore.sh
./Tools/verify-milestone-0.9.command

print "Milestone 0.9 applied and verified on top of committed 0.8."
print "Build native macOS with ./Tools/build-macos.command or Xcode: The Zone macOS > My Mac."
