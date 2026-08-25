# Front-End Navigation Architecture

## Boundary

The Zone Remastered now has two deliberately independent input consumers:

### Gameplay

`ZoneControllerManager` samples Apple's physical controller profile and converts it to `ZoneInput`. `ZoneInputRouter` merges keyboard/touch/controller semantic actions. ZoneCore receives only semantic gameplay state.

### Front end

`ZoneFrontEndInputMonitor` is a SwiftUI/product-layer helper used only while front-end or iPad pause views are visible. It emits six UI commands:

- up
- down
- left
- right
- accept
- back

It does not construct or mutate `ZoneInput`.

## Why polling instead of replacing GameController handlers

The gameplay controller layer already samples the active controller. Installing a competing `valueDidChangeHandler` on the same `GCPhysicalInputProfile` would unnecessarily create ownership/lifecycle questions as the app moves between title and gameplay.

The front-end monitor therefore performs a tiny 60-Hz read of the already-normalized physical profile while a menu is visible. This keeps controller remapping honored and makes teardown trivial.

## Edge semantics

Menu commands are rising-edge actions. Holding the stick or a button does not repeatedly activate a menu item.

When the monitor starts it first snapshots current input values. This is important for Pause: the Menu button may still be physically down when the pause overlay appears. Priming means that held button is treated as pre-existing state, not a new Back command.

## Selection state

The selected menu row is application state, not incidental SwiftUI focus styling. Therefore:

- controller selection is visible;
- touch/pointer buttons still work;
- keyboard navigation uses the same selection model;
- platform focus-ring differences do not determine menu behavior.

## Fidelity rule

Front-end navigation is a native product feature. It must never alter:

- ZoneCore state;
- Classic RNG calls;
- Classic decision cadence;
- 720-Hz continuous dynamics;
- exact-pixel collision cadence;
- gameplay controller mappings.
