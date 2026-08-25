# Reverse-engineering notes — lifecycle timing

## EXPL action: PPC 0x12080

The EXPL handler reads object `previous_type` at +4. `ship`, `moth`, and `base` increment +60 and use its low bit to decide whether to advance +56 (`sprite_frame`). Other previous types enter the direct advance branch. Frame finalization occurs when +56 reaches +58 (`sprite_frame_count`), at which point the handler calls `0x12370`.

Recovered implications used by Milestone 1.7:

- `ship` -> 20-frame explosion bank, every-other-action frame advance;
- `moth` / `base` -> destruction bank, every-other-action frame advance;
- ordinary recovered destruction origins -> frame advances each action pass;
- transformed EXPL object retains its source type in +4.

## EXPL finalization: PPC 0x12370 / object removal 0x124B0

`0x12370` uses `previous_type` to dispatch final consequences before calling the common object-removal path. For a ship-origin explosion it updates the player/life state and sets the reset flag consumed by the main loop. For Mother/HQ origins, common removal eventually reaches the branch that decrements the shared wave-objective counter.

## Player reset: PPC 0x1663C

`0x1663C` reconstructs the `ship` object. The spawn coordinates are derived from half of the playfield extents minus 16 in top-left object coordinates. The modern engine stores centers, so the portable center is 320x240.

The important timing conclusion is structural: the main loop calls this reset after the ship explosion's finalization flag is set. No independent 120-frame death countdown was found.

## Wave completion: PPC 0x124B0 -> global 11978 -> 0x10648

The removal dispatcher compares `previous_type`. Both `base` and `moth` reach the branch at `0x126F4`, which decrements the TOC global at +11282. If it becomes zero, global +11978 is set to one. Later in the main gameplay loop (around `0xF2B8`) a nonzero +11978 directly invokes `0x10648`. That routine increments the wave global at +11976 and calls the zone/wave setup routines.

Therefore:

1. base/Mother damage threshold reached;
2. object transforms into EXPL;
3. EXPL animation runs according to `0x12080`;
4. final EXPL frame calls `0x12370`/`0x124B0`;
5. Mother/HQ objective count decrements;
6. if it reaches zero, +11978 is set;
7. main loop immediately invokes `0x10648` and advances the wave.

The recovered gate is the Mother/HQ objective counter, not the aggregate defender/enemy population.

## SHOT/FIRE retirement: unresolved spatial dependency

The action handlers for `shot` (`0x11D44`) and `fire` (`0x11D6C`) do not contain a lifetime counter. The spatial-maintenance pass around `0xF080` clears +128 and then treats the projectile types differently: `fire` reaches common removal while `shot` is unlinked through `0xDFBC` and follows additional spatial handling.

Because the current portable engine intentionally collapses the original screen/world/spatial-list representation into a wrapped 640x480 world, a faithful projectile-retirement lift requires the pending +128/list work. The old 90/120 counters are documented as temporary compatibility guards, not recovered values.
