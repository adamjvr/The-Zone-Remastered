# Milestone 0.3 — Real Zone, phase 1

This milestone starts replacing the demonstration sandbox with the shipping game's recovered world rules.

## Orientation / gunfire correction

The first playable scaffold treated recovered movement components as modern `(x,y)`. The PPC binary and classic Macintosh data layout show that the relevant components are in **vertical/horizontal** order.

The portable mapping is therefore:

```text
original vertical   = -sin(angle) -> screen Y
original horizontal =  cos(angle) -> screen X
```

The original `Math` resource ID 2 is 192 bytes: 48 pairs of big-endian signed 16-bit muzzle offsets. PPC `0x12224` indexes that table with the visible ship frame before constructing a `shot`.

Canonical examples:

```text
frame  0: (+16,   0)
frame 12: (  0, -16)
frame 24: (-16,   0)
frame 36: (  0, +16)
```

ZoneCore now uses those exact offsets. The raw shipping resource is preserved at:

```text
Docs/ReverseEngineering/Resources/Math_00002_MuzzleOffsets.bin
```

## Recovered wave 1

For both fixed difficulty tables, wave 1 contains:

```text
Mother Bases: 1
Head Quarters: 0
Raiders:       0
Seekers:       0
Bee limit:     1
Asteroids:     wave + 2 = 3
```

Milestone 0.3 now instantiates the 3 `aste` objects and 1 `moth` object from the real sprite banks and reports `BASES 1` in the HUD.

The exact Mother Base behavior/Bee request state machine is deliberately left for the next lift rather than approximated here. Spawn *counts/classes* are recovered; spawn *placement* is still an isolated deterministic placeholder pending completion of PPC `0x13D5C`.

## Damage / scoring now live

- `aste`: 1 damage point, 20 points.
- `moth`: 40 damage points in Professional mode, 750 points.

Projectile collision continues to use the original nonzero-pixel sprite masks.

## Explosion bank correction

Recovered `expl` configuration selects banks by destroyed object side:

```text
16px -> Spri 700..710
24px -> Spri 3000..3010
32px -> Spri 600..610
48px -> Spri 20000..20010
```

The 20-frame `1500..1519` bank is reserved for ship/mine-style explosions.

## Next

Milestone 0.4 will focus on the Mother Base/Bee state machine, exact wave spawn placement, real shot/fire modes, and base destruction/wave lifecycle.
