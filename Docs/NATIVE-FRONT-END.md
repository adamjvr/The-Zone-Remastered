# Native front-end architecture

## Boundary

The application shell is intentionally outside ZoneCore. ZoneCore remains a portable deterministic game simulation and has no title/menu/preferences concepts. The SwiftUI host chooses when a game instance exists and how native UI is presented around it.

```text
SwiftUI application shell
        |
        +-- title / controls / preferences / credits
        |
        +-- gameplay screen
                |
                +-- ZoneContentView
                        |
                        +-- ZoneGameHost
                                |
                                +-- ZoneCore
                                +-- AVAudioEngine
                                +-- Metal presentation
```

This keeps product navigation from becoming a new simulation state and prevents UI work from perturbing recovered gameplay timing.

## Game lifetime

`ZoneContentView` still owns `@StateObject private var host = ZoneGameHost()`.

`ZoneAppSession.startNewGame()` changes `gameIdentity` and selects `.game`. The game view receives `.id(gameIdentity)`, forcing SwiftUI to construct a fresh gameplay subtree and therefore a new ZoneGameHost/ZoneCore instance. `returnToTitle()` removes that subtree.

This is the correct Milestone-1.8 behavior for **New Game**. Persistent Continue/Load will later introduce explicit save restoration rather than retaining an invisible live game behind the title screen.

## Direct engineering boot

Set:

```text
ZONE_BOOT_DIRECT=1
```

before launching the app. `ZoneAppSession` then starts on `.game` instead of `.title`. This is a host-only developer affordance and does not change ZoneCore.

## Resource loading

Gameplay already loads sprite PNGs from:

```text
Bundle.main/.../Sprites/Spri_XXXXX.png
```

The title emblem uses the same bundle contract and the recovered ship bank 1000...1047. It does not add a second copy of the ship art and does not require an asset-catalog entry.

## Preference ownership

Milestone 1.8 presentation preferences are stored under:

- `ZoneFrontEnd.showHUD`
- `ZoneFrontEnd.showControlHints`
- `ZoneFrontEnd.showTouchControls`

They affect only SwiftUI overlays. Classic gameplay preferences that influence rules remain separate future work and must be promoted only when their original semantics are understood.

## Future attachment points

The shell is intentionally ready for later screens without changing its game boundary:

- Continue / save-slot browser
- Hall of Fame
- Classic preferences
- controller mapping
- game-over flow
- wave-transition presentation
- fullscreen/display controls

Save/load should create a new game subtree and restore serialized state into it; it should not keep a suspended ZoneGameHost alive behind the menu.
