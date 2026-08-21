# Milestone 0.2 — Branding + recovered motion integration

Milestone 0.2 is deliberately incremental on top of the first verified native macOS build. It does not change the native target architecture.

## Added

- Selected remaster ship artwork under `Docs/images/`.
- Native macOS `Assets.xcassets/AppIcon.appiconset` with all 16/32/128/256/512 point 1x/2x slots.
- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` for the macOS Debug and Release configurations.
- Reproducible macOS `sips` icon generator.
- Milestone verifier.

## Gameplay correctness

The prototype core originally used `(cos(angle), -sin(angle))` for thrust and shots. Static lifting of the original PPC player/projectile code established that TheZone uses:

```text
X = -sin(angle)
Y =  cos(angle)
```

Milestone 0.2 routes player thrust through the recovered `tz_apply_player_thrust()` implementation and uses the same recovered directional convention for projectiles. Ship sprite-frame mapping now goes through `tz_heading_to_frame48()`.

The deterministic regression test asserts the recovered heading-0 behavior so future renderer/input changes cannot silently rotate the simulation basis.

## Apply

Extract the ZIP directly into the repository root, then:

```bash
chmod +x APPLY-MILESTONE-0.2.command Tools/*.command Tools/*.sh Tools/*.py
./APPLY-MILESTONE-0.2.command
```

## Verify and run

```bash
./Tools/verify-milestone-0.2.command
./Tools/build-macos.command
```

In Xcode, select **The Zone macOS > My Mac** and press **Command-R**.
