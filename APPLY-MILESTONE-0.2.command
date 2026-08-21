#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

[[ -d .git ]] || { print -u2 "ERROR: extract this ZIP directly into the The-Zone-Remastered repository root."; exit 1; }

print "=== The Zone Remastered Milestone 0.2 ==="
print "Base HEAD: $(git rev-parse --short HEAD)"
print

chmod +x Tools/*.command Tools/*.sh Tools/*.py 2>/dev/null || true
python3 Tools/patch-xcodeproj-milestone-0.2.py

print
print "=== Verification ==="
./Tools/verify-milestone-0.2.command

print
print "Milestone 0.2 applied successfully."
print "Build the verified native Mac target with:"
print "  ./Tools/build-macos.command"
print
print "Or in Xcode select: The Zone macOS > My Mac, then press Command-B / Command-R."
