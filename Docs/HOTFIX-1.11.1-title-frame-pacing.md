# Hotfix 1.11.1 — Title/Menu Frame Pacing

This hotfix is intentionally product-layer-only. It does **not** modify the Milestone 1.11 world/camera/radar/spatial work or the accepted 720-Hz/60-Hz gameplay split.

## Root cause

The title/front-end path used three independent periodic workloads on the main UI path:

1. `ZoneTitleStarfield` requested SwiftUI updates at 60 Hz.
2. `ZoneFrontEndInputMonitor` independently polled GameController from a main-run-loop `Timer` at 60 Hz even when the controller was idle.
3. `ZoneRotatingShip` requested updates at 24 Hz, but quantized its visual phase to `Int(time * 5.0)`. The decorative rings were tied to that same integer frame and therefore jumped only five times per second.

The bundled ship image was also opened with `NSImage(contentsOf:)` / `UIImage(contentsOfFile:)` from the animated SwiftUI view body. Re-evaluating that body could therefore cause recurring synchronous resource lookup/image construction instead of using a stable cache.

This combination is fundamentally different from gameplay, whose high-refresh path is driven by the native host/Metal renderer. It explains why the title can look uneven while gameplay is smooth.

## Changes

- Remove the idle 60-Hz front-end polling timer.
- Use `GCPhysicalInputProfile.valueDidChangeHandler` so menu controller work happens when input actually changes.
- Marshal controller callbacks onto the main queue before mutating menu state.
- Let SwiftUI choose the display-appropriate animation cadence for both title animation timelines instead of hard-capping one at 24 Hz and one at 60 Hz.
- Preserve the title ship's existing slow 48-view revolution rate, but blend adjacent sprite views continuously between recovered frames.
- Drive decorative ring angles from continuous time, preserving their old angular speed while removing 200-ms stepping.
- Cache bundled sprite images after first load so animated view invalidation no longer implies recurring file/image construction.
- Leave gameplay simulation, Metal rendering, ZoneCore, and Milestone 1.11 spatial behavior untouched.

## Test checklist

On macOS:

- Leave the title screen idle for 15–30 seconds and watch the starfield/rings/ship.
- Navigate rapidly with Up/Down + Return.
- If a controller is connected, navigate repeatedly with D-pad and left stick and select with the primary button.
- Enter gameplay and confirm gameplay motion still feels identical to accepted 1.11.
- Return to the title screen and confirm title animation remains smooth after the transition.

On iPadOS:

- Repeat the title-screen test with touch and a paired/tethered controller.
- Open Pause and verify controller Back/Menu edge handling still does not immediately dismiss due to a held button.

## Scope

This is a frame-pacing hotfix, not a new gameplay milestone. If accepted, it can be committed with the 1.11 candidate as Milestone 1.11.1 or as a dedicated front-end fix commit immediately after 1.11.
