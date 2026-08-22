# Milestone 0.6.1 — Pause/Input and Mother Base Stutter Hotfix

This hotfix stabilizes Milestone 0.6 before further gameplay systems are added.

## Bug 1 — spontaneous pause/unpause

### Cause
Pause entered ZoneCore as a sampled held state. ZoneCore itself edge-latched that state, but a controller `Menu` input that briefly bounced `pressed -> released -> pressed` produced two valid edges. Keyboard auto-repeat also needlessly re-submitted held key state.

### Fix
- `ZoneInputRouter` turns keyboard/touch pause into a one-shot rising-edge pulse.
- macOS repeated `keyDown` events are ignored.
- `ZoneControllerManager` turns Apple's semantic `GCInputButtonMenu` into a rising-edge pulse and rejects a second edge inside 200 ms.
- Controller connect/disconnect resets pause edge state.
- macOS clears held keyboard state if the Metal view loses first-responder status, preventing swallowed `keyUp` events from leaving controls stuck.

ZoneCore retains its own pause latch as a second safety boundary.

## Bug 2 — Mother Base / HQ visual stutter

### Cause
The portable world loop was cycling every non-enemy sprite bank once every eight ticks. That included the eight-frame Mother Base (`moth`) and Headquarters (`base`) banks.

The recovered PPC `moth` behavior handler at `0x14C70` updates movement/orientation state but contains no store to object `sprite_frame` at offset `+56`. The same is true of the `base` behavior path. Their frames therefore must not be advanced by a generic passive-animation loop.

At 60 Hz the incorrect `tick & 7` rule changed those frames at 7.5 Hz, creating the obvious wobble/stutter.

### Fix
Mother Base and Headquarters frames are excluded from the provisional passive frame cycler. Their chosen frame remains stable until an exact recovered behavior explicitly changes it.

## Regression coverage

A new headless test parks the Wave-1 Mother Base and advances 64 ticks. Its sprite frame must remain unchanged.

The full Milestone 0.6 ZoneCore suite continues to pass with `-Wall -Wextra -Werror`.
