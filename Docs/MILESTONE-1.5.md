# Milestone 1.5 — Native High-Rate Dynamics Phase 1

Base commit: `e0c94d0ac9a50b3006302a47711be2eda7019531` (accepted Milestone 1.4).

Milestone 1.5 promotes **real continuous motion** onto the 720-Hz master timebase introduced by 1.4. It does not use interpolation or extrapolation and it does not multiply the recovered Classic behavior clock.

## Runtime split

The accepted Classic API remains unchanged:

```text
zone_game_step()
    = one complete authoritative Classic interval
    = existing deterministic regression contract
```

The native high-refresh host gains:

```text
zone_game_advance_master_ticks()
    720-Hz master grid

phase 0
    Classic input/turn/thrust decision
    AI state decisions
    RNG/fire gates
    object ticks/animation decisions

phases 0..11
    real player position integration
    real world-object position integration
    real projectile position integration

phase 11
    projectile lifetime
    exact-pixel collision
    pickup collision
    player/body collision
    world/world collision
    wave lifecycle
    explosion aging
```

Twelve master ticks therefore remain exactly one 60-Hz Classic interval while 120/144/165/240-Hz displays can observe genuine intermediate ZoneCore positions.

## Why collision remains 60 Hz in Phase 1

The objective of this milestone is to remove the final 60-Hz **motion** quantization without silently changing Classic gameplay. Collision sampling itself is observable game behavior. Running exact-pixel collision 12 times as frequently could turn historical misses into hits, change impact timing, and alter projectile consequences.

Milestone 1.5 therefore keeps collision at the recovered Classic boundary after all twelve motion substeps. A future explicit Remastered collision policy may promote collision frequency separately after deterministic comparison.

## Classic API is not removed

`zone_game_step()` is deliberately retained and unchanged. This is important for:

- old regression tests;
- reverse-engineering comparisons;
- deterministic Classic traces;
- A/B testing against native high-rate motion;
- future Classic/Remastered policy separation.

The live native host uses the new path by default; `ZONE_HIGH_RATE_DYNAMICS=0` selects the accepted 1.4 Classic-step path for A/B comparison.

## A/B launch modes

`Tools/run-macos-refresh.command` now accepts a dynamics policy:

```text
./Tools/run-macos-refresh.command 60 classic
./Tools/run-macos-refresh.command 60 high
./Tools/run-macos-refresh.command 240 high
./Tools/run-macos-refresh.command native high
```

`auto` is the default: presentation above 60 Hz (or `native`) enables high-rate motion; a forced 60-Hz presentation keeps the accepted 1.4 Classic path.

## Regression evidence

New ZoneCore tests verify:

- 3 master ticks advance exactly one quarter of a Classic displacement;
- 12 master ticks complete exactly one Classic interval;
- one Classic step and twelve master ticks land on matching player/projectile boundary state;
- a 180-interval changing turn/thrust/fire script retains matching Classic-boundary player state, behavior tick count, projectile count, HUD counters and velocities.

The existing full regression suite remains active because `zone_game_step()` is untouched.

## Performance

Milestone 1.4 measured roughly 64x headroom even against a hypothetical 1440 full-Classic-step rate on the test Mac. 1.5 adds a more relevant benchmark that measures the actual 12-substep native dynamics path separately from the monolithic Classic path.

## Explicit non-changes

- no interpolation;
- no extrapolation;
- no 30-Hz global clock;
- no AI/RNG/fire cadence increase;
- no timer rescaling;
- no high-rate collision yet;
- no change to the accepted AVAudioEngine backend;
- no change to sprite preload/render hot paths;
- no change to recovered Bee/Seeker/Mother/Rotor state semantics;
- no change to the Raider 3-shot cap correction committed in 1.4.

## Next

After native 120/240-Hz play testing confirms that the real-motion path feels correct, the roadmap returns to Classic reconstruction: Mother/HQ collision/state semantics and shared-object-pool parity. High-rate collision remains a distinct Remaster-policy experiment rather than being smuggled into Classic fidelity work.
