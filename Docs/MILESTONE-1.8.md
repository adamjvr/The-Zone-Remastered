# Milestone 1.8 — Native Front-End & Title Screen

Milestone 1.8 is the first product-shell milestone for **The Zone Remastered**. It wraps the accepted Milestone 1.7 gameplay runtime in a shared native SwiftUI front end without changing ZoneCore, the 720-Hz motion path, Classic 60-Hz decision/collision cadence, Metal rendering, audio, or controller routing.

## Product flow

Normal launch now enters a real title/front-end shell instead of dropping directly into Wave 1:

```text
App launch
   |
   +-- Title screen
         +-- New Game
         +-- Controls
         +-- Preferences
         +-- Credits
         +-- Quit (macOS)
               |
               v
            Gameplay
               |
               +-- Pause -> Resume
               +-- Pause -> Title Screen
```

`New Game` creates a fresh `ZoneGameHost`/ZoneCore instance. Returning to the title destroys the active gameplay view; starting again receives a new session identity and therefore a clean Wave-1 game rather than resuming hidden state.

For engineering iteration, `ZONE_BOOT_DIRECT=1` bypasses the front end and retains the accepted direct-to-game workflow.

## Title presentation

The title is built from native SwiftUI rather than a pre-rendered menu bitmap:

- responsive desktop/iPad layout with `ViewThatFits`;
- animated deep-space/starfield backdrop;
- recovered original ship sprite bank `Spri_01000` through `Spri_01047` used as a rotating 48-frame title emblem;
- nearest-neighbor sprite interpolation so the recovered pixels stay deliberate rather than blurred;
- cyan/purple terminal treatment around the menu while the core title remains high-contrast;
- system **Reduce Motion** freezes the rotating ship and animated starfield.

The sprite is loaded explicitly from the existing bundled `Sprites` resource directory, so no Xcode-project/resource-list surgery is required.

## Shared front-end state

`ZoneAppShell` and its app-session state live in the already compiled `Shared/ZoneContentView.swift`, which keeps the first front-end milestone common to macOS and iPadOS and avoids creating an undocumented XcodeGen dependency.

Screens:

- `title`
- `game`
- `controls`
- `preferences`
- `credits`

The existing `ZoneContentView` remains the actual game view and still owns the existing `ZoneGameHost`.

## Functional pages

### Controls

On macOS the Controls page reads the same persisted `ZoneInputRouter` bindings used by gameplay, so it reports the user's actual current assignments rather than hardcoded labels. Rebinding remains in the established in-game pause panel for this milestone.

On iPadOS the page documents touch, GameController, and external-keyboard input paths without inventing a controller-remapping UI that does not yet exist.

### Preferences

The first product preferences are front-end/presentation options and persist in `UserDefaults`:

- Show HUD
- Show Control Hints (macOS)
- Show Touch Controls (iPadOS)

These settings do not enter ZoneCore and therefore cannot change Classic simulation behavior.

### Credits

Credits establish the native-source reconstruction identity, recovered asset basis, supported Apple targets, and Classic-first fidelity mission.

## Pause integration

macOS retains its keyboard-rebinding pause panel and gains **Title Screen** alongside Resume. iPadOS gains a proper native pause panel with **Resume** and **Title Screen** instead of the previous text-only `PAUSED` overlay.

## Deliberately deferred

Milestone 1.8 does **not** add placeholder controls for systems that are not wired yet:

- Continue / Load Game and save slots
- Hall of Fame
- difficulty/profile selection plumbing
- controller remapping
- complete Classic preferences
- game-over and wave-transition presentation

Those now have a stable front-end shell to plug into.

## Preservation contract

The candidate must leave these accepted runtime components unchanged from Milestone 1.7:

- all of `ZoneCore/`;
- `Shared/ZoneGameHost.swift`;
- `Shared/ZoneMetalView.swift`;
- `Shared/ZoneRenderer.swift`;
- `Shared/ZoneAudioEngine.swift`;
- `Shared/ZoneInputRouter.swift`;
- `Shared/ZoneControllerManager.swift`;
- `Shared/ZoneTouchControls.swift`;
- `project.yml` and the checked-in Xcode project.

The milestone verifier enforces that preservation before running the existing ZoneCore, timebase, and native-target checks.
