# Damage model (`0x307C`, `0x172DC`, `0x192FC`)

The binary uses cumulative **damage points**, not a universal number-of-collisions counter.

Ordinary player shots use:

```c
damage = weapon_damage_level + 1; // 1..4
```

at `0x172DC`. This matches the manual's yellow-to-red shot progression (1 through 4 hit/damage units per projectile).

`0x307C` installs difficulty-dependent destruction thresholds:

| Type | Professional | Beginner |
| --- | ---: | ---: |
| Mother Base (`moth`) | 40 | 20 |
| HQ (`base`) | 25 | 14 |
| Raider (`raid`) | 8 | 5 |
| Bee (`bee!`) | 5 | 4 |
| Rotor (`roto`) | 20 | 10 |
| Seeker (`seek`) | 15 | 8 |
| Bloody (`bloo`) | 5 | 4 |

`rock` has a literal threshold of 4 damage points before entering its fragmentation/spawn logic. Standard asteroids, stones, Empire Fighters, and Off-Shores use immediate/single-damage destruction paths.

The manual rounds some beginner figures (for example HQ says 15 while v1.5.1 binary stores 14); the binary values above are authoritative for behavioral reconstruction.
