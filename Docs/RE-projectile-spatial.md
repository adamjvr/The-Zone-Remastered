# Reverse-engineering notes — projectile spatial activity and retirement

## `shot` action — PPC `0x11D44`

The handler begins by reading byte `+128` and comparing it with zero. Zero returns immediately to the common object-action tail. Nonzero activity copies object `+48/+50` into `+36/+38` and calls `0x172DC`, the player-shot collision path.

There is no age or lifetime counter in this action.

## `fire` action — PPC `0x11D6C`

The hostile projectile action is structurally parallel: `+128 == 0` returns, otherwise cached motion fields are copied and `0x1801C` runs hostile-projectile collision.

Again, there is no age/lifetime decrement.

## Spatial pass — PPC `0xED44..0xF168`

For objects whose `+128` state is live, the pass performs object behavior and motion. It then compares screen coordinates against the sprite side and current zone dimensions. The recovered horizontal rule is equivalent to:

```text
-screenSide < screenX < zoneWidth
```

and vertical activity is equivalent to:

```text
-screenSide < screenY < zoneHeight
```

Crossing either axis records a spatial-out flag in the two halfwords at `+32/+34`.

The later pass at `0xF080` detects those flags, clears byte `+128`, and dispatches by object type.

## Type dispatch after `+128` clears

The constants in the `0xF0E0..0xF164` dispatch decode directly to:

- `fire`
- `expl`
- `shot`

`fire` enters common object removal. `expl` enters explosion finalization. `shot` enters the unlink routine at `0xDFBC`.

`0xDFBC` walks the object's `+138` next-pointer chain, splices the target out, scans the 80-entry object table for the corresponding record, clears that table's occupied byte, and decrements the shared live-object count. This is sufficient evidence that an off-region `shot` is freed rather than merely hidden.

## Coordinate translation into ZoneCore

Classic object screen positions are top-left-oriented; ZoneCore render/collision positions are sprite centers. Therefore the Classic left test `screenX <= -side` maps to portable center `x <= -side/2`, and Classic `screenX >= width` maps to portable `x >= width + side/2`.

This translation is used only for projectiles in 1.9. Existing wrapped world-body motion is intentionally unchanged because promoting the rest of the spatial/object-list model requires additional per-type analysis.

## High-refresh constraint

The original spatial maintenance belongs to the Classic object pass. Milestone 1.9 therefore integrates projectile coordinates on every 720-Hz master tick but evaluates the off-region `+128` consequence only at the existing 60-Hz Classic end boundary. Sampling it 12× more often would be a remaster policy change, not a fidelity lift.
