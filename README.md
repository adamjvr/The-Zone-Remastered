# The Zone Remastered — Engineering Milestone 0.1

Native Apple remaster scaffold built from the reverse-engineered TheZone 1.5.1 game logic and assets.

## Targets
- **The Zone macOS** — native macOS app. Keyboard is canonical; all controllers exposed by Apple's `GameController.framework` are supported as an alternate input path.
- **The Zone iPadOS** — native iPad app. Apple-supported game controllers are first-class; touch controls remain available when no controller is connected.
- **ZoneCore** — deterministic C engine library, with no AppKit/UIKit/Metal dependencies.

## Milestone 0.1 playable loop
- Original 640×480 logical viewport, Retina/widescreen letterboxing in Metal.
- Original 48-frame player `Spri` art.
- Original asteroid, shot and 20-frame explosion art.
- Recovered 7.5° sprite orientation system.
- Recovered continuous-motion X≈0.325/Y=0.25 scaling.
- Recovered 15-unit projectile vector basis.
- Exact nonzero-pixel collision using original indexed sprite bytes in ZoneCore.
- Ship rotation/thrust, firing, asteroid destruction, explosion, score and shield collision.
- Original 36 Sound Manager samples converted to WAV and bundled. Initial event mappings are provisional pending completion of sound dispatcher lifting.

## Build
Open `TheZoneRemastered.xcodeproj` in current Xcode on macOS.

Choose **The Zone macOS** or **The Zone iPadOS** and Run. Signing team/bundle IDs can be changed in Signing & Capabilities.

The project uses generated Info.plists and has no third-party runtime dependencies.

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

## Accuracy status
Milestone 0.1 is an executable remaster foundation, not yet a claim of 100% behavior parity. Exact sprite collision and several core constants are already recovered. Remaining AI/collision/wave/projectile/equipment state machines are being lifted into `ZoneCore/Recovered` and will replace temporary milestone logic subsystem-by-subsystem.

## Asset completeness
The project now carries all **651** recovered `Spri` images and all **36** recovered `snd ` resources. ZoneCore also contains the indexed pixel payload for all 651 sprites, generated from the original resource fork, so every future object class can use the exact original nonzero-pixel collision masks.

Regenerate the collision database after a fresh resource extraction with:

```sh
./Tools/generate-zone-sprite-data.py /path/to/TheZone_Sprites ZoneCore/src/zone_sprite_data.c
```

## Apple controller implementation
The iPad target declares the Game Controllers capability/profile support in `iPadOS/Info.plist`. Runtime input is brand-agnostic and uses Apple semantic controller elements; system-level controller remapping is respected. The Mac target uses the same controller manager while retaining direct AppKit keyboard handling as the canonical input path.

## Verification boundary
This package was produced in a non-Apple build environment. Its C engine is compiled and regression-tested here, its Swift files are syntax-parsed, and the `.pbxproj` / plist files are linted. Final framework/Metal compilation, signing, and device/simulator execution must be performed by Xcode on macOS; `Tools/build-macos.command` and `Tools/build-ipados-simulator.command` are included for that first Apple-host verification.
