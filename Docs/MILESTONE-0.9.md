# Milestone 0.9 — Mother Base Motion & Headquarters Fire

Base checkpoint: `b7e4bdc` — **Milestone 0.8: restore base damage feedback and headquarters defense**

Milestone 0.9 continues the existing Classic-fidelity roadmap. It does not replace or reapply 0.8; it is a small overlay on top of the committed 0.8 tree.

## Recovered behavior promoted

### Fixed-wave mobile Mother flag (`+84`)

The fixed-wave constructor at PPC `0x13B94..0x13BB0` marks the first `mobile_moth_quota` Mother Bases with object halfword `+84 = 1`.

The existing wave tables already contained that quota. ZoneCore now preserves it on the actual Mother objects instead of discarding it after population.

`+84` is treated as an eligibility flag, not as an invented movement mode. The Mother remains in selector state `+86 = 0` until the recovered destruction path activates it.

### Player-shot destruction activates a mobile Mother

PPC `0x19C38..0x19C98` runs after a player-shot destruction. It walks the object list, finds the first live `moth` whose `+84` is nonzero, calls the game's range helper with `(1,3)`, and stores the result into `+86`.

The range helper at PPC `0x4E24` computes:

`lower + ((uint16(Random()) * (upper - lower)) >> 16)`

That makes the upper bound exclusive. For `(1,3)`, the only reachable results are **1 and 2**. The original code contains a defensive `if (+86 == 3) +86 = 2`, but that branch is unreachable for this callsite under the recovered helper.

ZoneCore promotes this event-driven transition after player-shot kills. The portable world-slot order is currently the deterministic traversal order; exact original linked-list ordering remains a parity item.

### Mother Base motion selector (`+86`) — PPC `0x14C70`

Three selector states are now live:

- **State 0:** no AI velocity rewrite; transferred/existing motion is preserved.
- **State 1:** accelerative chase. One unit of target-direction vector is tentatively added. The change is accepted if the new speed is at/below the runtime maximum or if it reduces an already-over-cap speed; otherwise velocity is clamped toward the target at the runtime maximum.
- **State 2:** direct pursuit. At squared distance `<= 40000` (radius **200**) it uses the runtime maximum speed; outside that radius it uses recovered cruise speed **10**.

The original nonzero states route through PPC `0xE6F4` to convert the continuous vector into scaled integer motion. ZoneCore keeps the same continuous-vector abstraction already used by the live Bee/Seeker lifts and applies the recovered X/Y motion scales at world integration.

Mother Base sprite-frame cycling remains disabled. Motion-state promotion therefore does not reintroduce the 0.6-era visual wobble.

### Headquarters/base fire handler — PPC `0x14B18`

`base` objects do not use the Mother Base `0x14C70` handler.

The recovered Headquarters/base handler:

- checks the shared behavior tick;
- enters the fire branch when `tick % 15 == 0`;
- aims at the player;
- constructs a `fire` object using the recovered hostile projectile vector magnitude **11.25**;
- does **not** use the separate `+72 < 3` per-shooter cap from the Bloody/Bee/Raider/Seeker fire tail.

ZoneCore now gives Headquarters this independent **15-tick** fire cadence. It still obeys the remaster's finite projectile pool.

## Regression coverage

Milestone 0.9 adds deterministic tests for:

- `RandomRange(1,3)` selector endpoints: low half -> state 1, high half -> state 2;
- the exact 200-unit state-2 speed boundary;
- Professional Wave 10's first `mobile_moth_quota = 1` object-state assignment;
- player-shot destruction activating the flagged Mother into state 1 or 2;
- live Mother state 0 velocity preservation;
- live Mother state 1 accelerative chase;
- live Mother state 2 far cruise speed 10;
- live Mother state 2 near runtime-max speed;
- Mother frame stability while movement state is active;
- Headquarters producing no shot through tick 14, then one at tick 15 and another at tick 30.

All existing 0.8 regressions remain in `test_zone_core.c`, including the Professional 40-hit Mother Base destruction chain, nonlethal hit feedback, Headquarters defender replenishment, and stable Mother/HQ sprite frames.

## Known fidelity boundaries

Milestone 0.9 intentionally does **not** guess:

- the exact classic Mac `Random()` sequence; only the recovered range transform is promoted;
- exact PPC linked-list traversal ordering versus ZoneCore's stable world-slot traversal;
- the original shared 80-object allocation pool versus ZoneCore's split world/projectile/explosion pools;
- remaining Mother/HQ collision-state edge transitions not yet isolated;
- exact legacy palette operation for damage flag `+133`;
- exact classic sound-resource mapping for the already-promoted hit event.

These remain explicit reverse-engineering items for later milestones.
