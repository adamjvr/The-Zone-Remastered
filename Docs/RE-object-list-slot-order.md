# Reverse-engineering notes — 80-slot allocator, `+138` list and spatial registration

## 80-record pool

The original PPC startup allocates storage for exactly **80 object pointers** and **80 150-byte object records**. A parallel occupancy table marks which records are in use.

The allocator at `0xDDD0` receives a mode flag:

```text
mode == 1: scan 79,78,...,0
otherwise: scan 0,1,...,79
```

The first free record is marked occupied and zeroed. No dynamic per-type pool exists in the original runtime.

## Persistent player/list head

During initialization the occupancy table is clear and the game calls `0xDDD0` in low mode. The returned object is stored as the global object-list head/player pointer. Therefore the persistent player record is Classic **slot 0**.

Respawn routine `0x1663C` reinitializes this same global head object as `ship`; it does not allocate a new player record.

## `0xDF14` — link insertion

`0xDF14(new, anchor, mode)` operates on object pointer `+138`:

### Mode 0

```text
new->next    = anchor->next
anchor->next = new
```

With the global player as anchor, low-mode objects are inserted directly after the head.

### Mode 1

The routine walks `anchor->next` until the tail, then:

```text
tail->next = new
new->next  = NULL
```

It increments the global live-object count after insertion.

## `0xDFBC` — unlink/free

The unlink routine:

1. walks `+138` from the list head to find the predecessor;
2. replaces `predecessor->next` with `target->next`;
3. scans the 80-record pointer table for the target record;
4. clears that slot's occupancy byte;
5. decrements the global live-object count.

This establishes that allocation slot identity and list position are separate concepts.

## Generic construction modes

Generic spawn path `0x11318` passes its mode argument through both:

```text
0xDDD0(mode)  -> choose record
0xDF14(..., mode) -> choose list insertion
```

Recovered live call sites used by current ZoneCore include:

| Object path | Mode | Allocator | List insertion |
| --- | ---: | --- | --- |
| Player `shot` (`0x122A0` / `0x12320`) | 0 | low → high | after head |
| HQ/base `fire` (`0x14BE8`) | 0 | low → high | after head |
| Fixed/world construction | 1 | high → low | append tail |
| Moving enemy/defender `fire` | 1 | high → low | append tail |
| Linked defenders / Bee / Big Rock children | 1 | high → low | append tail |

This explains why a flat typed-array iteration cannot reproduce all first-match behavior.

## In-place `EXPL`

The destruction paths call object initialization routine `0x107B4` on the existing object pointer with type `expl`.

Examples include:

- ship destruction: the global player/head pointer is passed directly to `0x107B4`;
- world destruction paths around `0x19BB4` / `0x19C18`: the destroyed object's pointer is passed directly.

There is no intervening call to `0xDDD0` or `0xDF14`. Consequently:

- Classic slot identity is unchanged;
- `+138` next pointer/list position is unchanged;
- the record remains occupied while the explosion runs.

Non-player explosion finalization later reaches common removal/unlink. Ship explosion completion instead reaches player reset/reinitialization, preserving head slot 0.

## `fake` and deferred removal

Common removal path `0x124B0` can reinitialize a record to `fake` before later spatial/list maintenance performs the actual `0xDFBC` unlink. This reinforces the distinction between **type transform** and **record free**.

Milestone 1.10 promotes the identity/list consequences required by currently live destruction paths without claiming every `fake` transition is fully represented yet.

## List-order-sensitive behaviors

### Bee donor — `0x16568`

The donor scan starts at `head->+138`, skips the requester, and returns the first eligible Mother/HQ donor. ZoneCore 1.10 now walks its Classic-slot list surrogate for this decision.

### Mobile Mother activation — `0x19C38..0x19C98`

After a qualifying player-shot kill, the original walks the object list and writes motion selector `+86` to the first eligible Mother with `+84 != 0`. ZoneCore 1.10 likewise uses Classic list order.

## `+129` — coarse spatial registration

The helper around `0x419C` writes/clears entries in a coarse 2D spatial lookup. Maintenance around `0x145A0` and `0x14764..0x14864` shows:

- `+129 == 1`: object is registered in a coarse spatial/collision cell;
- cell movement causes unregister/re-register and cached cell-coordinate updates;
- leaving the represented area clears `+129` and removes the previous cell entry.

This is distinct from `+138`, which is the global object chain.

## Why world `+128/+129` is not promoted in 1.10

For non-projectile objects, the maintenance code first derives screen coordinates from wider world/camera state before deciding `+128` visibility/action participation and `+129` spatial-cell registration.

Current portable ZoneCore uses a simplified wrapped 640×480 world and has no faithful equivalent of that original camera/world-to-screen transform. Promoting guessed cell/visibility rules now would contaminate Bee/Seeker and collision behavior.

The correct dependency order is therefore:

```text
1.10  exact shared slot identity + +138 ordering
  ↓
1.11  recover camera/world -> screen transform
      then promote non-projectile +128/+129 spatial state
```
