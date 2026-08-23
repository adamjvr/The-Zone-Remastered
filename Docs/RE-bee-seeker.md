# Reverse-Engineering Note — Bee and Seeker State Gates

This note records the PowerPC evidence promoted by Milestone 1.3.

## Bee — PPC `0x154A8`

The handler opens with:

```text
lha   r0,66(r30)
cmpwi r0,1
...
lwz   r7,92(r30)
current TickCount - r7
cmpwi elapsed,60
```

For elapsed values below 60 it routes through the continuous-vector conversion helper (`0xE6F4`) and returns. It does not execute the normal target-vector/facing/fire tail. At elapsed 60 or later it writes zero to `+66` and continues into the normal chase handler.

Observable portable contract:

```text
hit_state == 1 && elapsed < 60
    retain current velocity
    no retarget
    no new facing decision
    no Bee firing Random()

elapsed >= 60
    hit_state = 0
    resume normal Bee behavior
```

### No recovered Bee return state

The Bee behavior routine does not read the donor link created by `0x16504`. The donor link remains important for ownership/outstanding-Bee counters, but there is no evidence in `0x154A8` for orbiting or returning to that parent. The implementation therefore does not invent one.

## Bee donor/requester — PPC `0x16504`

The already-live request path is retained:

- requester must be Mother/HQ;
- request count must be below the current wave Bee limit;
- requester is excluded from donor search;
- donor must be another Mother/HQ with no Bee already outstanding;
- Bee link1 points at donor;
- donor outgoing-Bee count increments;
- requester request count increments.

Professional Wave 2 is the first fixed wave that naturally provides two Mothers while retaining `bee_limit = 1`, so it is now used as an integration regression for this path.

## Seeker — PPC `0x15944`

The Seeker opens with the same `+66` timed-state check and a 60-TickCount threshold. While gated it returns before normal target calculation and the firing tail.

Normal pursuit retains the already-promoted distance switch:

```text
distance_squared <= 40000  -> player maximum speed
distance_squared >  40000  -> cruise speed 10
```

The exact `<=` boundary is regression-tested.

## Seeker player collision — PPC `0x1A0B4..0x1A0C8`

The player/body collision dispatcher recognizes `seek` and writes:

```text
+92 = TickCount - 30
+66 = 1
```

The next Seeker handler therefore sees an already-aged 30/60 interval. Assuming no additional setter refreshes the state, approximately 30 TickCount units remain before normal retarget/firing resumes.

## Why firing is gated before RNG

The branch to the timed-state return occurs before the Bee/Seeker `Random()` firing test. ZoneCore therefore checks the timed state before consuming its placeholder RNG. This is not only an optimization: preserving whether a Random call occurs is part of the observable future deterministic sequence once Classic Mac `Random()` compatibility is implemented.

## `+128` remains unresolved

Both handlers later inspect byte `+128`. It appears to select between spatial/targeting modes and also affects entry into their common firing tails. ZoneCore does not yet model the original spatial manager strongly enough to assign a safe semantic name to this byte. Milestone 1.3 leaves it unresolved.

## Timing and high-refresh architecture

Classic Mac `TickCount` is a wall-clock tick source, not a statement that the renderer must be fixed to 60 Hz forever. Milestone 1.3 uses the current `behavior_tick` as the temporary native representation because the accepted game currently advances once per nominal 60-Hz host callback.

The planned Milestone 1.4 integer engine timebase must translate these recovered durations independently of presentation refresh. A 120-Hz iPad Pro and a 240-Hz Mac display must not alter Bee/Seeker state duration, RNG cadence, or game speed. The current `behavior_tick` also freezes while the native pause state is active, whereas Classic Mac `TickCount` is a wall-clock source; exact pause-versus-expiry behavior is therefore explicitly deferred to the timebase audit rather than guessed here.


## Remaining setters

The collision dispatcher contains additional writes to object `+66` across enemy-pair special cases. Milestone 1.3 promotes the proven Seeker player-collision setter and the Bee/Seeker behavior gates, but does not claim the complete original collision matrix yet. Additional Bee hit-state setters will be wired when those exact pair branches are lifted.
