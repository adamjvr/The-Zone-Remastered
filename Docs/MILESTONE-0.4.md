# The Zone Remastered — Milestone 0.4

## Collision Physics, Phase 1

Milestone 0.4 replaces the Milestone 0.3 placeholder player collision rule (`overlap => -1 shield every frame`) with collision behavior recovered from the native PowerPC executable.

This milestone deliberately concentrates on the physical interactions visible in Wave 1: the player ship, asteroids, and the Mother Base. It also promotes the recovered generic impact formulas for the other ordinary collision types so later waves can use the same code without another physics rewrite.

## Recovered binary anchors

- `0x1708C` — broad-phase rectangle test followed by exact nonzero-sprite-pixel overlap.
- `0x174E8` — dedicated player-vs-Mother-Base/HQ collision path.
- `0x181A4` — object-pair collision-response dispatcher.
- `0x19D1C` — exchange fixed/integer object velocities.
- `0x19D40` — exchange mixed fixed/continuous velocity representations.
- `0x19DD8` — exchange continuous float velocities.
- `0x19DFC` — ordinary player-vs-object collision response and shield damage.

The portable engine stores one screen-space velocity representation, so the fixed/float exchange helpers collapse to a direct `(vx, vy)` exchange at the ZoneCore boundary.

## Ordinary player impact damage

The original `0x19DFC` routine measures the ship's speed before and after the collision velocity exchange. For the ordinary exchange cases, the post-impact ship speed is the collider's pre-impact speed, so the recovered semantic formula is:

```text
speed_sum = ship_speed_before + ship_speed_after
raw_damage = trunc(speed_sum / type_divisor)
raw_damage = min(raw_damage, type_cap)
shield_damage = trunc(raw_damage / shield_strength)
```

Recovered divisors:

| Collider | Divisor |
|---|---:|
| Stone (`ston`) | 6 |
| Bloody (`bloo`) | 5 |
| Asteroid (`aste`) | 5 |
| Empire Fighter (`swar`) | 5 |
| Raider (`raid`) | 4 |
| Off-Shore (`moto`) | 4 |
| Seeker (`seek`) | 4 |
| Bee (`bee!`) | 3 |
| Rotor (`roto`) | 3 |
| Big Rock (`rock`) | 3 |

Recovered caps:

- Big Rock: 30
- Raider / Bee / Seeker: 20
- other ordinary types in this path: 8

The current default Classic shield-strength multiplier is `1.0`. Equipment-driven shield-strength changes remain to be wired into the live game state.

## Mother Base / HQ impacts

`0x174E8` has a separate rule:

```text
shield_damage = trunc(ship_speed_before * 0.75 / shield_strength)
shield_damage = min(shield_damage, 30)
```

The shipping packed-data constant used here is exactly `0.75`.

After calculating damage, the routine exchanges the ship and base continuous velocity vectors. This produces a distinctive original behavior: hitting a stationary Mother Base can stop the ship and transfer the ship's motion to the base.

Milestone 0.4 now makes Mother Bases integrate collision-transferred velocity so this behavior is visible rather than immediately discarded.

## Contact handling

The classic executable tracks collision/hit state through object fields and spatial bookkeeping. ZoneCore currently represents the equivalent event boundary with an explicit contact latch:

- first frame of a new overlap => apply response/damage once;
- continued overlap => do not re-apply or swap velocities back;
- separation => re-arm the contact.

This is intentionally a portable semantic mechanism, not a claim that the original source contained a `player_contact` field.

The same strategy is used for Wave-1 world/world contacts to prevent a pair of overlapping bodies from exchanging velocities every frame.

## Wave-1 world physics

For the body combinations currently instantiated in Wave 1 (asteroids and Mother Base), the recovered `0x181A4` paths use the fixed/mixed/float velocity-exchange helpers. Milestone 0.4 therefore enables exact-pixel world/world contact detection and one-shot velocity exchange for those physical bodies.

## Regression coverage

The headless test now verifies:

- all prior 48-frame muzzle/orientation behavior;
- recovered impact divisors and caps;
- shield-strength division order;
- asteroid impact velocity exchange;
- asteroid impact damage only once during sustained overlap;
- Mother Base `0.75` impact rule;
- ship-to-base momentum transfer;
- world-body pair exchange only once during sustained overlap.

## Still intentionally deferred

Collision work is not complete. The next collision/gameplay phases still need:

- exact special-case pair consequences across the complete `0x181A4` matrix;
- exact object hit-state/dirty-state timing instead of the portable contact-latch equivalent;
- Big Rock -> Asteroid/Stone fragmentation and drop probabilities;
- projectile variants and enemy projectile consequences;
- pickup/equipment collision effects;
- player shield depletion -> original death/respawn path (`0x1663C`);
- toroidal collision testing across opposite viewport edges;
- complete Mother Base and Rotor state machines;
- exact spawn placement from `0x13D5C`.

No Xcode target/build-setting changes are made in 0.4.
