# Enemy behavior lift

These values come from the PPC behavior switch at `0x14914`; they are not
balance guesses.

## Shared target steering

Several enemies compute the player's wrapped world target and then adjust each
signed 16-bit velocity component by one step toward it.

| Type | Update cadence | Per-axis cap | Fire window when eligible |
|---|---:|---:|---:|
| `swar` | every 4 behavior updates | ±8 | none in this handler |
| `bloo` | every 3 behavior updates | ±9 | `10000 < (int16)Random() < 13500` |
| `moto` | every behavior update | ±10 | none in this handler |
| `raid` | every 2 behavior updates | ±9 | `10000 < (int16)Random() < 20000` |

Facing is computed with the game's angle helper and a 24-frame orientation:
`frame = angle / 15`.

### Shooting gates

The `bloo`, `raid`, `bee!`, `seek`, and `roto` random-fire paths additionally
require `object+72 < 3`. The shared shot-spawn tail increments `object+72`,
creates a `fire` object, links it back to the shooter through object link1, and
plays the appropriate SFX.

Strict signed-Random windows observed:

- `bloo`: `(10000, 13500)`
- `bee!`: `(10000, 15000)`
- `raid`: `(10000, 20000)`
- `seek`: `(10000, 11000)`
- `roto`: `(10000, 15000)`

Because Classic Mac `Random()` is treated as signed 16-bit here, these are
literal comparison windows, not percentages reconstructed from observation.

## Seeker (`seek`) — `0x15944`

The handler calculates squared distance to the wrapped player target and uses
the literal `40000.0`, i.e. a radius of exactly 200 units.

```
if distance_squared <= 40000:
    speed = current_maximum_speed
else:
    speed = cruise_speed

vx = trunc(speed * x_motion_scale * -sin(angle))
vy = trunc(speed * y_motion_scale *  cos(angle))
```

Startup defaults establish `x_motion_scale ≈ 0.325` and
`y_motion_scale = 0.25`. At a fresh game, max speed is 25 and the derived
cruise-speed global is 10, so the seeker changes from roughly 40% speed to full
speed when the player enters the 200-unit radius. This directly explains the
manual's statement that Seekers move slowly and then "jump towards you".

## Bee (`bee!`) — `0x154A8`

Bee movement is maintained as float vector components at object offsets
100/104. Each retarget update tentatively adds one unit lookup vector
`(-sin(angle), cos(angle))`.

The candidate vector is accepted if its squared magnitude is at or below the
runtime maximum-speed-squared value, or if it reduces the current magnitude.
If neither is true, the vector is clamped directly to maximum speed in the new
heading. `0xE6F4` then converts the continuous vector into integer world-step
fields +40/+42.

A hit/stun state at object+66 uses object+92 as a tick timestamp and suppresses
normal retargeting for 60 ticks.

## Rotor (`roto`) — `0x15BC8..0x16124`

The Rotor is a linked guard object. Its link1 at object `+142` points to a
Mother Base or Headquarters; fixed-wave construction stores the reciprocal
Rotor pointer in the parent's link2 (`+146`). The handler validates that parent
on every update.

Rotor byte `+131` is the live state selector:

- **0 — orbit:** heading `+54` advances by 4 degrees and wraps at 360. The
  visible 24-frame orientation is tangent to the orbit: `(heading + 90) / 15`.
  The target point is a **40-unit** circle around the parent.
- **1 — attack:** aim at the player and pursue at recovered speed **10**. If
  parent distance reaches the **160-unit** leash in the 640-unit Classic zone,
  switch to state 2.
- **2 — return:** aim at the parent and return at recovered speed **20**. Once
  parent distance is at or below **40 units**, switch back to state 0.

Before state dispatch, an orbiting Rotor switches immediately to attack when
player distance squared is at or below `10000.0` — exactly **100 units**.

The collision dispatcher supplies two additional wake paths: a valid player
shot on a Rotor writes `+131 = 1` before the lethal-threshold check, and a
nonlethal hit on a Mother Base wakes its linked Rotor through parent link2.

Rotor firing reaches the shared hostile-fire tail with the strict signed-Random
window `10000 < Random() < 15000` and the same `object+72 < 3` active-shot cap
as the other firing enemies.

If link1 is missing or no longer points to `moth`/`base`, the native handler
falls through to a direct pursuit path instead of continuing the orbit state.
