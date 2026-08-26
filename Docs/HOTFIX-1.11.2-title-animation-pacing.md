# Hotfix 1.11.2 — Title Ship Decode + Pose Interpolation

Hotfix 1.11.1 removed the largest title-screen pacing faults: the 5-Hz ring jump, the 24-Hz ship schedule, and the idle 60-Hz GameController polling timer. Hardware testing still showed a smaller residual judder in the ship animation.

## Remaining causes

### Lazy image decode remained on the animation path

1.11.1 used an `NSCache`, but it populated the cache only when a frame was first requested. A new recovered ship frame enters the blend every 0.2 seconds. During the first revolution, that still allowed resource lookup and PNG decompression to coincide with animation updates.

1.11.2 replaces that cache with one 48-frame `CGImage` store. The first access initializes the entire set, and ImageIO is asked to cache/decode the images immediately. No later display-driven update opens or decodes a new ship PNG.

### A dissolve is not rotational interpolation

The recovered ship set contains 48 headings, 7.5 degrees apart. 1.11.1 cross-faded between adjacent headings but did not move their silhouettes through that 7.5-degree interval. That removes hard frame changes but can still look like a low-rate dissolve rather than continuous rotation.

1.11.2 keeps both recovered neighboring frames and continuously aligns them to the same intermediate heading:

- base frame rotates forward by `blend * 7.5°`;
- next frame rotates backward by `(1 - blend) * 7.5°`;
- the two aligned images cross-fade at the display-driven cadence.

At a recovered-frame boundary the outgoing and incoming representations meet at the same visual heading, so there is no 7.5-degree pose snap.

## What remains unchanged

- 48 recovered ship images remain authoritative.
- The title ship still completes one revolution in about 9.6 seconds.
- Ring angular speeds remain unchanged from 1.11.1.
- The starfield stays display-driven.
- Event-driven controller input from 1.11.1 stays intact.
- ZoneCore, the 720-Hz/60-Hz gameplay timing split, Milestone 1.11 camera/world/radar/spatial behavior, Metal gameplay rendering, and collision behavior are untouched.

## Acceptance test

On macOS, watch at least one complete title-ship revolution (~9.6 seconds), then another revolution. The first should no longer exhibit periodic frame-load hitches and the silhouette should move continuously rather than dissolve between static 7.5-degree poses. Enter gameplay and return to the title to ensure the animation remains smooth after a screen transition.

Repeat on the tethered iPad Pro after macOS acceptance.
