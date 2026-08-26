# Hotfix 1.11.4 — Cinematic title motion

## Motivation

Hotfix 1.11.3r1 removes the active-window stutter, but the recovered 48-frame title ship still completes a revolution in about 9.6 seconds. With continuous interpolation that speed is smooth, yet it reads as frantic rather than atmospheric.

## Changes

- Default ship revolution: **24 seconds** (previously ~9.6 seconds).
- The 48 recovered title frames remain authoritative and are still continuously interpolated.
- Purple display arc: **48 seconds/revolution**.
- Cyan counter-rotating arc: **90 seconds/revolution**.
- Ring movement is deliberately decoupled from ship rotation so the display feels like slow instrumentation rather than synchronized spinning decoration.
- Optional environment tuning: `ZONE_TITLE_ROTATION_SECONDS` accepts 12–120 seconds, with 24 seconds as the default.

No ZoneCore, gameplay, audio, collision, camera, AI, timing, renderer, or recovered gameplay sprite behavior changes are included.

## Visual acceptance

Run normally and watch the title for at least one full 24-second revolution. The motion should feel calm, deliberate, and continuous. If desired, audition another period without rebuilding, for example:

```bash
ZONE_TITLE_ROTATION_SECONDS=30 ./Tools/run-macos-refresh.command native high
```

Good tuning candidates are 20, 24, 30, and 36 seconds. Once a preferred value is selected it can be made the permanent default.
