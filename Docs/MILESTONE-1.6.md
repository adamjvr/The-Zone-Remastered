# Milestone 1.6 — Shared 80-Slot Capacity & Base Impact Parity

Milestone 1.6 returns to Classic-fidelity reconstruction on top of the accepted Milestone 1.5 high-rate dynamics architecture.

## Scope

This milestone promotes two directly recovered behaviors:

1. the original global 80-object capacity;
2. missing Mother Base / Headquarters ship-impact state consequences from PPC `0x174E8`.

It does **not** change the 720-Hz master rate, 60-Hz Classic decision/collision cadence, presentation rate, audio backend, projectile lifetime, wave timing, or RNG implementation.

## Recovered 80-object pool

PPC startup `0x19E0..0x1A34` allocates:

- one 320-byte pointer array (`80 * 4` on PPC32);
- exactly 80 separate zeroed object records;
- each object record is exactly 150 bytes.

The shipping program therefore has one shared capacity for the ship and gameplay objects rather than independent capacities for world bodies, projectiles and explosions.

ZoneCore still keeps typed arrays internally because replacing every storage/reference path at once would unnecessarily destabilize renderer, collision-link and save work. Milestone 1.6 instead promotes the observable allocator rule first:

```text
ship + world objects + projectiles/fire + explosions <= 80
```

Every object-producing path now checks that shared admission budget before consuming a typed slot.

This is intentionally **allocator parity phase 1**. The following remain separate work:

- one literal 80-record storage array;
- original linked-list head/tail and traversal ordering;
- exact slot-reuse ordering;
- object categories not yet implemented in ZoneCore;
- the `+128` alternate collision/list-search behavior.

## Mother Base / HQ ship collision — PPC 0x174E8

The normal (`+128 == 0`) base collision path directly checks the base against the ship and, on overlap:

- writes base byte `+133 = 1`;
- writes ship byte `+133 = 4`;
- requests sound effect index 5;
- computes recovered base-impact shield damage;
- caps that damage at 30;
- sets base byte `+130 = 1`;
- clears base/Mother motion selector `+86 = 0`;
- exchanges the ship/base continuous velocity vectors.

ZoneCore already had the recovered damage formula and velocity exchange. Milestone 1.6 adds the missing state consequences:

- `player_contact` remains the portable `+130` contact latch;
- Mother motion state is reset to 0 on impact;
- base and player receive one-draw impact feedback;
- the existing collision audio event remains the presentation-layer surrogate for the recovered sound request.

The exact Classic palette operations represented by `+133 = 1` and `+133 = 4` are still unresolved. The Metal renderer therefore continues to use its short white-flash surrogate rather than claiming palette-perfect reconstruction.

## High-rate path parity

Milestone 1.5 introduced the additive 720-Hz master path while preserving `zone_game_step()` as the Classic reference. Milestone 1.6 applies the same base-collision consequences to both paths and regression-tests them together.

Collision itself remains on the Classic boundary. This milestone does not promote 720-Hz collision sampling.

## Regression coverage

New tests verify:

- reported Classic object capacity is exactly 80;
- fresh Professional Wave 1 consumes five Classic object slots: ship + 3 asteroids + 1 Mother;
- after filling 64 world slots plus 15 hostile projectile slots, total occupancy is exactly 80;
- a further world-object allocation is rejected even though the typed world API is asked directly;
- a further projectile allocation is rejected even though projectile storage still has theoretical room;
- Mother ship collision resets motion selector state 2 -> 0;
- Mother and ship one-draw impact feedback are emitted;
- those collision consequences agree between one Classic step and twelve master ticks.

## Next

Milestone 1.7 moves to projectile/death/wave timing fidelity: recovered projectile lifetime, special projectile collisions, player death/respawn timing/placement, and wave-clear timing on the display-independent timebase.
