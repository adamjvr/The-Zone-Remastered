# Milestone 0.7 — Hostile Combat, Fixed-Wave Lifecycle & Keyboard Remapping

Milestone 0.7 continues the existing Classic-fidelity roadmap. The only product-layer addition is macOS keyboard remapping in the pause menu; it does not change ZoneCore's semantic input contract or the native iPadOS/controller plan.

## Recovered hostile-fire behavior promoted into ZoneCore

The PPC enemy handlers use a signed 16-bit `Random()` result and strict inequalities before entering their shared `fire` creation tail:

| Enemy | FOURCC | Fire window |
|---|---|---|
| Bloody | `bloo` | `10000 < r < 13500` |
| Bee | `bee!` | `10000 < r < 15000` |
| Raider | `raid` | `10000 < r < 20000` |
| Seeker | `seek` | `10000 < r < 11000` |

For all four types the recovered object counter at `+72` limits the shooter to **3 active `fire` objects**. The `fire` constructor uses the shared projectile sprite bank at frame 4 and a vector magnitude of **11.25**.

The portable core now preserves those gates/caps and source accounting. A hostile shot that expires or hits releases its source counter. If its shooter is destroyed first, the shot remains alive but is detached from the recyclable world slot.

The exact classic Mac `Random()` state transition is still pending, so *which frame* a probabilistic enemy fires is not yet cycle-identical even though the recovered gate itself is exact.

## Hostile-shot collision

Hostile shots use the same original sprite-pixel collision oracle as the rest of Classic mode. The recovered `fire` consequence establishes a one-damage base path; Milestone 0.7 applies one shield point on player contact.

Still deliberately isolated for later lifting:

- exact hostile projectile lifetime;
- equipment/shield modifiers around hostile fire;
- any remaining type-specific `fire` collision branches;
- exact historical sound ID/event selection for each hostile shot.

## Bee and Seeker movement

### Bee

The live Bee now uses the recovered continuous pursuit pattern: accelerate toward the player, accept the candidate velocity when it is under the current max or reduces speed, otherwise clamp toward the target at the current maximum. Its recovered stun/return edge states remain pending.

### Seeker

The Seeker's recovered distance switch is live:

- squared distance `> 40000` (outside 200 logical units): cruise speed **10**;
- squared distance `<= 40000`: direct pursuit at the current runtime maximum speed.

This is the code path behind the manual's description of Seekers suddenly jumping toward the player.

## Fixed-wave lifecycle

The already-recovered tables for waves 1–18 are now connected to the running game for direct population counts: asteroids, Mother Bases, HQs, Raiders, Seekers, linked Rotors, defender subtype quotas and Bee limits.

The combat objective is the tracked base/enemy population. Asteroids and pickups do not block wave completion. After the objective reaches zero, an isolated **90-tick transition delay** currently advances to the next fixed wave and repopulates the world.

That delay is a presentation placeholder, not a claim about the original timing. Likewise, the Rotor parent link is populated but the full orbit/attack/return state machine and `mobile_moth_quota` behavior remain future lifts. Wave 19+ procedural generation is still explicitly pending.

## macOS pause-menu keyboard remapping

This is a modern native-product feature, not reverse-engineered game logic.

The pause overlay now provides a `Keyboard Controls` panel for every semantic Mac action:

- Rotate Left / Right
- Thrust
- Fire
- Equipment Up / Down
- Select / Use
- Pause
- Classic Save

Click a binding, press a replacement key, and the mapping changes immediately. If that physical key is already assigned, the two actions swap so no action silently becomes unreachable. Bindings persist in `UserDefaults` under a versioned key. `Reset Defaults` restores the Classic mapping.

Option/Command (and other paired modifier families) are handled as families so either physical side continues to work when assigned.

Pause remains the one-shot/debounced semantic pulse introduced by the 0.6.1 stability fix; remapping does not regress held-key pause behavior.

## Regression coverage

Milestone 0.7 adds checks for:

- all recovered hostile-fire windows;
- three-shot source cap;
- hostile shot survival after shooter destruction and player hit cleanup;
- hostile projectile speed 11.25;
- Seeker far/near speed switch;
- Wave 1 → Wave 2 fixed-population transition;
- the full existing 0.6.2 collision/progression/enemy/stability suite.

## Still next on the established roadmap

1. complete Mother Base/HQ movement state machines;
2. finish Bee/Seeker edge states and Rotor orbit/attack/return behavior;
3. complete hostile projectile lifetime/special consequences;
4. wave-transition presentation and procedural Wave 19+ generation;
5. remaining equipment, collision and destruction special cases.
