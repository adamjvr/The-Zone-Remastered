# Milestone 1.1 — Real-Time Hot-Path Repair

Base: Milestone 1.0 (`6df5e5da9985eaa379a385c5e49af49c8f9e912c`).

This milestone deliberately does **not** change ZoneCore timing, AI, physics, collision, projectile lifetime, wave timing, player controls, or any recovered gameplay constant.

## Why this milestone exists

The first timing experiment was rejected in play testing. It globally changed the simulation cadence and then attempted to hide the resulting coarse updates with interpolation/extrapolation. That mixed too many variables and made game feel worse.

The 1.0 baseline still has two independent real-time implementation problems that can cause stutter or chopped sound without requiring any gameplay-timing theory:

1. `ZoneRenderer.texture(_:)` performed bundle lookup, PNG decoding and Metal texture creation on first use from inside `draw(in:)`.
2. `ZoneAudioEngine.play(_:)` constructed and prepared a new `AVAudioPlayer` for every trigger and retained only one player per sound resource, so a repeated same-sample event could destroy the previous player while it was still sounding.

Milestone 1.1 fixes only those hot paths.

## Changes

### Renderer

- keeps `preferredFramesPerSecond = 60`;
- keeps exactly one `host.step()` per Metal draw callback;
- preloads the recovered `Sprites/*.png` resources into Metal textures before presentation starts;
- makes `texture(_:)` a cache-only lookup with no file I/O, PNG decode or texture allocation;
- removes the per-quad six-element Swift Array allocation and uses temporary stack storage for vertex data;
- does **not** interpolate or extrapolate any object position;
- adds opt-in frame-gap / slow-host-step / slow-CPU-frame diagnostics through `ZONE_PERF_DIAGNOSTICS=1`.

### Audio

- preloads only the currently mapped sound resources once;
- prepares 16 independent `AVAudioPlayer` voices per mapped sound resource;
- repeated triggers use a free prepared voice instead of replacing the sole strong reference to the previous player;
- if all 16 voices for one sample are genuinely busy, the oldest rotating slot is reused and an opt-in diagnostic is emitted;
- there is no WAV file read or `AVAudioPlayer` construction in `play(_:)`.

## Explicit non-changes

Milestone 1.1 intentionally leaves these at Milestone 1.0 behavior:

- 60-Hz presentation-driven `host.step()` contract;
- all ZoneCore C source and headers;
- all enemy behavior tick divisors;
- player firing cadence;
- projectile lifetimes;
- death/respawn timing;
- wave-clear timing;
- Rotor, Mother, HQ, Bee and Seeker state machines;
- render positions and sprite-frame selection.

The recovered Classic TickCount evidence remains useful forensic data, but it is no longer being interpreted as a blanket instruction to halve the entire modern simulation.

## Play-test target

First run normally. Concentrate on enemy rotation/orientation changes, first encounters with new enemy types, dense projectile/explosion scenes, and rapid repeated gunfire/impact sounds.

If motion still hitches, run `./Tools/run-macos-perf.command`. A hitch accompanied by `[ZonePerf][renderer] frame-gap` points toward presentation scheduling/GPU/window behavior. A hitch with no frame gap and no slow host step points toward discrete ZoneCore behavior and should be audited per enemy/state rather than by changing the global simulation clock.
