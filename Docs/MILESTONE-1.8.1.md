# Milestone 1.8.1 — Front-End Polish & Navigation

Milestone 1.8.1 is a product-layer follow-up to the accepted Milestone 1.8 title/menu shell. It does not alter ZoneCore, the 720-Hz dynamics path, Classic AI/RNG/collision cadence, Metal rendering, audio, gameplay input routing, or recovered rules.

## Goals

- make the title/menu shell fully usable from a physical game controller rather than requiring pointer/touch interaction;
- give hardware keyboards first-class front-end navigation on current macOS/iPadOS;
- add explicit selected-state presentation instead of relying on platform focus-ring behavior;
- make Preferences controller-operable;
- make the iPad pause screen controller-operable;
- tighten title/menu spacing and safe-area behavior on iPad;
- add short native transitions and visual hierarchy without replacing the accepted recovered ship art.

## Controller navigation

A new menu-only `ZoneFrontEndInputMonitor` polls Apple's semantic `GCPhysicalInputProfile`. It reads the D-pad/left thumbstick plus primary/secondary/Menu buttons and emits edge-triggered front-end commands.

The monitor is intentionally separate from `ZoneControllerManager`:

- `ZoneControllerManager` remains the gameplay input source and continues to feed semantic `ZoneInput` to ZoneCore.
- `ZoneFrontEndInputMonitor` exists only while title/submenu/iPad-pause SwiftUI views are on screen.
- it never writes ZoneCore input state;
- it does not replace system controller remapping;
- it primes edge state from currently-held buttons when a screen appears, preventing the Menu press that opened Pause from immediately triggering another pause-menu command.

Title controls:

- D-pad / left stick: change selection;
- primary button: activate selection;
- touch/pointer remains fully supported.

Subpages:

- secondary/Menu: return to title;
- Preferences: D-pad/stick selects a row, left/right/primary toggles it.

On iPad Pause:

- D-pad/stick selects Resume or Title Screen;
- primary activates;
- secondary returns to gameplay;
- Menu can still use the existing gameplay pause semantic.

## Hardware keyboard navigation

The front end now uses SwiftUI's focused `onKeyPress` API on supported Apple targets:

- Up/Down: title/preference selection;
- Left/Right: toggle selected preference;
- Return: activate;
- Escape: leave subpages or resume iPad Pause.

This is front-end-only input and does not alter the canonical macOS gameplay bindings.

## Visual polish

- explicit cyan selected-row treatment with a compact READY state;
- small terminal status header and online indicator;
- Classic Rules / 720 Hz Motion / Native Metal status chips;
- subtle second orbit element around the recovered 48-frame ship;
- restrained scanline texture over the existing starfield;
- safe-area-respecting title/subpage content on iPad while the space backdrop still fills the screen;
- consistent cyan/blue pause-panel treatment on both Apple platforms;
- animated screen transitions that do not affect game timing.

## Acceptance

Milestone 1.8.1 should be tested on real hardware:

1. macOS: keyboard/pointer plus any connected controller;
2. tethered iPad Pro from Xcode: touch plus a physical controller if available;
3. start a New Game, Pause, Resume, Return to Title, and start another New Game;
4. verify title/subpage navigation never changes gameplay timing or controller behavior in ZoneCore.

No iPad simulator run is required for this milestone.
