# Milestone 1.9 — Recovered Projectile Spatial Retirement

Milestone 1.9 replaces the last known invented projectile-lifetime rule in the live Classic reconstruction. Player `shot` and hostile `fire` objects no longer wrap around the 640×480 playfield and no longer expire after provisional 90/120-step counters. Their lifetime is now driven by the recovered spatial-active state used by TheZone 1.5.1.

This milestone is built on the accepted 1.8.1 front-end checkpoint. The native title/menu work, Metal renderer, AVAudioEngine path, 720-Hz host scheduler, input/controller layers, and recovered AI decision cadence remain unchanged.

## Recovered rule promoted

The PPC action handlers are explicit:

- `shot` action at `0x11D44` tests object byte `+128`; when zero it returns without running the shot collision handler. When active, it copies the cached motion fields and calls the player-shot collision path at `0x172DC`.
- `fire` action at `0x11D6C` has the same `+128` gate and calls the hostile-projectile collision path at `0x1801C`.
- neither action contains a lifetime decrement.

The spatial pass around `0xED44..0xF168` maintains screen activity. After motion it sets the horizontal/vertical out-of-region flags when an object's Classic top-left coordinate is no longer strictly inside:

```text
x > -side && x < zoneWidth
y > -side && y < zoneHeight
```

When either axis leaves that live rectangle, the pass clears object `+128`. Its type dispatch then retires projectile objects:

- `fire` goes through common object finalization/removal;
- `shot` is unlinked through `0xDFBC`, which removes it from the `+138` object chain, clears its occupied-table byte, and decrements the shared object count.

ZoneCore stores sprite centers rather than Classic top-left positions. The equivalent portable bounds are therefore:

```text
centerX > -side/2 && centerX < zoneWidth  + side/2
centerY > -side/2 && centerY < zoneHeight + side/2
```

## Portable implementation

`Projectile` now carries an explicit `spatial_active` surrogate for recovered byte `+128`. Spawned `shot` and `fire` objects enter with it set.

Projectile coordinates are no longer passed through `wrapf()`. A projectile can therefore actually leave the visible zone. At the next Classic spatial boundary, `projectile_outside_classic_live_region()` clears the spatial state and releases the projectile.

The sprite side used by the live-region check comes from the recovered `Spri` data through `zone_sprite_pixels()`, rather than a guessed fixed projectile size.

## 720-Hz behavior

Continuous projectile position integration remains real at 720 Hz. Spatial admission/retirement is deliberately **not** multiplied to 720 Hz: it remains a Classic 60-Hz boundary operation, matching the existing rule that high-rate dynamics do not multiply recovered AI/RNG/collision/lifecycle decisions.

That gives the high-refresh path real intermediate projectile positions without changing the Classic frequency at which off-region object state is evaluated.

## Source-shot accounting

Hostile projectiles already retain their source world slot so the recovered active-shot cap can be represented. Off-region `fire` retirement now takes the same `deactivate_projectile()` path as collision retirement, which releases that source count before freeing the projectile. A shooter whose three active shots leave the region can therefore fire again without waiting for an invented timeout.

## Regression coverage

Milestone 1.9 adds tests proving:

- a stationary player shot remains alive for 150 Classic steps — beyond the removed 90-step placeholder;
- an off-region player shot is retired and does not wrap to the opposite edge;
- recovered spatial-active state clears when the projectile is retired;
- 720-Hz motion does not retire an off-region projectile until the next Classic boundary;
- three hostile projectiles that leave the live region release their shooter's active-shot accounting and reopen the recovered cap;
- prior Classic/high-rate boundary parity remains required.

## Scope boundary

This milestone promotes the **projectile-relevant** recovered spatial/list behavior. It does not claim that ZoneCore's typed world/projectile/explosion arrays have become the original pointer graph. Exact `+138` traversal ordering, shared-slot reuse order, and remaining `+128/+129` behavior for Bee/Seeker and non-projectile world objects remain separate compatibility work.
