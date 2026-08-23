# Milestone 1.3 — Bee & Seeker State Completion

Base commit: `f7894f0b8a28a2016fe6f593585fd4ecd335ad42` (Milestone 1.2).

Milestone 1.3 returns to Classic gameplay reconstruction after the accepted 1.1 real-time repair and 1.2 stall-attribution checkpoint. It deliberately leaves the renderer, audio engine, host-step cadence, and 1.2 diagnostics unchanged.

## Bee: recovered timed hit-state gate

The Bee handler at PPC `0x154A8` begins by checking object halfword `+66`. When the value is `1`, it compares current Classic Mac `TickCount` against the timestamp stored at `+92`.

- elapsed `< 60`: the handler returns before normal steering, facing, and firing;
- elapsed `>= 60`: `+66` is cleared and normal chase resumes;
- while gated, the original calls its continuous-vector conversion helper and therefore retains/coasts on its existing motion rather than choosing a new target vector.

ZoneCore already stores a single portable continuous velocity and integrates it after the behavior handler, so the portable observable equivalent is to retain velocity and skip Bee steering/facing/fire until the gate expires.

### Correction to the earlier roadmap

The Bee handler does **not** read its donor/parent link and does not contain a return-to-parent state. The link created by PPC `0x16504` is bookkeeping for donor/request counters. Earlier roadmap wording that described "Bee stun/return" was too strong and is corrected by this milestone.

## Seeker: recovered timed gate and collision backdate

The Seeker handler at PPC `0x15944` uses the same `+66 == 1` / `+92` 60-TickCount gate. During that interval it keeps its existing motion and returns before retargeting, facing, or its firing Random call.

The player/body collision branch at PPC `0x1A0B4..0x1A0C8` has an additional recovered consequence specifically for `seek`:

1. store `TickCount - 30` in `+92`;
2. set `+66 = 1`.

Because the behavior handler clears at elapsed 60, a player collision leaves approximately half the full gate remaining: 30 TickCount units.

The existing Seeker direct pursuit remains intact:

- distance squared `<= 40000` (radius 200): runtime player maximum speed;
- outside radius 200: recovered cruise speed 10.

## Bee request in real fixed-wave gameplay

Milestone 0.6 correctly recovered that a Mother/HQ cannot donate a Bee to itself. Professional Wave 1 contains only one Mother, so a Bee is impossible there even though its `bee_limit` is one.

Professional Wave 2 contains two Mothers and `bee_limit = 1`. A new deterministic regression now applies a nonlethal player shot to the first Wave-2 Mother and verifies that exactly one Bee is requested from the other Mother, using the normal fixed-wave construction rather than a synthetic donor.

## RNG ordering

Both recovered Bee and Seeker handlers return before their firing `Random()` call while the timed gate is active. The portable core therefore suppresses the fire test itself while gated rather than consuming RNG and merely refusing to create a projectile. This keeps call ordering closer to the original program and matters for the later Classic-RNG parity milestone.

## Timebase note

The original duration is expressed in Classic Mac `TickCount` units. Milestone 1.3 currently maps that to the existing 60-Hz-compatible `behavior_tick`, because 1.3 intentionally does not restructure timing.

Milestone 1.4 will introduce a display-independent engine timebase/high-refresh architecture. At that point this recovered 60-TickCount duration must be represented as a Classic-duration event and **must not** become 2× faster on a 120-Hz display or 4× faster on a 240-Hz display.

## Explicit non-changes

- no renderer interpolation or extrapolation;
- no global 30-Hz experiment;
- no display-refresh changes;
- no change to the accepted 1.1 renderer/audio hot paths;
- no change to 1.2 host stall diagnostics;
- no guessed Bee return-to-parent state;
- no partial promotion of the related Raider `+66` behavior;
- no guessed meaning for the Bee/Seeker `+128` spatial-mode branch.

## Regression coverage

Milestone 1.3 adds deterministic checks for:

- Bee hit-state duration = 60;
- Seeker hit-state duration = 60;
- Raider is intentionally not promoted by the new helper;
- Seeker player-collision timestamp backdate = 30;
- Seeker boundary behavior at distance squared 40000/40001;
- Wave-2 nonlethal Mother hit spawning a Bee from the other Mother;
- Bee retaining velocity/facing for 59 ticks and resuming chase at elapsed 60;
- Seeker player collision retaining its state for 29 additional ticks and resuming at the 30th.

## Remaining Bee/Seeker parity work

The original handlers contain a `+128` spatial/active-mode branch that changes target-coordinate/firing-tail behavior. ZoneCore does not yet carry an equivalent recovered spatial-mode model, so that branch remains explicitly unresolved rather than guessed. The broader collision matrix also contains enemy-vs-enemy special cases that will be promoted with collision/allocator parity work.
