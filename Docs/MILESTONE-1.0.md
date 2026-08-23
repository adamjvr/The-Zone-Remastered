# Milestone 1.0 — Rotor Orbit, Attack & Return AI

**Base checkpoint:** Milestone 0.9, commit `25284767db9ab3f4e60b07d011e593da169bdaf7`.

Milestone 1.0 promotes the recovered Rotor guard behavior without changing the
working 0.9 Mother Base / Headquarters systems.

## Recovered Rotor state machine

The object-behavior switch at PPC `0x14914` dispatches `roto` to
`0x15BC8..0x16124`. Rotor byte `+131` is the state selector:

| State | Meaning | Live behavior |
|---:|---|---|
| 0 | Orbit | 40-unit parent orbit; heading +4°/tick; tangent 24-frame facing |
| 1 | Attack | pursue player at speed 10; return after 160-unit parent leash |
| 2 | Return | pursue parent at speed 20; re-enter orbit at radius 40 |

An orbiting Rotor also wakes directly into attack when the player enters a
100-unit radius (`distance² <= 10000`).

The implementation keeps ZoneCore's existing screen-space motion convention.
Orbit state is special in the native routine because it writes the direct
correction to integer motion fields before common integration; ZoneCore
compensates its X/Y integration scales only for that state so the resulting
visible displacement matches the recovered orbit target. Attack and return use
the existing continuous-vector path.

## Parent links and collision wake behavior

Fixed-wave Rotor construction now retains both recovered directions:

```text
Rotor +142 (link1)  -> parent Mother Base / HQ
parent +146 (link2) -> Rotor
```

The collision dispatcher contributes two wake events that are now live:

- a valid player-shot hit on `roto` writes Rotor `+131 = 1` before checking
  whether the hit destroys it;
- a nonlethal player-shot hit on a Mother Base wakes its linked Rotor by writing
  that Rotor `+131 = 1`.

Rotor destruction clears the parent's Rotor link. It deliberately does **not**
decrement the parent's `+72` launched-defender count: Rotor is the separate
link2 guard, not one of the Mother's/HQ's launched defenders.

## Rotor hostile fire

The Rotor reaches the shared hostile-projectile tail with:

- strict signed-Random gate `10000 < (int16)Random() < 15000`;
- active hostile-shot cap `object+72 < 3`;
- the already-recovered `fire` projectile speed of 11.25.

This extends the 0.7 firing model without altering Bloody/Bee/Raider/Seeker
semantics.

## Verification

Milestone tests cover:

- recovered Rotor constants and strict firing boundaries;
- fixed-wave bidirectional Rotor links;
- Mother-hit and Rotor-hit wake behavior;
- orbit → attack → return → orbit transitions;
- 40 / 100 / 160 distance boundaries and 10 / 20 speed states;
- Rotor destruction link cleanup without defender-count corruption.

The delivery was also compiled with `-std=c11 -Wall -Wextra -Werror` for every
changed C translation unit, and a focused runtime harness executed the live
Rotor transition/link paths against the modified `zone_core.c`.

The repository verifier remains authoritative after application because it runs
the full current `Tools/test-zonecore.sh` against the user's complete checkout.

## Still pending

Milestone 1.0 intentionally does not claim complete Classic parity. Remaining
high-value work includes Bee stun/return edges, remaining Seeker edge states,
the original shared 80-object allocator and list ordering, exact Classic Mac
RNG sequencing, special projectile/collision consequences, procedural waves
after 18, and remaining equipment/destruction effects.
