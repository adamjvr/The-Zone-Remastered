# Reverse-Engineering / Architecture Note — High Refresh Without Changing Classic Speed

## Architectural rule

Display refresh is not game time.

The original reconstruction reached Milestone 1.3 with one `zone_game_step()` per `MTKView` callback at 60 Hz. That was safe only while presentation was fixed at 60 Hz. Modern displays make that coupling incorrect: 120-Hz and 240-Hz callbacks must not multiply AI decisions, RNG tests, collision checks, projectile counters or wave timers.

## Why 720 Hz

720 is currently used as the **master scheduling grid** because it divides cleanly into several useful rates:

| Rate | Master ticks |
|---:|---:|
| 30 Hz | 24 |
| 40 Hz | 18 |
| 48 Hz | 15 |
| 60 Hz | 12 |
| 80 Hz | 9 |
| 90 Hz | 8 |
| 120 Hz | 6 |
| 144 Hz | 5 |
| 240 Hz | 3 |

The selection remains benchmark-driven for future high-rate dynamics. 720 Hz is not being asserted as a recovered property of the original game.

## Classic scheduler vs future dynamics scheduler

Milestone 1.4:

```text
monotonic wall time
        |
     720-Hz grid
        |
   every 12 ticks
        |
  zone_game_step()
        |
  60-Hz Classic state
        |
 presentation at screen rate
```

Future high-rate dynamics:

```text
720-Hz master grid
   |           |
continuous    recovered discrete
motion        AI/RNG/timers
   |           |
720 Hz        recovered cadence
   \           /
    current authoritative state
              |
       display presentation
```

The second model requires a deliberate ZoneCore decomposition. Calling the existing monolithic `zone_game_step()` hundreds of times per second would change gameplay and is explicitly prohibited.

## TickCount-derived behavior

Recovered Bee/Seeker state gates and other Classic routines refer to Classic Macintosh TickCount semantics. Their *duration* must remain stable even if the display is 120 or 240 Hz.

The master timebase gives those recovered durations a display-independent home. Future work should map each recovered timing domain explicitly rather than treating display callbacks as historical ticks.

## Presentation API direction

Milestone 1.4 keeps `MTKView` because it is already stable and sufficient to prove display/simulation decoupling. `preferredFramesPerSecond` is now presentation-only.

The later final Apple presenter can move to `CAMetalDisplayLink` for tighter variable-refresh timing and latency control without requiring another ZoneCore timing redesign.

## Interpolation policy

The rejected 1.1 timing experiments demonstrated why generic presentation extrapolation cannot substitute for correct engine timing:

- previous→current interpolation added visual latency;
- current-state extrapolation overshot state transitions, collisions and wraps.

Therefore high-refresh architecture does not depend on either technique. Interpolation may remain an optional presentation feature for special cases, but fresh high-rate simulation is the preferred Native-mode destination.

## Benchmark policy

A candidate dynamics rate is acceptable only if all of the following are true:

1. optimized headless ZoneCore shows large headroom on minimum supported hardware;
2. the relevant continuous subsystem has been converted to rate-correct units;
3. recovered Classic discrete cadence remains regression-tested;
4. deterministic behavior remains stable;
5. real macOS and iPadOS presentation tests show no new stalls or audio regressions.
