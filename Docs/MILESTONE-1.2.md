# Milestone 1.2 — Host Stall Attribution

Base: Milestone 1.1 (`e3bdbbcf5d04672da2de4ce738669394bdb5b66c`).

Milestone 1.2 is an **instrumentation-only diagnostic phase** on the accepted 1.1 gameplay build. It does not change ZoneCore behavior, presentation cadence, enemy AI, physics, collision, wave timing, projectile timing, sprite selection, or the 16-voice audio policy.

## Why this phase exists

The accepted Milestone 1.1 play test was materially smoother, successfully completed Zone 1, preloaded all 651 sprite textures, and showed no texture-cache misses or audio voice exhaustion. That isolates the remaining intermittent hitch to work occurring inside the host step.

The previous profiler timed `host.step()` as one opaque region. That region contains several unrelated subsystems:

1. controller/keyboard input sampling;
2. `zone_game_step()`;
3. ZoneCore audio-event draining;
4. one or more `ZoneAudioEngine.play()` calls;
5. periodic HUD snapshot publication.

A recurring roughly 70–76 ms stall signature cannot safely be assigned to any one of those without measuring them independently.

## What 1.2 adds

When `ZONE_PERF_DIAGNOSTICS=1` only, every host step slower than 4 ms emits one structured `host-detail` record containing:

- total host-step duration;
- input-sampling duration;
- ZoneCore-step duration;
- audio-event drain duration;
- cumulative audio-trigger duration;
- maximum single audio-trigger duration and event type;
- HUD-publication duration and whether this frame published a HUD snapshot;
- the dominant measured stage;
- wave, base count, enemy count, world-object count, player projectile count, hostile projectile count, and behavior tick.

The audio engine also measures the two operations inside a trigger independently:

- resetting `AVAudioPlayer.currentTime`;
- `AVAudioPlayer.play()` itself.

A trigger exceeding 2 ms emits `slow-trigger` with sound resource, event type, voice index, reset time, play time, and whether AVFoundation reported a successful start.

## Normal gameplay contract

Diagnostics remain opt-in. When `ZONE_PERF_DIAGNOSTICS` is absent, `ZoneGameHost.step()` immediately takes a dedicated fast path copied from Milestone 1.1. The accepted 60-Hz presentation-driven host contract is unchanged.

Milestone 1.2 ships no ZoneCore file and no renderer file. The verifier explicitly fails if either differs from the committed 1.1 base.

## Perf workflow

Build normally:

```bash
./Tools/build-macos.command
```

Then launch the diagnostic build:

```bash
./Tools/run-macos-perf.command
```

Play until the hitch occurs or complete another zone, then quit normally. The runner now automatically invokes `Tools/summarize-macos-perf.command` and prints a compact attribution report.

You can summarize an existing log again with:

```bash
./Tools/summarize-macos-perf.command build/perf-logs/zone-perf-YYYYMMDD-HHMMSS.log
```

## Decision gate after the next run

- **audio dominates** and `slow-trigger` agrees: repair/replace the AVAudioPlayer start path without touching ZoneCore cadence;
- **core dominates**: instrument `zone_game_step()` internally by subsystem next, keeping behavior identical;
- **input dominates**: inspect controller sampling/GameController access;
- **HUD dominates**: move or coalesce publication work without changing the simulation;
- **no host stage dominates but frame gaps remain**: focus on presentation/window scheduling rather than game-state logic.

No speculative timing changes are authorized by this milestone.
