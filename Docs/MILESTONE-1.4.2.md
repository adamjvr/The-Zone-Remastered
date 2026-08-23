# Milestone 1.4.2 — Nonblocking SFX Graph Hotfix

Base working state: committed Milestone 1.3 (`92f4e1912310162992f067c70edb7133412b48ec`) with the uncommitted Milestone 1.4 high-refresh/timebase overlay and the 1.4.1 Raider fire-cap correction applied.

## Why this hotfix exists

Milestone 1.2 attribution and the first Milestone 1.4 refresh run conclusively localized the remaining large frame stalls to the native audio trigger path rather than ZoneCore or Metal.

Representative accepted telemetry from the 60-Hz comparison run:

- ZoneCore maximum: about **0.067 ms**;
- audio stage maximum: about **90.033 ms**;
- worst Classic step: about **90.117 ms**, `dominant=audio`;
- worst individual trigger: about **89.940 ms**, sample `sid=153` / fire event;
- all 23 logged slow Classic steps were audio-dominant;
- texture misses: **0**;
- voice steals: **0**.

The individual trigger split showed the repeated 10–15 ms stalls and the ~72–90 ms outliers landing inside `AVAudioPlayer.play()` (and occasionally `currentTime = 0`). This means the Milestone 1.1 preload/voice-bank repair removed file/player construction from gameplay but `AVAudioPlayer` itself is still allowed to synchronously interact with its playback machinery on the main game/presentation thread.

## Backend change

`ZoneAudioEngine` now uses one persistent `AVAudioEngine` graph with predecoded `AVAudioPCMBuffer` samples and a fixed pool of sixteen `AVAudioPlayerNode` voices per mapped sample.

Initialization, before gameplay presentation:

1. open each mapped WAV through `AVAudioFile`;
2. decode it fully into an `AVAudioPCMBuffer`;
3. create/attach/connect sixteen player nodes for that sample;
4. prepare and start the shared engine once;
5. start each player node once.

Gameplay trigger path:

1. select a free rotating voice using a predicted buffer-completion timestamp;
2. if all sixteen are occupied, reuse the rotating oldest slot and emit `voice-steal` diagnostics;
3. call only `scheduleBuffer(..., options: .interrupts)` on the already-running node.

There is no gameplay-time WAV access, `AVAudioPlayer` construction, `currentTime` seek, player `stop()`, or player `play()` call.

## Behavioral scope

The mapping of Zone audio events to `snd` resources is unchanged. Volume remains 0.75. Voice capacity remains sixteen per unique mapped sample. This hotfix changes the native playback mechanism only.

It does **not** change:

- ZoneCore;
- the 720-Hz master timebase;
- 60-Hz Classic semantics;
- high-refresh presentation policy;
- AI/RNG/collision/projectile rules;
- Bee/Seeker behavior;
- the 1.4.1 Raider 3-shot recovered cap correction;
- sprite rendering or texture preload behavior.

## Validation target

Run both:

```bash
./Tools/run-macos-refresh.command 60
./Tools/run-macos-refresh.command native
```

The important expectation is that `host-detail` no longer reports 10–90 ms audio-dominant Classic steps when firing/impact/explosion sounds trigger. Any remaining stall should be attributed independently by the existing 1.2/1.4 diagnostics.
