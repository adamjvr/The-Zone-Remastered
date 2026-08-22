# Milestone 0.6.2 — consistency repair

## Why this exists

The 0.6.1 delta hotfix updated the live implementation and regression test but did not carry the matching 0.5/0.6 public and recovered headers. On a tree where those headers had not been updated, strict C compilation therefore produced implicit-declaration errors and an excess `ZoneHUDState` initializer.

This repair is deliberately self-contained. It re-synchronizes the files that define the 0.5 progression API, 0.6 enemy-life API, and 0.6.1 pause/Mother-Base fixes.

## Restored as one coherent API set

- `ZoneCore/include/zone_core.h`
- `ZoneCore/src/zone_core.c`
- `ZoneCore/tests/test_zone_core.c`
- `ZoneCore/Recovered/include/thezone_decomp.h`
- `ZoneCore/Recovered/src/objects.c`
- `ZoneCore/Recovered/src/ai.c`
- `Shared/ZoneInputRouter.swift`
- `Shared/ZoneControllerManager.swift`
- `Shared/ZoneMetalView.swift`
- `Shared/ZoneGameHost.swift`
- `Shared/ZoneContentView.swift`

No Xcode project, signing, deployment-target, or native-target settings are changed.
