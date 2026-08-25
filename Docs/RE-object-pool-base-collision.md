# Reverse-Engineering Note — 80-Object Pool and Base Collision

## Object pool allocation

At PPC startup `0x19E0..0x1A34`:

```text
li      r3,320
NewPtr                  ; 80 PPC32 pointers
...
li      r3,150
NewPtrClear             ; repeated 80 times
...
cmpwi   objectIndex,80
```

This is direct evidence for an 80-record global gameplay object pool with 150-byte PPC object records.

The current ZoneCore model historically used separate storage capacities:

```text
world       64
projectile  48
explosion   12
player      separate
```

That was useful during reconstruction but permits impossible Classic states. For example, the modern typed arrays could theoretically hold well over 80 simultaneous gameplay objects.

Milestone 1.6 adds a shared admission counter over the implemented Classic object categories. It does not yet collapse the storage arrays themselves.

## Base collision dispatcher entry

The per-object update code dispatches both `moth` and `base` to PPC `0x174E8`.

When object byte `+128 == 0`, the routine obtains the ship object, verifies its type is `ship`, performs the exact sprite overlap test, and enters the dedicated ship/base impact path.

On impact the recovered writes include:

```text
base +133 = 1
ship +133 = 4
SFX index 5
base +130 = 1
base +86  = 0
```

The routine then exchanges the continuous X/Y motion vectors and recomputes motion state.

The already-promoted damage formula is:

```text
damage = trunc(shipSpeed * 0.75 / shieldStrength)
damage = min(damage, 30)
```

## `+128 != 0` branch

The same routine has a materially different branch when base byte `+128` is nonzero. Rather than directly colliding with the ship, it walks an object-list range, ignores at least `fake` and `expl` object classes, exact-tests candidate objects, and dispatches a matching pair through the general collision dispatcher at `0x181A4`.

That behavior depends on original object-list ordering and the still-unresolved semantic meaning of `+128`. Milestone 1.6 therefore does **not** synthesize a portable equivalent for it.

## Portable mapping

Current mapping after Milestone 1.6:

| Classic field/behavior | ZoneCore mapping |
|---|---|
| global 80-object pool | shared admission cap across implemented categories |
| object +130 collision flag | `WorldObject.player_contact` latch |
| Mother/base +86 | `mother_motion_state` |
| base +133=1 | one-draw base flash surrogate |
| ship +133=4 | one-draw player flash surrogate |
| continuous vector exchange | `tz_swap_screen_velocity` |
| exact palette effects | pending |
| literal unified linked list | pending |
| `+128` alternate list collision mode | pending |
