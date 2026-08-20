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

The `bloo`, `raid`, `bee!`, and `seek` random-fire paths additionally require
`object+72 < 3`. The shared shot-spawn tail increments `object+72`, creates a
`fire` object, links it back to the shooter through object link1, and plays the
appropriate SFX.

Strict signed-Random windows observed:

- `bloo`: `(10000, 13500)`
- `bee!`: `(10000, 15000)`
- `raid`: `(10000, 20000)`
- `seek`: `(10000, 11000)`

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
