# Reverse-Engineering Note — Native Real-Time Hot Paths

## Milestone 1.0 renderer problem

The Milestone 1.0 renderer's cache miss path was reachable directly from `draw(in:)`:

1. construct the `Spri_%05d` resource name;
2. ask `Bundle.main` for a URL;
3. call `MTKTextureLoader.newTexture(URL:options:)`;
4. decode the PNG and allocate/upload a Metal texture;
5. only then continue drawing the frame.

Because enemy heading changes select different recovered sprite resources, the first appearance of an orientation can coincide with that synchronous work. A user-visible micro-pause can therefore correlate with enemy motion even when ZoneCore itself is deterministic.

The repaired path preloads the complete recovered sprite directory before assigning the MTKView delegate. During gameplay, `texture(_:)` is a dictionary lookup only.

## Per-quad allocation problem

Milestone 1.0 created a new six-element Swift `[Vertex]` for every quad. The starfield alone contains 72 quads per frame, before any game object is drawn. At 60 Hz this creates thousands of short-lived array allocations per second.

Milestone 1.1 uses `withUnsafeTemporaryAllocation` for the six vertices. Visual geometry and UV coordinates are unchanged.

## Milestone 1.0 audio problem

The old implementation did this on every event:

- locate WAV URL;
- `AVAudioPlayer(contentsOf:)`;
- `prepareToPlay()`;
- `play()`;
- `players[sid] = player`.

The last assignment retained only one player for each sound resource. Triggering the same resource again replaced the previous strong reference even when it was still playing. That is incompatible with overlapping gunfire/impact events and can sound like restarting/chopping.

The repaired implementation prepares a finite voice bank before gameplay. `play(_:)` only chooses a voice, rewinds it and starts it.

## Diagnostic contract

Normal play has diagnostics disabled. `Tools/run-macos-perf.command` sets `ZONE_PERF_DIAGNOSTICS=1` and records output.

Important messages:

- `sprite-preload`: number of discovered / successfully prepared sprite textures;
- `texture-miss`: a requested sprite was absent from the preloaded cache;
- `frame-gap`: time between Metal draw callbacks exceeded 24 ms;
- `slow-step`: `host.step()` itself exceeded 4 ms;
- `slow-cpu-frame`: CPU-side draw submission exceeded 8 ms;
- `voice-steal`: all 16 prepared voices for one mapped sample were already playing.

This is intentionally coarse instrumentation. It separates presentation stalls from deterministic game-state changes without modifying ZoneCore.
