# The Zone Remastered — Milestone 0.5

## Destruction, Pickups & Progression

Milestone 0.5 promotes another set of behaviors recovered from the native PowerPC game into the live `ZoneCore`. The focus is the consequence chain after firing and collisions: projectile capacity, object destruction, drops, collectible effects, Big Rock fragmentation, and the first portable representation of the ship death/respawn lifecycle.

## Exact recovered progression constants

The following values are no longer milestone guesses.

### Initial maximum speed

The packed PowerPC data used by the new-game path contains:

```text
maximum speed = 25.0
```

The live engine now initializes the ship to **25.0**, replacing the temporary 12.0 cap used by the early engineering sandbox.

### Velocity Module — `velo`

PPC pickup branch `0x17908`:

```text
if maximum_speed < 50:
    maximum_speed += 5
```

The live rule is therefore **+5 maximum speed, capped at 50**.

### Ammunition Loader — `ammo`

PPC pickup branch `0x178E0`:

```text
if ammo_capacity < 10:
    ammo_capacity += 1
```

The value is not merely a HUD quantity: it limits the number of simultaneous player shots. A new game starts at **2**, and Ammunition Loaders increase that capacity to a maximum of **10**.

### Oscilloscope — `osci`

PPC pickup branch `0x178B8` restores shields to **100** when the current value is lower.

## Medium Asteroid payload

PPC destruction path around `0x195F4` shows that a destroyed `aste` creates one collectible payload.

A random low bit chooses which upgrade gets first priority:

```text
priority A: VELO -> AMMO -> barrel fallback
priority B: AMMO -> VELO -> barrel fallback
```

`VELO` is skipped once maximum speed reaches 50. `AMMO` is skipped once ammunition capacity reaches 10. If both are saturated, the game falls through to its barrel selector.

Milestone 0.5 implements this consequence in the live engine. During ordinary early play, every destroyed medium asteroid therefore produces either a Velocity Module or Ammunition Loader.

## Barrel selector

The selector at PPC `0x1A3D8` is now represented in recovered source. It chooses among:

- `equi`
- `bonu`
- `gadg`

according to wave number, two upgrade counters, and a 0..100 random value. The special Big-Rock callsite prevents a gadget result from surviving unchanged.

The individual `bonu` / `equi` / `gadg` upgrade effects are **not** invented in this milestone. Their sprites can be spawned and collected, but the remaining effect branches stay deferred until those PPC paths are fully lifted.

## Big Rock destruction

PPC `0x19718` establishes these consequences:

- a Big Rock requires 4 ordinary damage points;
- destruction creates **2..4 child fragments**;
- the normal fragment class is `ston`;
- fragment launch magnitude is selected in the recovered **4..12** range;
- on waves above 2, a hidden-enemy test can produce an enemy;
- the raw signed Random test is `>= 22000`;
- on waves 15+, an additional 0..100 draw `<= 40` selects a Raider; otherwise the hidden enemy is a Seeker.

Milestone 0.5 promotes the recovered object-count, class, speed-range, and hidden-enemy selection rules.

The exact child angle/offset case table is still being lifted. Its current portable angular spread is deliberately isolated in `fragment_big_rock()` and is **not yet claimed byte-for-byte exact**.

## Player death / respawn

Shield depletion now destroys the visible ship, produces the ship-specific 20-frame explosion bank (`Spri` 1500...), disables controls/firing during the death interval, and respawns with restored shields.

The original PPC death routine is at `0x1663C`. Its full state choreography is not yet completely lifted. Therefore:

- ship disappearance/explosion and shield restoration are recovered semantics;
- the current 120-tick delay and reset position are explicitly provisional compatibility values.

Keeping the provisional values centralized means they can be replaced without changing the platform/UI architecture.

## HUD

The native HUD now exposes current speed and maximum speed. This makes Velocity Module progression directly visible during testing.

## Regression coverage

The headless suite now verifies:

- all Milestone 0.4 collision tests;
- initial maximum speed = 25;
- Velocity Module +5 and 50 cap;
- Ammunition Loader +1 and 10 cap;
- Oscilloscope shield restoration;
- ammo as simultaneous projectile capacity;
- one VELO/AMMO payload from a destroyed early-game asteroid;
- Big Rock creation of 2..4 Stones;
- player shield depletion, destruction, and respawn skeleton.

## Still deferred

The next phase should concentrate on actual enemy/world behavior rather than more platform scaffolding:

- exact Big Rock child angle/offset case table;
- exact `bonu` / `equi` / `gadg` effects;
- full `0x1663C` death/respawn timing and placement;
- Mother Base state machine;
- Bee spawning/request logic;
- enemy projectiles;
- full special-case collision matrix;
- exact spawn positioning from `0x13D5C`;
- exact classic Mac Random() compatibility.
