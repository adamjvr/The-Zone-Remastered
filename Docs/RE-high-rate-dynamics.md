# Architecture Note — High-Rate Dynamics Without Manufactured Frames

Milestone 1.5 is the first phase in which high-refresh presentation receives genuinely new simulation positions between Classic behavior boundaries.

## Invariants

1. `ZONE_MASTER_HZ = 720`.
2. `ZONE_CLASSIC_HZ = 60`.
3. `ZONE_MASTER_TICKS_PER_CLASSIC_STEP = 12`.
4. Recovered discrete behavior executes once per Classic interval.
5. Position integration executes once per master tick at `1/12` of the old per-step displacement.
6. Classic collision remains at the end of the 12-tick interval.
7. `zone_game_step()` continues to represent the old complete Classic interval.

## Temporal ordering

The decomposition mirrors the ordering of the existing monolithic step rather than merely distributing arbitrary work:

```text
Classic interval begins
    behavior_tick++
    player decision / thrust / fire
    enemy AI / RNG / firing

    motion 1/12
    motion 2/12
    ...
    motion 12/12

    projectile lifetime + collision
    pickups
    player/body collision
    world/world collision
    wave lifecycle
    explosion age
Classic interval ends
```

This preserves the important original ordering that newly spawned projectiles move during the same interval before their first collision test, while objects created by a collision do not receive movement until the following interval.

## Rotor orbit

Rotor orbit state writes a full desired Classic displacement into velocity before common integration. Splitting common integration by 12 is therefore correct: the twelve substeps sum to the same recovered orbit correction at the Classic boundary while allowing the display to observe intermediate positions.

## Hit flash ordering

The monolithic path ages an existing base hit flash before projectile collision can set the next one. In the decomposed path, flash aging is kept on the phase-11 Classic boundary immediately before projectile collision. This prevents a phase-11 hit followed by a phase-0 substep in the same presentation callback from clearing the flash before it can be drawn.

## Collision policy

Classic collision is intentionally not a continuous-dynamics component in Phase 1. Exact-pixel collision is observable rule behavior and remains sampled once per Classic interval. Future high-rate collision belongs to an explicit Remastered policy with separate regression expectations.

## Host batching

The Metal callback does not need a 720-Hz timer. The monotonic `ZoneTimebase` already tells the host how many master ticks elapsed since the previous presentation. At 240 Hz, a normal callback advances roughly three real master ticks; at 120 Hz roughly six; at 60 Hz twelve. Each of those ticks executes in ZoneCore before the current state is rendered.

The host still bounds catch-up work to eight Classic intervals (96 master ticks) after a stall, matching the accepted 1.4 anti-spiral policy.
