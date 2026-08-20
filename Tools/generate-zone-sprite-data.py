#!/usr/bin/env python3
"""Generate ZoneCore's exact indexed sprite-pixel database from extracted Spri resources.

Spri format recovered from TheZone 1.5.1:
  u16be side
  u16be area (= side * side)
  u8    mask_type
  u8    unused
  u8    indexed_pixels[area]
  ...   68K blitter bytes (ignored by native PPC/remaster collision path)

Palette index 0 is transparent in the original PPC renderer.
"""
from __future__ import annotations
import argparse
import re
from pathlib import Path

ID_RE = re.compile(r"Spri__\+(\d+)\.bin$")

def read_sprites(src: Path):
    rows = []
    for p in src.glob("Spri__+*.bin"):
        m = ID_RE.match(p.name)
        if not m:
            continue
        sid = int(m.group(1))
        b = p.read_bytes()
        if len(b) < 6:
            raise ValueError(f"short Spri {p}")
        side = int.from_bytes(b[0:2], "big")
        area = int.from_bytes(b[2:4], "big")
        if area != side * side:
            raise ValueError(f"Spri {sid}: area {area} != {side}^2")
        if len(b) < 6 + area:
            raise ValueError(f"Spri {sid}: missing pixel payload")
        rows.append((sid, side, b[6:6+area]))
    rows.sort()
    return rows

def emit_array(f, name: str, data: bytes):
    f.write(f"static const uint8_t {name}[] = {{\n")
    for i in range(0, len(data), 24):
        f.write("  " + ",".join(str(x) for x in data[i:i+24]) + ",\n")
    f.write("};\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    sprites = read_sprites(args.source)
    if len(sprites) != 651:
        raise SystemExit(f"expected 651 Spri resources, got {len(sprites)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as f:
        f.write('#include "zone_sprite_data.h"\n\n')
        f.write("/* Generated from TheZone 1.5.1 Spri resources.\n")
        f.write(" * This intentionally stores only the 6-byte header-derived dimensions\n")
        f.write(" * and indexed pixel payload. The original PPC build discards each Spri's\n")
        f.write(" * appended 68K blitter and renders pixels natively; index 0 is transparent.\n")
        f.write(" */\n\n")
        for sid, side, pixels in sprites:
            emit_array(f, f"px_{sid}", pixels)
        f.write("\nstatic const ZoneSpritePixels kSprites[] = {\n")
        for sid, side, _ in sprites:
            f.write(f"  {{{sid}, {side}, px_{sid}}},\n")
        f.write("};\n\n")
        f.write("const ZoneSpritePixels *zone_sprite_pixels(int32_t sprite_id) {\n")
        f.write("  size_t lo = 0, hi = sizeof(kSprites) / sizeof(kSprites[0]);\n")
        f.write("  while (lo < hi) {\n")
        f.write("    size_t mid = lo + (hi - lo) / 2;\n")
        f.write("    if (kSprites[mid].sprite_id < sprite_id) lo = mid + 1; else hi = mid;\n")
        f.write("  }\n")
        f.write("  if (lo < sizeof(kSprites) / sizeof(kSprites[0]) && kSprites[lo].sprite_id == sprite_id) return &kSprites[lo];\n")
        f.write("  return 0;\n")
        f.write("}\n\n")
        f.write("size_t zone_sprite_count(void) { return sizeof(kSprites) / sizeof(kSprites[0]); }\n")
    print(f"generated {len(sprites)} sprites -> {args.output}")

if __name__ == "__main__":
    main()
