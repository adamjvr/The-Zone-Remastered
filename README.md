<p align="center">
  <img src="Docs/images/TheZoneRemastered-Ship.png" alt="The Zone Remastered ship" width="720">
</p>

# The Zone Remastered — Engineering Milestone 0.2

Native Apple remaster built from the reverse-engineered *TheZone* 1.5.1 game logic and assets.

## Current verification status

- **The Zone macOS** — native macOS application, verified building and running on macOS 15 Sequoia. Keyboard is canonical; controllers exposed by Apple's `GameController.framework` are supported as an alternate input path.
- **The Zone iPadOS** — separate native iPadOS application target. Apple-supported game controllers are first-class; touch controls remain available when no controller is connected.
- **ZoneCore** — deterministic portable C engine library, with no AppKit/UIKit/Metal dependencies.

## Milestone 0.2

- Adds the selected remaster ship artwork as the documentation hero image.
- Adds a complete native macOS `AppIcon.appiconset` generated from that artwork.
- Sets the macOS target's asset-catalog app icon to `AppIcon`.
- Preserves the native target split introduced in 0.1.2: macOS is a real `macosx` target; iPadOS is a real `iphoneos`/`iphonesimulator` iPad-only target.
- Replaces the milestone prototype's rotated thrust/projectile vector with the recovered original TheZone basis: **X = -sin(angle), Y = cos(angle)**.
- Routes Classic ship frame selection and thrust acceptance through the recovered `tz_heading_to_frame48`, `tz_wrap_heading`, and `tz_apply_player_thrust` functions.
- Adds a regression test proving heading 0 accelerates and fires along the recovered positive-Y vector rather than the old provisional +X vector.

## Playable foundation

- Original 640×480 logical viewport, Retina/widescreen letterboxing in Metal.
- Original 48-frame player `Spri` art.
- Original asteroid, shot and 20-frame explosion art.
- Recovered 7.5° sprite orientation system.
- Recovered continuous-motion X≈0.325/Y=0.25 scaling.
- Recovered 15-unit projectile vector basis.
- Exact nonzero-pixel collision using original indexed sprite bytes in ZoneCore.
- Ship rotation/thrust, firing, asteroid destruction, explosion, score and shield collision.
- Original 36 Sound Manager samples converted to WAV and bundled. Initial event mappings remain provisional pending completion of sound-dispatch lifting.

## Build

Open `TheZoneRemastered.xcodeproj` in Xcode.

For the native Mac application select:

```text
The Zone macOS > My Mac
```

Then press **⌘B** to build or **⌘R** to run.

Native command-line checks/builds:

```bash
./Tools/verify-native-targets.command
./Tools/test-zonecore.sh
./Tools/build-macos.command
./Tools/build-ipados-simulator.command
./Tools/build-ipados-device.command
```

## Canonical macOS controls

- Left/Right arrows: rotate
- Space: thrust
- Option: fire
- Up/Down arrows: equipment selection
- Command: select/use
- Escape: pause
- Keypad decimal: classic save action hook

## Controller policy

There is intentionally **no brand/device whitelist**. Controller support comes from `GameController.framework`; any controller recognized and normalized by Apple is accepted. Classic gameplay turns analog inputs into the original digital actions.

## Artwork and macOS app icon

The selected source artwork lives at:

```text
Docs/images/TheZoneRemastered-Ship.png
```

The Mac asset catalog lives at:

```text
macOS/Assets.xcassets/AppIcon.appiconset
```

To regenerate the icon sizes on macOS from the source artwork:

```bash
./Tools/generate-macos-app-icon.command
```

The source art remains untouched; generated icon PNGs are derived assets.

## Accuracy status

Milestone 0.2 is an executable remaster foundation, not yet a claim of 100% behavior parity. Exact sprite collision, object/save layouts, damage tables, fixed wave presets, several AI routines and core motion semantics have been recovered. Remaining AI/collision/wave/projectile/equipment state machines are being lifted into `ZoneCore/Recovered` and will replace temporary milestone logic subsystem-by-subsystem.

## Asset completeness

The project carries all **651** recovered `Spri` images and all **36** recovered `snd ` resources. ZoneCore also contains the indexed pixel payload for all 651 sprites, generated from the original resource fork, so every future object class can use the exact original nonzero-pixel collision masks.

Regenerate the collision database after a fresh resource extraction with:

```bash
./Tools/generate-zone-sprite-data.py /path/to/TheZone_Sprites ZoneCore/src/zone_sprite_data.c
```

## Native target policy

This project intentionally ships **two distinct native Apple application targets**:

- **The Zone macOS** — macOS SDK; AppKit/SwiftUI/Metal; deployment target macOS 15 Sequoia; keyboard is canonical, with GameController support alongside it.
- **The Zone iPadOS** — iPadOS/iOS SDK for **iPad only**; UIKit/SwiftUI/Metal; GameController plus touch/keyboard input.

The iPad target explicitly disables both **Mac Catalyst** and **Mac (Designed for iPad)**. It is not the Mac version of the game. The shared C `ZoneCore` is compiled for the active native SDK, so no macOS static-library binary is linked into the iPad build.

Run `./Tools/verify-native-targets.command` on a Mac with Xcode to assert these settings.

## Sequoia policy

The installed Xcode SDK and the minimum OS are intentionally separate concepts. A current Xcode may report `SDKROOT = macosx26.x`; the native Mac app remains explicitly pinned to `MACOSX_DEPLOYMENT_TARGET = 15.0` and is developed to remain compatible with macOS 15 Sequoia rather than requiring macOS 26 APIs.
