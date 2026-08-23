# Milestone 1.4 — Display-Independent Timebase & Native-Refresh Presentation

Base commit: `92f4e19` — Milestone 1.3 Bee/Seeker state completion.

Milestone 1.4 removes the architectural assumption that one Metal draw callback equals one game step. It is deliberately a **foundation milestone**: Classic gameplay remains authoritative at 60 Hz while presentation may run at the active display's native maximum. No interpolation or extrapolation is introduced.

## Why this is necessary

Before 1.4, `ZoneRenderer.draw(in:)` called `host.step()` exactly once. Raising `MTKView.preferredFramesPerSecond` from 60 to 120 or 240 would therefore have doubled or quadrupled the entire game speed.

That coupled rendering, input sampling, AI, RNG, collision, projectile lifetime, wave timers and audio event production to monitor refresh. It also made variable-refresh displays impossible to support correctly.

## 720-Hz master scheduling grid

`ZoneGameHost.swift` now contains a monotonic integer scheduling grid:

- master rate: **720 Hz**;
- Classic authoritative rate: **60 Hz**;
- divisor: **12 master ticks per Classic step**.

At this milestone, the 720-Hz grid is a scheduler, not yet a 720-Hz physics loop. This distinction is intentional. It lets presentation and wall-clock time become independent now while preserving every recovered 1.3 gameplay cadence.

Examples:

- 60-Hz display: normally 12 master ticks elapse and one Classic step executes per presentation;
- 120-Hz display: normally 6 master ticks per presentation, therefore one Classic step every second presentation;
- 240-Hz display: normally 3 master ticks per presentation, therefore one Classic step every fourth presentation;
- 144/165-Hz and VRR rates use elapsed monotonic time rather than display-frame counting.

The test harness proves that simulated one-second runs at 60/120/144/165/240-Hz presentation all execute the same number of Classic steps.

## Native-refresh presentation

`ZoneMTKView` now requests the active screen's `maximumFramesPerSecond` when the view is attached to a screen.

- macOS follows the active `NSScreen` and updates the request when the window changes screens;
- iPadOS follows the `UIScreen` attached to the window;
- `ZONE_PRESENTATION_HZ=<n>` provides a diagnostic override and is clamped to the screen maximum;
- default behavior is the display's native maximum.

This enables a 240-Hz Mac display or 120-Hz iPad Pro to receive presentation callbacks above 60 Hz without changing game speed.

## No manufactured motion

Milestone 1.4 does **not** interpolate or extrapolate object positions. High-refresh displays may therefore present the same authoritative 60-Hz world state more than once between Classic updates.

That is temporary and explicit. The next dynamics phase can move continuous motion/integration onto the 720-Hz master grid after benchmarking and regression work, while discrete Classic semantics remain on their recovered cadence.

## Stall handling

The scheduler uses monotonic uptime and deliberately refuses to simulate unbounded backlog after sleep, backgrounding, debugger stops or severe scheduling stalls:

- presentation gaps above 250 ms rebase the timebase;
- at most eight Classic steps may be executed for one presentation callback;
- diagnostics report rebases, multi-step catch-up and clamping.

This prevents a paused/suspended application from returning with seconds of queued gameplay to simulate.

## Headless ZoneCore benchmark

`Tools/benchmark-zonecore.command` builds an optimized, headless ZoneCore benchmark and reports measured throughput and headroom against candidate rates:

- 240 Hz
- 480 Hz
- 720 Hz
- 960 Hz
- 1440 Hz

The benchmark periodically reloads fixed Wave 18 and uses scripted thrust/turn/fire input so a long run does not quietly become an empty-world benchmark.

A high throughput result is **not** permission to globally call `zone_game_step()` at that rate. The next promotion must split continuous dynamics from Classic discrete state/RNG/timer semantics first.

## Diagnostic commands

```bash
./Tools/test-zone-timebase.command
./Tools/benchmark-zonecore.command
./Tools/run-macos-refresh.command native
./Tools/run-macos-refresh.command 60
./Tools/run-macos-refresh.command 120
./Tools/run-macos-refresh.command 240
```

`run-macos-refresh.command` reuses the existing 1.2 performance diagnostics so frame gaps, host stalls and requested presentation FPS remain visible.

## Explicit non-changes

Milestone 1.4 does not alter:

- `ZoneCore` C source or headers;
- Bee/Seeker 1.3 state semantics;
- AI/RNG call cadence;
- player physics constants;
- collision rules;
- projectile lifetime constants;
- damage thresholds;
- wave progression;
- audio sample mapping or voice banks;
- sprite selection or rendering geometry.

## Next high-refresh step

After real hardware benchmark results are captured, continuous motion can be decomposed from legacy frame-quantized behavior and promoted onto the master timebase. That phase should produce genuinely fresh simulated positions for 120/240-Hz displays rather than relying on render interpolation.
