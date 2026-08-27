# Bee Parity Pass 2 — Donor Occupancy Finalization Timing

## Scope

One Bee behavior changes:

**The donor Mother/HQ remains Bee-occupied after the Bee is killed and is released only when the Bee-derived explosion finishes.**

Pass 1 requester quota semantics remain untouched.

## Recovered PPC behavior

The Bee carries its donor link in object field `+142`. Destruction transforms the same Classic record into `EXPL`, retaining that donor link. The EXPL finalizer around `0x12370..0x12494` checks the previous type, follows the retained Bee donor link, and decrements donor `+74` only when that explosion is finalized.

Therefore the two Bee counters have different meanings:

- requester `+76`: cumulative requests consumed during the wave;
- donor `+74`: outstanding Bee occupancy, retained through Bee EXPL.

## Repair

Pass 2 adds a `parent_slot` to the typed `Explosion` surrogate. Only Bee explosions populate it. Donor occupancy is left unchanged at lethal-hit time and decremented when the Bee EXPL reaches its final frame.

A defensive explosion-allocation failure releases the donor immediately because no finalizer would exist.

## Deterministic timing

A 32-pixel Bee uses the 11-frame EXPL bank and starts at `action_age=-1`.

The regression proves:

- immediately after Bee destruction: donor +74 = 1;
- after 11 Classic steps: donor +74 = 1 and EXPL remains active;
- after the 12th Classic step: EXPL finalizes and donor +74 = 0;
- requester +76 remains 1 throughout.

## Expected gameplay impact

Visible Bee frequency should remain essentially like Pass 1. This timing mainly matters when multiple Mothers compete for the same donor during the short Bee explosion window.

No firing, steering, collision, placement, spatial, RNG, wave, rendering, or audio rules are changed.
