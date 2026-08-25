# Milestone 1.7 — Death, Explosion & Wave Timing Fidelity

Milestone 1.7 replaces three frame-count approximations with lifecycle relationships recovered directly from TheZone 1.5.1 PPC code. It is built on the accepted Milestone 1.6 object-capacity/base-impact tree and does not change the 720-Hz continuous-motion architecture, display scheduling, audio backend, AI/RNG cadence, or collision sampling frequency.

## Recovered behavior promoted

### Explosion action cadence

The EXPL action at PPC `0x12080` dispatches on `previous_type` (object +4). It increments `animation_counter` (+60) for explosions whose previous type is `ship`, `moth`, or `base`, and advances their sprite frame only on odd counter values. Those classes therefore advance one animation frame every two Classic action passes. Other recovered explosion origins take the direct frame-advance path every action pass.

ZoneCore now retains `previous_type` in its typed explosion surrogate and reproduces that cadence. A transformed explosion begins at frame 0 and does not execute the new EXPL action in the same dispatch that created it.

The common 11-frame destruction banks therefore complete after 11 action advances for ordinary bodies, while Mother/HQ explosions use the recovered alternating cadence. The ship uses the recovered 20-frame bank with the same alternating cadence.

### Player death / respawn

The old portable `ZONE_RESPAWN_TICKS = 120` countdown was not recovered behavior. PPC `0x12370` finalizes a ship-origin explosion and sets the player-reset flag; the main gameplay loop observes that flag and calls `0x1663C`. Respawn is therefore causally tied to ship-explosion completion.

ZoneCore now marks respawn pending at death, runs the ship's recovered 20-frame EXPL cadence, and rebuilds the player only when that explosion completes. `0x1663C` constructs the ship at half the playfield dimensions minus the 16-pixel top-left sprite offset; because ZoneCore stores object centers, the recovered portable center is `(320, 240)` on the 640x480 logical zone.

The same relationship is regression-tested through both `zone_game_step()` and `zone_game_advance_master_ticks()` so display refresh cannot change death duration.

### Wave completion

The old 90-tick wave-clear countdown was provisional. PPC object finalization `0x124B0` decrements the shared Mother/HQ objective counter for a removed `moth` or `base`. Only when that counter becomes zero does it set global wave-complete flag `11978`. The main loop checks that flag and immediately calls `0x10648`, which increments the wave and reconstructs the next zone.

This also means a Mother/HQ's lethal hit does **not** decrement the objective immediately: the object first becomes `expl`, and the objective count is decremented only when that transformed explosion reaches its final frame and is removed. Surviving defenders do not gate the next wave.

ZoneCore now preserves that ordering. The fixed Wave 1 -> Wave 2 regression keeps a linked defender alive, destroys the Mother, verifies the objective remains live through the Mother explosion, then verifies Wave 2 begins when the Mother-origin EXPL is finalized.

## Projectile lifetime finding — intentionally not promoted yet

The audit disproved the current `life = 90` / `life = 120` values as recovered constants. `shot` action `0x11D44` and `fire` action `0x11D6C` contain no lifetime decrement. A separate spatial/list-maintenance path around `0xF080` clears active/spatial state; `fire` is removed there, while `shot` follows a distinct list-unlink path.

ZoneCore's current 640x480 wrapped-world abstraction does not yet model the original spatial/list system closely enough to replace those temporary retirement guards without creating immortal wrapped projectiles or otherwise inventing semantics. Milestone 1.7 therefore labels those counters explicitly temporary and leaves their behavior unchanged. Their removal is coupled to the later `+128` spatial/list parity lift.

## Regression coverage

- ship explosion drives respawn instead of a 120-tick timer;
- recovered 20-frame/every-other-action ship cadence;
- identical respawn behavior on Classic and 720-Hz master paths;
- respawn center `(320,240)`;
- ordinary EXPL advances every action pass;
- Mother/HQ objective count remains until EXPL finalization;
- Wave 1 -> Wave 2 starts at last Mother/HQ finalization even with defenders alive;
- no change to projectile retirement behavior in this milestone;
- all prior gameplay/high-refresh/object-capacity regressions remain required.
