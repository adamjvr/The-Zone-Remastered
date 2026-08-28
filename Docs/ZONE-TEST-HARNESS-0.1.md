# Zone Test Harness 0.1 — Direct Fixed-Zone Startup

This is a reusable **forensic/testing harness**, not a gameplay feature.

It lets a test session begin directly on any recovered fixed Zone 1–18 without
playing every preceding Zone.

## Usage

```bash
./Tools/run-macos-zone-test.command 2
./Tools/run-macos-zone-test.command 7
./Tools/run-macos-zone-test.command 18 native high
```

The first argument is the Zone. Presentation/dynamics arguments are passed to
the existing `run-macos-refresh.command`.

Existing diagnostic environment variables are inherited. For example, after
Bee Pass 3A is installed:

```bash
ZONE_BEE_FIRE_TRACE=1 ./Tools/run-macos-zone-test.command 7
```

## Safety boundary

Normal gameplay is unchanged. `ZONE_TEST_START_ZONE` is ignored unless
`ZONE_TEST_MODE` is explicitly enabled.

The runner sets both variables only for that launched process:

- `ZONE_TEST_MODE=1`
- `ZONE_TEST_START_ZONE=<1..18>`

Invalid or out-of-range Zone requests fail closed to the normal Zone-1 reset.

## RNG caveat

A direct jump gives the correct fixed-wave preset, object classes/counts, and
rules for the selected Zone. It does **not** reconstruct all RNG consumption
that would have happened while naturally playing preceding Zones.

Use it for Bee quotas/lifecycle, enemy behavior/firing, collisions, wave
composition, object lifecycle, and later-Zone smoke tests. Do not use a direct
jump as evidence for exact full-run RNG/placement sequence parity.

In-app next/previous-Zone hotkeys can be added as a second testing layer later,
but direct startup solves the expensive replay problem without touching normal
input/UI behavior.
