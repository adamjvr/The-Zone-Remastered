#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

SOURCE="Docs/images/TheZoneRemastered-Ship.png"
OUT="macOS/Assets.xcassets/AppIcon.appiconset"

[[ -f "$SOURCE" ]] || { print -u2 "Missing source artwork: $SOURCE"; exit 1; }
mkdir -p "$OUT"

resize() {
  local pixels="$1" name="$2"
  /usr/bin/sips -s format png -z "$pixels" "$pixels" "$SOURCE" --out "$OUT/$name" >/dev/null
}

resize 16   AppIcon-16.png
resize 32   AppIcon-16@2x.png
resize 32   AppIcon-32.png
resize 64   AppIcon-32@2x.png
resize 128  AppIcon-128.png
resize 256  AppIcon-128@2x.png
resize 256  AppIcon-256.png
resize 512  AppIcon-256@2x.png
resize 512  AppIcon-512.png
resize 1024 AppIcon-512@2x.png

print "Regenerated native macOS AppIcon assets from $SOURCE"
