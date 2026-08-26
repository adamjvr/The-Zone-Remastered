# Milestone 1.10 — Shared Object Slots & +138 List Fidelity

Milestone 1.10 promotes the recovered allocator/list identity that sits underneath the original 150-byte object records. Milestone 1.6 already enforced the recovered **80-object capacity**; 1.10 now models *which* of those 80 records is used, how the object is inserted into the `+138` chain, how that exact record is reused after removal, and how destruction transforms an object in place rather than allocating a replacement explosion.

This is intentionally narrower than “all spatial state is complete.” Reverse engineering performed for this milestone also identifies object byte `+129` as coarse spatial-cell registration and confirms that non-projectile `+128/+129` activation depends on the original camera/world-to-screen transform. ZoneCore does not yet represent that transform faithfully enough to promote it without inventing behavior, so it is explicitly deferred to Milestone 1.11.

## Recovered allocator promoted

PPC routine `0xDDD0` owns the fixed 80-record allocator. Its mode argument controls reuse direction:

- **mode 0** scans record slots **0 → 79** and takes the first free slot;
- **mode 1** scans record slots **79 → 0** and takes the first free slot.

Startup clears the occupancy table and performs a mode-0 allocation for the global player/list-head object. The first free record is therefore **slot 0**, and the player remains that persistent head record.

ZoneCore now carries an 80-entry `ClassicObjectRef` table alongside its typed portable stores. The table records:

- occupied/free state;
- portable object kind;
- typed-store index;
- recovered Classic slot identity;
- a slot-index surrogate for object pointer `+138`.

The existing typed `world[]`, `projectiles[]`, and `explosions[]` arrays remain implementation details; they no longer determine Classic allocator order.

## Recovered `+138` insertion promoted

PPC routine `0xDF14` inserts newly allocated objects into the singly linked object chain rooted at the player/head record:

- **mode 0:** insert immediately after the head;
- **mode 1:** append at the tail.

The combination with `0xDDD0` gives two distinct behaviors that are now live:

```text
mode 0
  lowest free Classic slot
  + insert immediately after player/head

mode 1
  highest free Classic slot
  + append at list tail
```

Known live mappings promoted in 1.10 include:

- player `shot`: mode 0;
- Headquarters/base `fire`: mode 0;
- fixed-wave/world construction: mode 1;
- moving-enemy/defender `fire`: mode 1;
- portable debug/world construction follows the recovered world mode 1 contract.

This means list order is no longer equivalent to typed-array index order.

## Exact unlink and slot reuse

PPC routine `0xDFBC` walks the `+138` chain to find the predecessor, splices the target out, locates its exact record in the 80-entry table, clears that record's occupancy byte, and decrements the shared object count.

ZoneCore now mirrors those consequences. A removed low-mode projectile frees its exact Classic slot; the next mode-0 allocation reuses the lowest free record. High-mode objects analogously reuse the highest available record.

The player/head record is never unlinked.

## In-place destruction transforms

The original object initializer at `0x107B4` is called on the **same object pointer** when a ship or world object becomes `expl`. No second allocator call occurs.

Milestone 1.10 therefore changes portable destruction from:

```text
free WorldObject capacity
allocate new Explosion capacity
```

to the recovered identity model:

```text
same Classic slot
same +138 list position
WorldObject -> EXPL typed binding
```

This applies to:

- player `ship -> expl -> ship`: persistent Classic slot **0** remains the list head throughout death and respawn;
- world-object destruction: the explosion inherits the exact Classic slot and list rank of the destroyed object;
- explosion completion: non-player records are unlinked/freed only when the recovered explosion lifecycle completes.

Payload/consequence spawns still occur before the source transforms, preserving the already accepted capacity-pressure ordering.

## List-order-dependent scans

Two live behavior paths are now driven by the recovered `+138` ordering instead of typed world-array order:

- Bee donor search (`0x16568`): begins at `head->next` and chooses the first eligible other Mother/HQ donor;
- mobile Mother activation after a player-shot kill (`0x19C38..0x19C98`): walks the list and selects the first eligible Mother with `+84` set.

This matters once low-mode insertion and slot reuse begin changing the object-list order independently of typed storage.

## `+129` decoded, deliberately deferred

The coarse spatial helper around `0x419C` and maintenance paths around `0x145A0` / `0x14764..0x14864` show that byte `+129` means **registered in the coarse spatial/collision cell structure**. Cell transitions unregister/re-register the object and update cached cell coordinates.

For non-projectile world objects, the companion `+128` live/action state is derived after transforming world coordinates into screen coordinates relative to the original camera/player/world state. Current ZoneCore intentionally collapses that architecture into the 640×480 wrapped logical world.

Therefore 1.10 does **not** invent a world-object `+128/+129` rule. Milestone 1.11 will recover and introduce the camera/world-to-screen boundary first, then promote coarse-cell registration and the remaining Bee/Seeker spatial modes on top of it.

## Regression coverage

Milestone 1.10 adds regression assertions for:

- player/head = Classic slot 0;
- Wave-1 mode-1 allocations consume slots 79, 78, 77, 76 in list order;
- consecutive player shots consume slots 1 then 2 but each inserts immediately after the head;
- freeing low slot 1 causes the next player shot to reuse slot 1;
- Headquarters fire uses low-mode insertion;
- moving-enemy fire uses high-mode allocation and tail insertion;
- world destruction preserves Classic slot and list rank through `EXPL`;
- ship death keeps `EXPL` in slot 0 and respawn rebinds that same head record to `PLAYER`.

The existing 80-object admission, 720-Hz continuous-motion, 60-Hz Classic rule boundary, projectile spatial retirement, death/explosion timing, and fixed-wave regressions remain required.

## Scope boundary

Milestone 1.10 does **not** claim that typed portable storage has become a byte-for-byte clone of the original 150-byte records. It promotes the observable allocator/list semantics needed by live gameplay while keeping stable portable indices for host/save safety.

Still pending:

- original camera/world-to-screen transform;
- full non-projectile `+128` action/live-region behavior;
- `+129` coarse spatial-cell registration in live ZoneCore;
- Bee/Seeker edge behavior coupled to those spatial states;
- any unresolved special collision behavior that depends on the original spatial lists.
