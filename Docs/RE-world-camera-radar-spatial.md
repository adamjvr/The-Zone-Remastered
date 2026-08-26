# Reverse engineering — world, camera, radar, +128/+129 spatial state

## Exact dimensions

Classic display setup subtracts 112 pixels from the full 640-pixel display width, producing a 528-pixel playfield. It then stores twice the larger of playfield width (528) and display height (480) as the square world extent. Therefore the recovered world is exactly **1056×1056**.

The adjacent radar/map drawable width is `640 - 528 - 2 = 110` pixels.

## Initial camera

Startup computes:

- `(1056 - 528) / 2 = 264` → camera left
- `(1056 - 480) / 2 = 288` → camera top

A 32×32 ship created at local top-left `(248,224)` therefore has center `(264,240)` in the playfield and world center `(528,528)`.

## Camera and world→screen

The camera has independent toroidal world left/top globals. The frame pass builds a 528×480 camera rectangle from those values. World positions are wrapped modulo 1056 and projected through the camera using the shortest toroidal displacement so an object crossing a world seam remains spatially continuous.

## `+128`

Byte `+128` is not object allocation. It is the screen/action-active state. `0x145A0` can set it when an object's projected rectangle re-enters the camera rectangle. The main spatial pass clears it after the object leaves the live screen region. SHOT/FIRE then use the recovered retirement dispatch instead of an invented lifetime countdown.

## `+129`

Byte `+129` is radar/map registration. It is **not** a collision-grid membership flag.

`0x419C` indexes a row-pointer byte buffer and writes one byte. `0x14764..0x14864` computes radar coordinates from world coordinates using the 110-pixel map width and 1056 world extent, caches them in object halfwords `+16/+18`, updates an existing map cell when the coordinate changes, clears the old cell with `-1` when registration ends, and writes the object map value from `+70` when registration begins.

Portable mapping:

`radarX = 528 + 1 + floor(worldX * 110 / 1056)`

`radarY = 1 + floor(worldY * 110 / 1056)`

## Processing-list relationship

At `0xED08..0xED34`, an object enters the action/render-maintenance array when either `+129 != 0` **or** `+128 != 0`. This is the key off-screen behavior point: Bee, Seeker, and the other world bodies do not become inert merely because they leave the visible playfield. Radar registration can keep them in the Classic processing lifecycle.

The exceptions at the start of `0x145A0` are `fake`, `shot`, and `fire`, whose lifecycle is handled by their specialized paths.

## Timing constraint

Milestone 1.11 does not multiply Classic spatial consequences by the native refresh rate. Motion can still be integrated on the 720-Hz master grid, but `+128` projectile retirement and the recovered Classic spatial maintenance boundary remain 60 Hz.
